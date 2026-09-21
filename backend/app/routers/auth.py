from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session
from app.database import get_db
from app import security
from fastapi.security import OAuth2PasswordRequestForm

from app import models
from app.models import TipoPerfil, TokenRecuperacaoSenha
from app.models.token_recuperacao_model import gerar_token, gerar_expiracao
from app.schemas.usuario_schema import (
    UserCreate, UserResponse, Token, EsqueciSenhaRequest, RedefinirSenhaRequest,
)
from app.email_utils import enviar_email_recuperacao_senha, FRONTEND_URL
from datetime import datetime

router = APIRouter(prefix="/auth", tags=["Autenticação"])

@router.post("/registrar", response_model=UserResponse)
def registrar_usuario(user: UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(models.Usuario).filter(models.Usuario.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email já cadastrado.")

    # SEGURANÇA: esta rota é pública (sem autenticação), então o perfil é
    # sempre forçado para CLIENTE, ignorando qualquer valor enviado no body.
    hashed_password = security.get_password_hash(user.senha)
    novo_usuario = models.Usuario(
        nome=user.nome,
        email=user.email,
        senha_hash=hashed_password,
        perfil=TipoPerfil.CLIENTE,
    )

    db.add(novo_usuario)
    db.commit()
    db.refresh(novo_usuario)
    return novo_usuario

@router.post("/login")
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    user = db.query(models.Usuario).filter(models.Usuario.email == form_data.username).first()

    if not user or not security.verify_password(form_data.password, user.senha_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="E-mail ou senha incorretos."
        )

    access_token = security.create_access_token(
        data={"id": user.id, "perfil": user.perfil.value, "sub": str(user.id)}
    )
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me", response_model=UserResponse)
def obter_meu_perfil(
    usuario: dict = Depends(security.get_usuario_atual),
    db: Session = Depends(get_db)
):
    user = db.query(models.Usuario).filter(models.Usuario.id == usuario["id"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuário não encontrado")
    return user


@router.post("/esqueci-senha")
def esqueci_senha(
    dados: EsqueciSenhaRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    """
    Sempre retorna a mesma mensagem genérica, exista ou não o e-mail no
    banco — evita que alguém descubra quais e-mails estão cadastrados
    testando essa rota (enumeration attack).
    """
    usuario = db.query(models.Usuario).filter(models.Usuario.email == dados.email).first()

    if usuario:
        token_registro = TokenRecuperacaoSenha(
            usuario_id=usuario.id,
            token=gerar_token(),
            expira_em=gerar_expiracao(),
        )
        db.add(token_registro)
        db.commit()
        db.refresh(token_registro)

        link = f"{FRONTEND_URL}/redefinir-senha?token={token_registro.token}"
        # Se a solicitação veio da tela do cliente (dentro de um evento
        # específico), carrega o evento_id no link para saber trazer o
        # cliente de volta para a tela daquele evento depois de redefinir.
        if dados.evento_id is not None:
            link += f"&evento_id={dados.evento_id}"

        background_tasks.add_task(
            enviar_email_recuperacao_senha, usuario.email, usuario.nome, link
        )

    return {
        "mensagem": "Se este e-mail estiver cadastrado, você receberá um link de recuperação em instantes."
    }


@router.post("/redefinir-senha")
def redefinir_senha(dados: RedefinirSenhaRequest, db: Session = Depends(get_db)):
    token_registro = (
        db.query(TokenRecuperacaoSenha)
        .filter(TokenRecuperacaoSenha.token == dados.token)
        .first()
    )

    if not token_registro:
        raise HTTPException(status_code=400, detail="Token inválido.")
    if token_registro.usado:
        raise HTTPException(status_code=400, detail="Este link já foi utilizado.")
    if token_registro.expira_em < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Este link expirou. Solicite um novo.")
    if len(dados.nova_senha) < 6:
        raise HTTPException(status_code=400, detail="A senha deve ter ao menos 6 caracteres.")

    usuario = db.query(models.Usuario).filter(models.Usuario.id == token_registro.usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")

    usuario.senha_hash = security.get_password_hash(dados.nova_senha)
    token_registro.usado = True
    db.commit()

    return {"mensagem": "Senha redefinida com sucesso. Você já pode fazer login."}