import base64
import json
import logging
import os
from html import escape
from io import BytesIO
from urllib.error import HTTPError
from urllib.request import Request, urlopen

logger = logging.getLogger("evently_backend")

BREVO_API_KEY = os.environ.get("BREVO_API_KEY")
BREVO_SENDER_EMAIL = os.environ.get("BREVO_SENDER_EMAIL")
BREVO_SENDER_NAME = os.environ.get("BREVO_SENDER_NAME", "Evently")
FRONTEND_URL = os.environ.get("FRONTEND_URL", "http://localhost:5000")
BREVO_API_URL = "https://api.brevo.com/v3/smtp/email"


def _enviar_email_brevo(destinatario: str, assunto: str, html: str, anexos=None) -> bool:
    """Solicita o envio pela Brevo via HTTPS; não interrompe a requisição em caso de falha."""
    if not BREVO_API_KEY or not BREVO_SENDER_EMAIL:
        logger.warning("Brevo não configurada: BREVO_API_KEY ou BREVO_SENDER_EMAIL ausente.")
        return False

    payload = {
        "sender": {"name": BREVO_SENDER_NAME, "email": BREVO_SENDER_EMAIL},
        "to": [{"email": destinatario}],
        "subject": assunto,
        "htmlContent": html,
    }
    if anexos:
        payload["attachment"] = anexos

    requisicao = Request(
        BREVO_API_URL,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "api-key": BREVO_API_KEY,
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )

    try:
        with urlopen(requisicao, timeout=25) as resposta:
            resultado = json.loads(resposta.read().decode("utf-8"))
        logger.info(
            "Brevo aceitou o e-mail para %s (messageId: %s)",
            destinatario,
            resultado.get("messageId", "indisponível"),
        )
        return True
    except HTTPError as erro:
        detalhe = erro.read().decode("utf-8", errors="replace")[:500]
        logger.error(
            "Brevo recusou o envio para %s (HTTP %s): %s",
            destinatario,
            erro.code,
            detalhe,
        )
    except Exception:
        logger.exception("Falha na comunicação com a Brevo ao enviar para %s", destinatario)
    return False


def _gerar_qr_code_bytes(conteudo: str) -> bytes:
    import qrcode

    img = qrcode.make(conteudo)
    buffer = BytesIO()
    img.save(buffer, format="PNG")
    return buffer.getvalue()


def _gerar_pdf_cartao(qr_bytes: bytes, nome_cliente: str, nome_evento: str, codigo: str) -> bytes:
    """Gera o mesmo cartão virtual em PDF usado no Evently."""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import cm
    from reportlab.lib.pdfgen import canvas
    from reportlab.lib.utils import ImageReader

    buffer = BytesIO()
    c = canvas.Canvas(buffer, pagesize=A4)
    largura, altura = A4

    c.setFont("Helvetica-Bold", 20)
    c.drawCentredString(largura / 2, altura - 4 * cm, "Cartão Virtual - Evently")
    c.setFont("Helvetica", 14)
    c.drawCentredString(largura / 2, altura - 5.2 * cm, nome_evento)
    c.setFont("Helvetica", 12)
    c.drawCentredString(largura / 2, altura - 6 * cm, f"Titular: {nome_cliente}")

    qr_image = ImageReader(BytesIO(qr_bytes))
    tamanho_qr = 8 * cm
    x_qr = (largura - tamanho_qr) / 2
    y_qr = altura - 15 * cm
    c.drawImage(qr_image, x_qr, y_qr, width=tamanho_qr, height=tamanho_qr)

    c.setFont("Helvetica-Bold", 16)
    c.drawCentredString(largura / 2, y_qr - 1 * cm, f"Código: {codigo}")
    c.setFont("Helvetica-Oblique", 10)
    c.drawCentredString(
        largura / 2,
        y_qr - 2 * cm,
        "Guarde este cartão. Apresente nas barracas mesmo sem conexão à internet.",
    )

    c.showPage()
    c.save()
    return buffer.getvalue()


def enviar_email_recuperacao_senha(destinatario: str, nome_usuario: str, link_redefinicao: str) -> None:
    """Envia link de recuperação pela API HTTPS da Brevo."""
    nome_seguro = escape(nome_usuario)
    link_seguro = escape(link_redefinicao, quote=True)
    html = f"""
    <html>
      <body style="font-family:Arial,sans-serif;">
        <h2>Olá, {nome_seguro}!</h2>
        <p>Recebemos uma solicitação para redefinir a senha da sua conta no Evently.</p>
        <p><a href="{link_seguro}"
              style="background-color:#6A1B9A;color:white;padding:10px 20px;
                     text-decoration:none;border-radius:6px;display:inline-block;">
              Redefinir minha senha
           </a></p>
        <p style="color:#888;font-size:12px;">
          Este link expira em 30 minutos. Se você não solicitou essa alteração,
          pode ignorar este e-mail com segurança — sua senha não será alterada.
        </p>
      </body>
    </html>
    """
    _enviar_email_brevo(destinatario, "Recuperação de senha - Evently", html)


def enviar_cartao_virtual(destinatario: str, nome_cliente: str, nome_evento: str, codigo: str) -> None:
    """Envia cartão virtual com QR Code PNG e PDF anexados pela API HTTPS da Brevo."""
    try:
        qr_bytes = _gerar_qr_code_bytes(codigo)
        anexos = [
            {
                "name": "qrcode.png",
                "content": base64.b64encode(qr_bytes).decode("ascii"),
            }
        ]
        try:
            pdf_bytes = _gerar_pdf_cartao(qr_bytes, nome_cliente, nome_evento, codigo)
            anexos.append(
                {
                    "name": "cartao_virtual_evently.pdf",
                    "content": base64.b64encode(pdf_bytes).decode("ascii"),
                }
            )
        except Exception:
            logger.exception("Não foi possível gerar o PDF do cartão virtual.")

        html = f"""
        <html>
          <body style="font-family:Arial,sans-serif;">
            <h2>Olá, {escape(nome_cliente)}!</h2>
            <p>Seu cartão virtual para o evento
               <strong>{escape(nome_evento)}</strong> foi gerado com sucesso.</p>
            <p>Seu código para as barracas:</p>
            <p style="font-size:20px;font-weight:bold;letter-spacing:2px;">
              {escape(codigo)}
            </p>
            <p>O QR Code está anexado como imagem PNG. O cartão completo
               está disponível em PDF, quando a geração do PDF for concluída.</p>
            <p style="color:#888;font-size:12px;">
              Este saldo é válido apenas dentro deste evento.
            </p>
          </body>
        </html>
        """
        _enviar_email_brevo(
            destinatario,
            f"Seu cartão virtual - {nome_evento}",
            html,
            anexos=anexos,
        )
    except Exception:
        logger.exception("Falha ao preparar cartão virtual para %s", destinatario)
