import os
import smtplib
import ssl
import logging
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.image import MIMEImage
from email.mime.application import MIMEApplication
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


def _gerar_pdf_cartao(qr_bytes: bytes, nome_cliente: str, nome_evento: str, codigo: str) -> bytes:
    """
    Gera um PDF com o QR Code e o código do cartão virtual, para o cliente
    salvar/imprimir e usar mesmo sem internet ou sem conseguir abrir o app.
    (O vendedor, na hora da venda, ainda precisa de conexão para validar
    e debitar o saldo — isso não muda.)
    """
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import cm
    from reportlab.pdfgen import canvas
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
        largura / 2, y_qr - 2 * cm,
        "Guarde este cartão. Apresente-o nas barracas mesmo sem conexão à internet.",
    )

    c.showPage()
    c.save()
    buffer.seek(0)
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

        # Anexa também um PDF do cartão, para uso sem internet / impressão
        try:
            pdf_bytes = _gerar_pdf_cartao(qr_bytes, nome_cliente, nome_evento, codigo)
            anexo_pdf = MIMEApplication(pdf_bytes, _subtype="pdf")
            anexo_pdf.add_header(
                "Content-Disposition", "attachment", filename="cartao_virtual_evently.pdf"
            )
            mensagem.attach(anexo_pdf)
        except Exception as e:
            # Se a geração do PDF falhar por qualquer motivo (ex: reportlab
            # não instalado), o e-mail ainda é enviado com o QR Code inline.
            logger.warning(f"Não foi possível anexar o PDF do cartão: {str(e)}")

        contexto = ssl.create_default_context()
        with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, context=contexto) as servidor:
            servidor.login(SMTP_USER, SMTP_PASSWORD)
            servidor.sendmail(SMTP_USER, destinatario, mensagem.as_string())

        logger.info(f"Cartão virtual enviado com sucesso para {destinatario}")
    except Exception as e:
        logger.error(f"Falha ao enviar cartão virtual para {destinatario}: {str(e)}", exc_info=True)