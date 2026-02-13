FROM python:3.9-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

ENV APP_PORT=8080
ENV APP_CONFIG=../app/configs/addressbook-local.yaml
ENV PYTHONPATH=/app/

WORKDIR /app

COPY ../app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ../app ./app

EXPOSE 8080

CMD ["python", "-m", "addrservice.tornado.server", "--port", "8080", "--config", "/app/configs/addressbook-local.yaml"]