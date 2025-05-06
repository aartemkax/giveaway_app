# api/Dockerfile
FROM python:3.11-slim

# 1. Папка всередині контейнера
WORKDIR /app

# 2. Скопіювати сесію та налаштування
COPY api/session.json ./session.json
COPY api/settings.json ./settings.json

# 3. Скопіювати requirements та встановити їх
COPY api/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# 4. Скопіювати увесь код бекенду
COPY api ./

# 5. Відкрити порт 8080 (Railway підставляє $PORT, але зазвичай 8080)
EXPOSE 8080

# 6. Запуск gunicorn
CMD ["gunicorn", "main:app", "--bind", "0.0.0.0:$PORT"]
