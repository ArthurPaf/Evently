from io import BytesIO
from datetime import datetime
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle

_ROXO = colors.HexColor("#6A1B9A")
_ROXO_CLARO = colors.HexColor("#F3E5F5")


def _tabela_padrao(cabecalho, linhas, larguras):
    tabela = Table([cabecalho] + linhas, colWidths=larguras)
    tabela.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), _ROXO),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("FONTSIZE", (0, 0), (-1, -1), 10),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, _ROXO_CLARO]),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    return tabela


def gerar_relatorio_pdf(nome_evento: str, dados: dict) -> bytes:
    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, topMargin=2 * cm, bottomMargin=2 * cm)
    styles = getSampleStyleSheet()
    titulo_style = ParagraphStyle("TituloEvently", parent=styles["Title"], textColor=_ROXO)
    subtitulo_style = ParagraphStyle(
        "Subtitulo", parent=styles["Heading2"], textColor=_ROXO, spaceBefore=18, spaceAfter=6
    )

    elementos = [
        Paragraph("Relatório Financeiro - Evently", titulo_style),
        Paragraph(nome_evento, styles["Heading3"]),
        Paragraph(
            f"Gerado em {datetime.now().strftime('%d/%m/%Y às %H:%M')}", styles["Normal"]
        ),
        Spacer(1, 1 * cm),
    ]

    # --- Resumo geral ---
    elementos.append(Paragraph("Resumo Geral", subtitulo_style))
    resumo = [
        ["Total Vendido", f"R$ {dados['total_vendido']:.2f}"],
        ["Número de Transações", str(dados["numero_transacoes"])],
    ]
    tabela_resumo = Table(resumo, colWidths=[8 * cm, 8 * cm])
    tabela_resumo.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), _ROXO_CLARO),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("FONTSIZE", (0, 0), (-1, -1), 11),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    elementos.append(tabela_resumo)

    # --- Produtos mais vendidos ---
    elementos.append(Paragraph("Produtos Mais Vendidos", subtitulo_style))
    if dados["produtos_mais_vendidos"]:
        linhas = [
            [p["nome"], str(p["quantidade"]), f"R$ {p['valor_total']:.2f}"]
            for p in dados["produtos_mais_vendidos"]
        ]
        elementos.append(
            _tabela_padrao(["Produto", "Quantidade", "Valor Total"], linhas, [8 * cm, 4 * cm, 4 * cm])
        )
    else:
        elementos.append(Paragraph("Nenhuma venda registrada.", styles["Normal"]))

    # --- Vendas por barraca (já vem ordenado do backend, do maior pro menor) ---
    elementos.append(Paragraph("Vendas por Barraca", subtitulo_style))
    if dados["vendas_por_barraca"]:
        linhas = [[b["barraca"], f"R$ {b['valor_total']:.2f}"] for b in dados["vendas_por_barraca"]]
        elementos.append(_tabela_padrao(["Barraca", "Valor Total"], linhas, [10 * cm, 6 * cm]))
    else:
        elementos.append(Paragraph("Nenhuma venda registrada.", styles["Normal"]))

    # --- Vendas por período (dia + hora) ---
    elementos.append(Paragraph("Vendas por Período", subtitulo_style))
    if dados["vendas_por_periodo"]:
        linhas = [[p["periodo"], f"R$ {p['valor_total']:.2f}"] for p in dados["vendas_por_periodo"]]
        elementos.append(_tabela_padrao(["Período", "Valor Total"], linhas, [10 * cm, 6 * cm]))
    else:
        elementos.append(Paragraph("Nenhuma venda registrada.", styles["Normal"]))

    doc.build(elementos)
    buffer.seek(0)
    return buffer.getvalue()