import os
import smtplib
import ssl
import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.image import MIMEImage
from io import BytesIO

logger = logging.getLogger("evently_backend")

SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "465"))
SMTP_USER = os.environ.get("SMTP_USER")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD")
SMTP_FROM_NAME = os.environ.get("SMTP_FROM_NAME", "Evently")


def _gerar_qr_code_bytes(conteudo: str) -> bytes:
    import qrcode
    img = qrcode.make(conteudo)
    buffer = BytesIO()
    img.save(buffer, format="PNG")
    return buffer.getvalue()


def enviar_cartao_virtual(destinatario: str, nome_cliente: str, nome_evento: str, codigo: str) -> None:
    """
    Envia por e-mail o cartão virtual (QR Code + código) do cliente para um evento.
    Uma falha de envio NUNCA deve travar o fluxo do usuário: qualquer erro aqui é
    apenas logado, e o cliente continua podendo usar o QR Code direto no app.
    """
    if not SMTP_USER or not SMTP_PASSWORD:
        logger.warning(
            "Envio de e-mail não configurado (SMTP_USER/SMTP_PASSWORD ausentes). "
            f"Cartão virtual de {destinatario} não foi enviado."
        )
        return

    try:
        qr_bytes = _gerar_qr_code_bytes(codigo)

        mensagem = MIMEMultipart("related")
        mensagem["Subject"] = f"Seu cartão virtual - {nome_evento}"
        mensagem["From"] = f"{SMTP_FROM_NAME} <{SMTP_USER}>"
        mensagem["To"] = destinatario

        html = f"""
        <html>
          <body style="font-family: Arial, sans-serif;">
            <h2>Olá, {nome_cliente}!</h2>
            <p>Seu cartão virtual para o evento <strong>{nome_evento}</strong> foi gerado com sucesso.</p>
            <p>Apresente o QR Code abaixo nas barracas de consumo, ou informe o código manualmente:</p>
            <p style="font-size: 20px; font-weight: bold; letter-spacing: 2px;">{codigo}</p>
            <img src="cid:qrcode_cartao" width="200" height="200" />
            <p style="color: #888; font-size: 12px;">Este saldo é válido apenas dentro deste evento.</p>
          </body>
        </html>
        """
        mensagem.attach(MIMEText(html, "html"))

        imagem = MIMEImage(qr_bytes)
        imagem.add_header("Content-ID", "<qrcode_cartao>")
        imagem.add_header("Content-Disposition", "inline", filename="qrcode.png")
        mensagem.attach(imagem)

        contexto = ssl.create_default_context()
        with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, context=contexto) as servidor:
            servidor.login(SMTP_USER, SMTP_PASSWORD)
            servidor.sendmail(SMTP_USER, destinatario, mensagem.as_string())

        logger.info(f"Cartão virtual enviado com sucesso para {destinatario}")
    except Exception as e:
        logger.error(f"Falha ao enviar cartão virtual para {destinatario}: {str(e)}", exc_info=True)