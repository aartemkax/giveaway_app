# 1️⃣ Базовый образ с нужной версией Python
FROM python:3.11-slim

# 2️⃣ Рабочая директория
WORKDIR /app

# 3️⃣ Копируем зависимости и ставим их (кешируется между сборками)
COPY requirements.txt .
COPY api/session.json ./session.json
RUN pip install --no-cache-dir -r requirements.txt

# 4️⃣ Копируем весь код
COPY . .

# 5️⃣ Открываем (декларируем) порт 8000
EXPOSE 8000

# 6️⃣ Запуск через gunicorn з підставленням $PORT
# Використовуємо sh -c, щоб перемінна розгорнулася в контейнері
CMD ["sh","-c","gunicorn main:app --bind 0.0.0.0:$PORT"]



