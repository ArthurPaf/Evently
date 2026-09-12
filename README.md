# 🎪 Gestão de Eventos & Barracas

Um sistema Full-Stack completo para gerenciamento de eventos e barracas organizacionais. O projeto permite cadastrar eventos, criar barracas associadas e selecionar/atribuir responsáveis cadastrados no sistema em tempo real.
O sistema também conta com uma url para o cliente que terá seu QrCode para adicionar créditos e fazer suas compras no evento.
---

## 🛠️ Tecnologias Utilizadas

### **Frontend (Mobile / Web)**
- **[Flutter](https://flutter.dev/)** — Framework UI multiplataforma.
- **[Riverpod](https://riverpod.dev/)** — Gerenciamento de estado reativo e injeção de dependências.
- **HTTP (http package)** — Integração e consumo de APIs RESTful.

### **Backend (API)**
- **[Python 3.14+](https://www.python.org/)** — Linguagem base do backend.
- **[FastAPI](https://fastapi.tiangolo.com/)** — Framework web assíncrono e de alto desempenho.
- **[SQLAlchemy](https://www.sqlalchemy.org/)** — ORM para mapeamento e manipulação do banco de dados.
- **[Pydantic v2](https://docs.pydantic.dev/)** — Validação de dados e definição de schemas de entrada/saída.
- **[Uvicorn](https://www.uvicorn.org/)** — Server ASGI leve para execução da aplicação FastAPI.

---

## 🚀 Funcionalidades Principais

- 📅 **Gestão de Eventos:** Criação e listagem de eventos.
- 🎪 **Gestão de Barracas:** Cadastro de barracas (Nome, Tipo) vinculadas a um evento específico.
- 👤 **Seleção Reativa de Responsável:**
  - Componente desacoplado (`SeletorUsuarioWidget`) que busca os usuários cadastrados via API.
  - Filtro e pesquisa em tempo real por nome ou e-mail.
  - Associação dinâmica da chave estrangeira `responsavel_id` na entidade `Barraca`.
- 🔐 **Autenticação e Usuários:** Integração com serviços de usuário existentes na aplicação.

---
