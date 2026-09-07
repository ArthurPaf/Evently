from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app import models, security
from app.models import TipoPerfil
from app.schemas.usuario_schema import UserCreate, VendedorResponse, AdministradorResponse

router = APIRouter(prefix="/admin", tags=["Administração"])


def _exigir_organizador(usuario: dict = Depends(security.get_usuario_atual)):
    if usuario["perfil"] != TipoPerfil.ORGANIZADOR.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas organizadores podem realizar esta ação.",
        )
    return usuario


# --- VENDEDORES (já existia) ---

@router.post("/vendedores", response_model=VendedorResponse, status_code=status.HTTP_201_CREATED)
def criar_vendedor(
    user: UserCreate,
    db: Session = Depends(get_db),
    _organizador: dict = Depends(_exigir_organizador),
):
    db_user = db.query(models.Usuario).filter(models.Usuario.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email já cadastrado.")

    hashed_password = security.get_password_hash(user.senha)
    novo_vendedor = models.Usuario(
        nome=user.nome,
        email=user.email,
        senha_hash=hashed_password,
        perfil=TipoPerfil.VENDEDOR,
    )

    db.add(novo_vendedor)
    db.commit()
    db.refresh(novo_vendedor)
    return novo_vendedor


@router.get("/vendedores", response_model=List[VendedorResponse])
def listar_vendedores(
    db: Session = Depends(get_db),
    usuario: dict = Depends(security.get_usuario_atual),
):
    return db.query(models.Usuario).filter(models.Usuario.perfil == TipoPerfil.VENDEDOR).all()


# --- ADMINISTRADORES (novo) ---

@router.post("/administradores", response_model=AdministradorResponse, status_code=status.HTTP_201_CREATED)
def criar_administrador(
    user: UserCreate,
    db: Session = Depends(get_db),
    _organizador: dict = Depends(_exigir_organizador),
):
    db_user = db.query(models.Usuario).filter(models.Usuario.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email já cadastrado.")

    hashed_password = security.get_password_hash(user.senha)
    novo_admin = models.Usuario(
        nome=user.nome,
        email=user.email,
        senha_hash=hashed_password,
        perfil=TipoPerfil.ADMINISTRADOR,  # força o perfil, ignora o que vier no body
    )

    db.add(novo_admin)
    db.commit()
    db.refresh(novo_admin)
    return novo_admin


@router.get("/administradores", response_model=List[AdministradorResponse])
def listar_administradores(
    db: Session = Depends(get_db),
    usuario: dict = Depends(security.get_usuario_atual),  # qualquer logado pode listar (pro dropdown)
):
    return db.query(models.Usuario).filter(models.Usuario.perfil == TipoPerfil.ADMINISTRADOR).all()