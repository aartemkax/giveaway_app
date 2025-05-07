# Dockerfile (в корені)
FROM python:3.11-slim

WORKDIR /app

# 1) Залежності
COPY api/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 2) Якщо ви досі зберігаєте файли сесії локально
COPY api/session.json ./session.json
COPY api/settings.json ./settings.json

# 3) Весь код бекенду
COPY api/ ./

EXPOSE 8080

CMD ["gunicorn", "main:app", "--bind", "0.0.0.0:$PORT"]