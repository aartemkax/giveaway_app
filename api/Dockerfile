# 1️⃣ Базовый образ с нужной версией Python
FROM python:3.11-slim

# 2️⃣ Рабочая директория
WORKDIR /app

# 3️⃣ Копируем зависимости и ставим их (кешируется между сборками)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4️⃣ Копируем весь код
COPY . .

# 5️⃣ Открываем порт 8000
EXPOSE 8000

# 6️⃣ Запускаем через Gunicorn, биндим на $PORT (Railway подставит нужный)
CMD ["gunicorn", "main:app", "--bind", "0.0.0.0:$PORT"]

