# 1️⃣ Базовый образ с нужной версией Python
FROM python:3.11-slim

# 2️⃣ Рабочая директория внутри контейнера
WORKDIR /app

# 3️⃣ Копируем только список зависимостей и сразу их ставим
#    — так Docker кеширует pip-install между сборками, если requirements.txt не менялся
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# 4️⃣ Копируем остальной код (включая main.py, static/, .env и т.д.)
COPY . .

# 5️⃣ Открываем порт 8000 (по умолчанию Gunicorn слушает на 8000)
EXPOSE 8000

# 6️⃣ Команда запуска: переводим HTTP‐запросы на наш Flask-приложение
#    main:app — значит "в модуле main найти переменную app"
CMD ["gunicorn", "main:app", "--bind", "0.0.0.0:8000"]
