# api/save_session.py

from dotenv import load_dotenv
load_dotenv()  # читає api/.env

import os
from instagrapi import Client

# Забираємо креденшали
USERNAME = os.getenv("IG_USERNAME")
PASSWORD = os.getenv("IG_PASSWORD")

# Ініціалізуємо клієнта (без проксі, бо ми генеруємо сесію локально)
cl = Client()

# Логінимося та зберігаємо налаштування у файл
cl.login(USERNAME, PASSWORD)
cl.dump_settings("session.json")
print("✅ Session saved to api/session.json")