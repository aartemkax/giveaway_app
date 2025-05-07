FROM python:3.11-slim
WORKDIR /app

# dependencies
COPY api/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# весь бекенд
COPY api/ . 

EXPOSE 8080
CMD ["gunicorn", "main:app", "--bind", "0.0.0.0:$PORT"]
