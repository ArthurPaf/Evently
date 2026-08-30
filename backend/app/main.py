from fastapi import FastAPI
from app.database import engine, Base
from app.routers import auth, evento
from fastapi.middleware.cors import CORSMiddleware

# Cria as tabelas no banco de dados (neste primeiro momento, sem usar o alembic para simplificar)
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Evently API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Na fase de testes, liberamos para qualquer origem
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inclui as rotas
app.include_router(auth.router)
app.include_router(evento.router)

@app.get("/")
def read_root():
    return {"mensagem": "Bem-vindo à API do Evently!"}