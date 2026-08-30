import logging
import time
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from app.database import engine, Base
from app.routers import auth, evento, barraca
from app.models import User, Evento, Barraca

Base.metadata.create_all(bind=engine)
# --- CONFIGURAÇÃO DO LOGGER PARA ARQUIVO .TXT ---
logger = logging.getLogger("evently_backend")
logger.setLevel(logging.INFO)

# Handler 1: Salva no arquivo app.log.txt
file_handler = logging.FileHandler("app.log.txt", encoding="utf-8")
file_formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
file_handler.setFormatter(file_formatter)

# Handler 2: Exibe no Terminal (para acompanhar em tempo real)
stream_handler = logging.StreamHandler()
stream_handler.setFormatter(file_formatter)

# Limpa handlers antigos para não duplicar linhas ao dar reload
if logger.hasHandlers():
    logger.handlers.clear()

logger.addHandler(file_handler)
logger.addHandler(stream_handler)

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Evently API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- MIDDLEWARE PARA REGISTRAR TODAS AS REQUISIÇÕES HTTP NO TXT ---
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    
    # Processa a requisição
    response = await call_next(request)
    
    # Calcula o tempo gasto
    process_time = (time.time() - start_time) * 1000
    
    # Formata a linha do log
    log_msg = f"HTTP {request.method} {request.url.path} | Status: {response.status_code} | Tempo: {process_time:.2f}ms"
    logger.info(log_msg)
    
    return response

app.include_router(auth.router)
app.include_router(evento.router)
app.include_router(barraca.router)

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