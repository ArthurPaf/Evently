from dotenv import load_dotenv
load_dotenv()
import logging
import time
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.routers import admin_router
from app.database import Base, engine
# Import do produto router adicionado para disponibilizar a API de produtos
from app.routers import auth, barraca, evento
from app.routers import produto_router as produto
from app.routers import vendedor
from app.routers import administrador_router
from app.routers import cliente_router, transacao_router

# Criação única das tabelas
Base.metadata.create_all(bind=engine)

# --- CONFIGURAÇÃO DO LOGGER PARA ARQUIVO .TXT ---
logger = logging.getLogger("evently_backend")
logger.setLevel(logging.INFO)

file_handler = logging.FileHandler("app.log.txt", encoding="utf-8")
file_formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
file_handler.setFormatter(file_formatter)

stream_handler = logging.StreamHandler()
stream_handler.setFormatter(file_formatter)

if logger.hasHandlers():
    logger.handlers.clear()

logger.addHandler(file_handler)
logger.addHandler(stream_handler)

app = FastAPI(title="Evently API")
app.include_router(admin_router.router)
app.include_router(vendedor.router)
app.include_router(produto.produto_direct_router)
app.include_router(administrador_router.router)
app.include_router(cliente_router.router)
app.include_router(transacao_router.router)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- MIDDLEWARE PARA REGISTRAR REQUISIÇÕES HTTP ---
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = (time.time() - start_time) * 1000
    
    log_msg = f"HTTP {request.method} {request.url.path} | Status: {response.status_code} | Tempo: {process_time:.2f}ms"
    logger.info(log_msg)
    
    return response

# Registro dos Routers
app.include_router(auth.router)
app.include_router(evento.router)
app.include_router(barraca.router)
# Registra as rotas diretas de PUT/DELETE em /barracas/{id}/
app.include_router(barraca.barraca_direct_router) 
# Registra as rotas de produtos
app.include_router(produto.router)

@app.on_event("startup")
async def startup_event():
    logger.info("=== SISTEMA INICIADO E LOGS EM ARQUIVO ATIVADOS ===")

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    logger.error(f"Erro 422 de Validação na rota {request.url.path}: {exc.errors()}")
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors()},
    )