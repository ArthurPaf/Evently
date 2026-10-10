"""Execute: venv/Scripts/python -m unittest discover -s tests -v"""
import os
import unittest
from datetime import datetime
from io import BytesIO

# Nunca conectar os testes ao banco da aplicação.
os.environ["DATABASE_URL"] = "sqlite://"

from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import DateTime, create_engine, event
from sqlalchemy.orm import Session
from sqlalchemy.sql.functions import GenericFunction
from openpyxl import load_workbook

from app.database import Base
from app.models import (
    Usuario, TipoPerfil, Evento, Barraca, Produto, Carteira,
    Transacao, ItemTransacao, TipoTransacao,
)
from app.controllers.transacao_controller import estornar_venda
from app.schemas.carteira_schema import EstornoCreate, TransacaoResponse
from app.routers.transacao_router import (
    _calcular_dashboard, estornar_transacao,
    exportar_dashboard_excel, exportar_dashboard_pdf,
)


class date_trunc(GenericFunction):
    """Tipo do retorno PostgreSQL para testar as mesmas consultas no SQLite."""
    type = DateTime()
    inherit_cache = True


class EstornoParcialTest(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite://")

        @event.listens_for(self.engine, "connect")
        def sqlite_functions(connection, _):
            connection.execute("PRAGMA foreign_keys=ON")
            connection.create_function("timezone", 2, lambda zone, value: value)
            connection.create_function(
                "date_trunc", 2,
                lambda unit, value: datetime.fromisoformat(value).replace(
                    minute=0, second=0, microsecond=0
                ).isoformat(" "),
            )

        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine)
        self.cliente = Usuario(nome="Cliente", email="cliente@test", senha_hash="test", perfil=TipoPerfil.CLIENTE)
        self.vendedor = Usuario(nome="Vendedor", email="vendedor@test", senha_hash="test", perfil=TipoPerfil.VENDEDOR)
        self.organizador = Usuario(nome="Organizador", email="organizador@test", senha_hash="test", perfil=TipoPerfil.ORGANIZADOR)
        self.evento = Evento(nome="Evento", organizador=self.organizador)
        self.barraca = Barraca(nome="Barraca", tipo="Comida", evento=self.evento, vendedores=[self.vendedor])
        self.produto = Produto(nome="Pastel", preco=8, barraca=self.barraca)
        self.bebida = Produto(nome="Suco", preco=5, barraca=self.barraca)
        self.carteira = Carteira(cliente=self.cliente, evento=self.evento, saldo_digital=66)
        self.db.add_all([self.vendedor, self.produto, self.bebida, self.carteira])
        self.db.flush()
        self.venda = Transacao(
            carteira=self.carteira, barraca=self.barraca,
            tipo=TipoTransacao.VENDA, valor_total=34,
            realizado_por_id=self.vendedor.id,
            itens=[
                ItemTransacao(produto=self.produto, quantidade=3, preco_unitario=8),
                ItemTransacao(produto=self.bebida, quantidade=2, preco_unitario=5),
            ],
        )
        self.db.add(self.venda)
        self.db.commit()
        self.item_id = self.venda.itens[0].id

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    def estornar(self, quantidade):
        return estornar_venda(
            self.db, self.venda.id, self.vendedor.id,
            EstornoCreate(itens=[{"item_id": self.item_id, "quantidade": quantidade}]),
        )

    def test_estorno_parcial_preserva_venda_e_preco_original(self):
        self.produto.preco = 99
        self.db.commit()
        estorno = self.estornar(1)
        self.assertEqual(estorno.valor_total, 8)
        self.assertEqual(self.carteira.saldo_digital, 74)
        self.assertEqual(self.venda.valor_total, 34)
        self.assertFalse(self.venda.estornada)
        self.assertEqual(self.venda.itens[0].quantidade, 3)
        response = TransacaoResponse.model_validate(self.venda)
        self.assertEqual(response.valor_estornado, 8)
        self.assertEqual(response.itens[0].quantidade_estornada, 1)
        self.assertEqual(TransacaoResponse.model_validate(estorno).itens[0].quantidade, 1)

    def test_estornar_tudo_devolve_apenas_restante(self):
        self.estornar(1)
        final = estornar_venda(self.db, self.venda.id, self.vendedor.id)
        self.assertEqual(final.valor_total, 26)
        self.assertEqual(self.carteira.saldo_digital, 100)
        self.assertTrue(self.venda.estornada)
        self.assertEqual(self.venda.valor_estornado, 34)
        self.assertEqual([i.quantidade_estornada for i in self.venda.itens], [3, 2])
        with self.assertRaises(HTTPException):
            estornar_venda(self.db, self.venda.id, self.vendedor.id)
        self.assertEqual(self.carteira.saldo_digital, 100)

    def test_estornos_sucessivos_nao_devolvem_unidades_ja_estornadas(self):
        self.estornar(1)
        self.estornar(2)
        with self.assertRaises(HTTPException):
            self.estornar(1)
        self.assertFalse(self.venda.estornada)  # O suco continua vendido.
        self.assertEqual(self.carteira.saldo_digital, 90)

    def test_quantidade_acima_do_restante_nao_altera_saldo(self):
        self.estornar(2)
        with self.assertRaises(HTTPException):
            self.estornar(2)
        self.assertEqual(self.carteira.saldo_digital, 82)
        self.assertEqual(len(self.venda.estornos), 1)

    def test_schema_rejeita_quantidades_invalidas(self):
        for qtd in [0, -1, 1.5, "2", True]:
            with self.subTest(qtd=qtd), self.assertRaises(ValidationError):
                EstornoCreate(itens=[{"item_id": self.item_id, "quantidade": qtd}])
        with self.assertRaises(ValidationError):
            EstornoCreate(itens=[])

    def test_item_estranho_ou_repetido_nao_altera_saldo(self):
        for itens in [
            [{"item_id": self.item_id, "quantidade": 1}, {"item_id": 9999, "quantidade": 1}],
            [{"item_id": self.item_id, "quantidade": 1}] * 2,
        ]:
            with self.subTest(itens=itens), self.assertRaises(HTTPException):
                estornar_venda(self.db, self.venda.id, self.vendedor.id, EstornoCreate(itens=itens))
            self.assertEqual(self.carteira.saldo_digital, 66)
            self.assertEqual(len(self.venda.estornos), 0)

    def test_produto_repetido_tem_limite_por_item_da_venda(self):
        extra = ItemTransacao(produto=self.produto, quantidade=2, preco_unitario=7)
        self.venda.itens.append(extra)
        self.venda.valor_total += 14
        self.db.commit()
        estorno = estornar_venda(self.db, self.venda.id, self.vendedor.id,
            EstornoCreate(itens=[{"item_id": extra.id, "quantidade": 1}]))
        self.assertEqual(estorno.valor_total, 7)
        self.assertEqual(self.venda.itens[0].quantidade_estornada, 0)
        self.assertEqual(extra.quantidade_estornada, 1)

    def test_estorno_antigo_total_continua_bloqueado(self):
        self.venda.estornada = True
        self.db.add(Transacao(carteira=self.carteira, tipo=TipoTransacao.ESTORNO,
                              valor_total=34, estorno_de=self.venda))
        self.db.commit()
        self.assertEqual(self.venda.itens[0].quantidade_estornada, 3)
        with self.assertRaises(HTTPException):
            self.estornar(1)

    def test_permissao_do_vendedor_continua_restrita_a_propria_venda(self):
        with self.assertRaises(HTTPException) as error:
            estornar_transacao(self.venda.id, db=self.db,
                usuario={"id": 9999, "perfil": "vendedor"})
        self.assertEqual(error.exception.status_code, 403)
        estorno = estornar_transacao(self.venda.id, db=self.db,
            usuario={"id": self.vendedor.id, "perfil": "vendedor"},
            dados=EstornoCreate(itens=[{"item_id": self.item_id, "quantidade": 1}]))
        self.assertEqual(estorno.valor_total, 8)

    def test_dashboard_desconta_parcial_em_todos_agrupamentos(self):
        self.estornar(1)
        dados = _calcular_dashboard(self.db, self.evento.id)
        self.assertEqual(dados["total_vendido"], 26)
        self.assertEqual(dados["numero_transacoes"], 1)
        self.assertEqual(dados["numero_estornos"], 1)
        self.assertEqual(dados["vendas_por_vendedor"][0]["valor_total"], 26)
        self.assertEqual(dados["vendas_por_barraca"][0]["valor_total"], 26)
        self.assertEqual(dados["vendas_por_periodo"][0]["valor_total"], 26)
        pastel = next(p for p in dados["produtos_mais_vendidos"] if p["nome"] == "Pastel")
        self.assertEqual(pastel["quantidade"], 2)
        self.assertEqual(pastel["valor_total"], 16)
        self.estornar(2)
        dados = _calcular_dashboard(self.db, self.evento.id)
        self.assertEqual([p["nome"] for p in dados["produtos_mais_vendidos"]], ["Suco"])
        estornar_venda(self.db, self.venda.id, self.vendedor.id)
        dados = _calcular_dashboard(self.db, self.evento.id)
        self.assertEqual(dados["total_vendido"], 0)
        self.assertEqual(dados["numero_transacoes"], 0)
        self.assertEqual(dados["vendas_por_vendedor"], [])

    def test_exportacoes_usam_totais_liquidos(self):
        self.estornar(1)
        usuario = {"id": self.organizador.id, "perfil": "organizador"}
        excel = exportar_dashboard_excel(self.evento.id, self.db, usuario)
        wb = load_workbook(BytesIO(excel.body), data_only=True)
        self.assertEqual(wb["Resumo"]["B5"].value, 26)
        self.assertEqual(wb["Vendas por Vendedor"]["D2"].value, 26)
        pdf = exportar_dashboard_pdf(self.evento.id, self.db, usuario)
        self.assertTrue(pdf.body.startswith(b"%PDF"))


if __name__ == "__main__":
    unittest.main()
