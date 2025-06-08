# Dockerfile (в корені проєкту)
FROM python:3.11-slim
WORKDIR /app

# 1) Беремо єдиний requirements.txt з кореня
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 2) Копіюємо увесь бекенд з папки api/ у /app
COPY api/ . 

EXPOSE 8080

# 3) Запускаємо Gunicorn так, щоб слухав порт 8080
CMD ["gunicorn", "main:app", "--bind", "0.0.0.0:8080"]
