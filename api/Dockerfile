# api/Dockerfile
FROM python:3.11-slim
WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# web-сервіс (worker все одно перепише CMD своїм Start Command)
CMD ["gunicorn","-w","2","-k","gthread","-t","120","-b","0.0.0.0:8080","main:app"]
