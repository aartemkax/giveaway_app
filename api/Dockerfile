# api/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Скопіювати файл сесії та налаштування (з поточної теки api/)
COPY session.json ./session.json
COPY settings.json ./settings.json

# Скопіювати залежності і встановити
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Скопіювати весь бекенд-код
COPY . .

# Порт, на якому слухає Gunicorn
EXPOSE 8080

# Запуск
CMD ["gunicorn", "main:app", "--bind", "0.0.0.0:$PORT"]
