FROM python:3.9-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

ENV APP_PORT=8080
ENV APP_CONFIG=./App/configs/addressbook-local.yaml
ENV PYTHONPATH=/app/App

WORKDIR /app

COPY ./App/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

CMD ["python", "-m", "addrservice.tornado.server", "--port", "8080", "--config", "./App/configs/addressbook-local.yaml"]