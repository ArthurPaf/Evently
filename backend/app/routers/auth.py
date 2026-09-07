from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app import security
from fastapi.security import OAuth2PasswordRequestForm

from app import models
from app.schemas.usuario_schema import UserCreate, UserResponse, Token

router = APIRouter(prefix="/auth", tags=["Autenticação"])

@router.post("/registrar", response_model=UserResponse)
def registrar_usuario(user: UserCreate, db: Session = Depends(get_db)):
    # Verifica se o email já existe
    db_user = db.query(models.Usuario).filter(models.Usuario.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email já cadastrado.")
    
    # Cria o usuário com a senha criptografada
    hashed_password = security.get_password_hash(user.senha)
    novo_usuario = models.Usuario(
        nome=user.nome,
        email=user.email,
        senha_hash=hashed_password,
        perfil=user.perfil
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
    # Altere de models.User para models.Usuario
    user = db.query(models.Usuario).filter(models.Usuario.email == form_data.username).first()
    
    if not user or not security.verify_password(form_data.password, user.senha_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="E-mail ou senha incorretos."
        )

    # Gere o token normalmente usando os dados do usuario
    access_token = security.create_access_token(data={"id": user.id, "perfil": user.perfil.value, "sub": str(user.id)})
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