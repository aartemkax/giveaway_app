# giveaway_app — вижимка проєкту

Цей файл призначений для швидкого handoff в інший чат або іншому розробнику.
Більш практичний onboarding і команди запуску винесені в [README.md](/Users/starlord/giveaway_app/README.md).

## 1. Що це за проєкт

`giveaway_app` — це Flutter-застосунок для проведення Instagram giveaway / розіграшів з Python-бекендом на Flask.

У проєкті є 2 основні сценарії роботи:

1. `Facebook/Instagram Graph API flow`
   Користувач логіниться через Facebook OAuth, бекенд отримує доступ до сторінок і підключених Instagram business/creator акаунтів, після чого можна:
   - отримати список IG-акаунтів;
   - завантажити медіа;
   - завантажити коментарі;
   - відфільтрувати учасників;
   - провести жеребкування з audit-даними.

2. `Instagram session / instagrapi flow`
   Користувач логіниться в Instagram через логін/пароль або через `sessionid`.
   Бекенд зберігає серверну IG-сесію і через `instagrapi` асинхронно витягує коментарі з поста, формуючи пул учасників.

Додатково є `admin/account-affinity` шар:
- можна зберігати окремі Instagram-акаунти;
- прив’язувати до них проксі;
- запускати account-scoped async jobs;
- зберігати цей стан у Redis.

## 2. Основний стек

- Frontend: Flutter 3 / Dart 3
- State management: Riverpod
- HTTP client: Dio + cookie jar
- Локальне збереження: SharedPreferences
- Локалізація: `uk`, `en`, `fr`
- Backend API: Flask
- Черги: Redis + RQ
- Instagram неофіційний доступ: `instagrapi`
- Facebook/Instagram офіційний доступ: Graph API v21
- Smoke tests: Playwright
- Деплой бекенду схожий на Railway

## 3. Архітектура

### Flutter-клієнт

Головна точка входу: `lib/main.dart`

Клієнт:
- читає `API_BASE_URL` з `.env`;
- ініціалізує `ApiClient`;
- визначає тип авторизації через `SharedPreferences`;
- направляє користувача або у Facebook flow, або у IG participants flow.

Ключові екрани:
- `lib/screens/login/app_login_screen.dart`
  стартовий екран, дає вибір між Facebook OAuth і Instagram/private flow.
- `lib/screens/password_login_screen.dart`
  логін в Instagram через логін/пароль, з fallback на `sessionid`.
- `lib/screens/fb_home_screen.dart`
  перевіряє FB-сесію і показує доступні IG-акаунти з Graph API.
- `lib/screens/ig_media_screen.dart`
  список медіа IG-акаунта, плюс пошук media по permalink.
- `lib/screens/ig_comments_screen.dart`
  завантаження коментарів, фільтрація, draw, копіювання winners/CSV.
- `lib/screens/login/participants_screen.dart`
  “простий” сценарій для session-based IG login: вводиш URL поста, отримуєш учасників, локально обираєш переможців.

### Python API

Головна точка входу: `api/main.py`

Що робить бекенд:
- тримає Flask session у Redis;
- приймає логін в Instagram;
- збирає/емуляє device payload;
- працює з `instagrapi`;
- запускає async jobs через RQ;
- інтегрується з Facebook OAuth і Graph API;
- віддає admin endpoints для акаунтів і проксі.

Додаткові модулі:
- `api/tasks.py` — worker-задачі для асинхронного збору учасників;
- `api/fb_graph.py` — обгортка над Facebook Graph API;
- `api/account_affinity.py` — модель акаунтів/проксі та їх зберігання в Redis;
- `api/device_emulator.py` — серверна емуляція device profile;
- `api/app.py` — схоже на застарілий/дублюючий файл з частиною маршрутів.

## 4. Ключові флоу

### A. Facebook / Graph API flow

1. Flutter відкриває `/api/fb/login_url`
2. Користувач проходить Facebook OAuth
3. Бекенд зберігає `fb_user_token` у server session
4. Flutter викликає `/api/ig/accounts`
5. Далі доступні:
   - `/api/ig/media`
   - `/api/ig/resolve_media`
   - `/api/ig/comments`
   - `/api/ig/comments_all`
   - `/api/ig/comments_filter`
   - `/api/ig/run_draw`
   - `/api/ig/export_csv`

Сильна сторона цього flow:
- є більш “офіційний” сценарій для бізнес/creator акаунтів;
- є audit-пакет у `/api/ig/run_draw` (`seed`, `pool_hash`, counts, filters).

### B. Instagram login / instagrapi flow

1. Flutter збирає fingerprint пристрою
2. Відправляє його на:
   - `/api/collect_device_geo`
   - `/api/device_report`
3. Потім викликає `/api/login`
4. Бекенд логіниться в Instagram через `instagrapi`
5. Сесія зберігається в Flask session (`ig_settings`)
6. Flutter запускає `/api/fetch_participants_async`
7. Бекенд ставить задачу в RQ
8. Flutter полить:
   - `/api/job_status/<job_id>`
   - `/api/job_result/<job_id>`

Особливість:
- у простому session-flow переможці фактично обираються на фронтенді після отримання списку учасників.

### C. Account affinity / admin flow

Є окремий бекенд-шар для збереження IG-акаунтів і проксі:
- `/api/admin/accounts`
- `/api/admin/proxies`
- `/api/admin/accounts/from_current_session`
- `/api/admin/accounts/from_sessionid`
- `/api/admin/accounts/<account_id>`
- `/api/admin/accounts/<account_id>/bind_proxy`
- `/api/admin/accounts/<account_id>/sync_session`
- `/api/admin/accounts/<account_id>/fetch_participants_async`

Це виглядає як підготовка до multi-account режиму, де один акаунт закріплений за одним проксі і виконує jobs із власною session settings.

## 5. Де зберігається стан

### На клієнті

- `SharedPreferences`
  - `auth_method`
  - `active_account_id`
  - `isLoggedIn` (частково)
- cookie jar для HTTP cookie

### На бекенді

- Flask Session у Redis:
  - `ig_settings`
  - `emu_cache`
  - `fb_user_token`
  - `ig_graph_settings`
- Redis для:
  - RQ jobs
  - account/proxy affinity store
  - optional caches

## 6. Що потрібно для запуску

### Flutter

Мінімум:
- Flutter SDK
- файл `.env` з `API_BASE_URL`

У `lib/utils/constants.dart` base URL береться з `.env`, fallback:
- `http://10.0.2.2:8080`

Базовий запуск:

```bash
flutter pub get
flutter run
```

### Backend

Мінімум:
- Python 3.11
- Redis
- залежності з `api/requirements.txt`

Базовий локальний запуск:

```bash
cd api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python main.py
```

Для async jobs окремо потрібен worker:

```bash
cd api
source .venv/bin/activate
python -m rq worker --with-scheduler -u "$REDIS_URL" -P .
```

Для повноцінної роботи потрібні env-перемінні щонайменше для:
- `FLASK_SECRET_KEY`
- `REDIS_URL`
- `SESSION_COOKIE_SECURE`
- `FB_APP_ID`
- `FB_APP_SECRET`
- `FB_REDIRECT_URI`
- опціонально проксі:
  - `INSTAGRAM_AUTH_PROXIES`
  - `INSTAGRAM_PROXIES`
  - `PROXIES`

Без Redis проєкт не зможе нормально працювати, бо на ньому тримаються:
- Flask Session
- RQ queue
- account affinity store

## 7. Тести

Є Playwright API smoke tests:
- `tests/playwright/admin-api.spec.ts`

Базовий запуск:

```bash
npm install
npm run test:api
```

Вони покривають переважно staging admin/account-affinity API:
- `runtime_info`
- списки акаунтів і проксі
- валідацію admin endpoints
- створення account/proxy
- bind proxy
- enqueue account-scoped async jobs

Тобто тестове покриття є, але воно вузьке:
- майже немає покриття Flutter UI;
- майже немає unit-тестів;
- тестується не весь продукт, а головно бекенд admin API.

## 8. Сильні сторони проєкту

- Є відразу два робочі бізнес-сценарії: офіційний Graph API і session-based Instagram flow.
- Бекенд уже має async job модель через Redis/RQ.
- Є device fingerprint / device emulation pipeline.
- Є multi-account foundation через affinity store.
- Є локалізація на 3 мови.
- Є базові smoke-тести для staging.
- Є audit-дані для прозорого draw у Graph API сценарії.

## 9. Слабкі місця та технічний борг

1. README майже порожній.
   Поточний `README.md` — стандартна заготовка Flutter і не описує реальний продукт.

2. У репозиторії є ознаки змішаних/дубльованих сценаріїв.
   Є старі й нові сервіси (`lib/services/auth_service.dart` і `lib/services/appapi/app_auth_service.dart`, аналогічно для participants), а також старі екрани в `lib/screens/` і нові в `lib/screens/login/`.

3. `api/app.py` виглядає як застарілий дубль частини `api/main.py`.

4. Є недоопрацьована логіка унікальності у simple participants screen.
   У `lib/screens/login/participants_screen.dart` прямо вказано, що `UniqueBy.comment` і `UniqueBy.both` поки працюють як плейсхолдер, бо модель `Participant` не містить `commentId`.

5. У локалізації є дублікати ключів.
   У `lib/l10n/app_uk.arb` повторюються деякі записи (`error_generic`, `error_internal_error`, `error_instagram_challenge`, `open_instagram_button`).

6. У `api/tasks.py` є мертвий код після `return`.
   Це сигнал, що worker-файл потребує прибирання.

7. Конфіг деплою виглядає неузгодженим.
   У корені є `railway.json`, який посилається на `Dockerfile`, але в репозиторії є лише `api/Dockerfile`.

8. У репозиторії лежать build artifacts.
   Папка `docs/` містить зібраний Flutter web build.

9. Поточна структура repo вже досить “операційна”, але ще не приведена до чистої продуктово-документованої форми.

## 10. Що це за продукт з точки зору бізнесу

Це внутрішній або напівпродуктовий інструмент для проведення розіграшів в Instagram, орієнтований на 2 типи кейсів:

- `Публічні / business / creator сторінки`
  через Facebook OAuth + Instagram Graph API.

- `Приватні або менш офіційні сценарії`
  через Instagram session login + `instagrapi`.

Фактично це не просто “рандомайзер”, а комбайн для:
- авторизації;
- доступу до Instagram коментарів;
- фільтрації учасників;
- випадкового вибору переможців;
- частково прозорого аудиту результату.

## 11. Якщо передавати цей проєкт в інший чат, коротко

Можна описати так:

> Це Flutter + Flask/Redis проєкт для проведення Instagram giveaway.
> Він підтримує 2 режими: офіційний Facebook/Instagram Graph API flow для business/creator акаунтів і session-based Instagram flow через instagrapi.
> Flutter-клієнт керує логіном, вибором поста і відображенням результатів, а Flask-бекенд тримає сесії, працює з Facebook OAuth, запускає async jobs через RQ і зберігає account/proxy state у Redis.
> У проєкті вже є staging smoke tests, локалізація та базовий multi-account фундамент, але є техборг: слабка документація, дубльовані сервіси/екрани, застарілі файли, артефакти збірки і кілька не доведених до кінця ділянок логіки.

## 12. Найважливіші файли

- `lib/main.dart` — старт Flutter app і маршрути
- `lib/utils/constants.dart` — конфіг API base URL
- `lib/screens/login/app_login_screen.dart` — вибір сценарію входу
- `lib/screens/password_login_screen.dart` — Instagram login/password + session fallback
- `lib/screens/login/participants_screen.dart` — simple draw flow
- `lib/screens/fb_home_screen.dart` — Facebook flow entry
- `lib/screens/ig_media_screen.dart` — список медіа
- `lib/screens/ig_comments_screen.dart` — коментарі, фільтри, draw
- `lib/services/api_client.dart` — Dio + cookies
- `api/main.py` — основний Flask API
- `api/tasks.py` — async worker logic
- `api/account_affinity.py` — аккаунти/проксі в Redis
- `api/fb_graph.py` — інтеграція з Graph API
- `tests/playwright/admin-api.spec.ts` — staging smoke tests

## 13. Моя коротка оцінка стану

Проєкт уже не схожий на прототип “з нуля”: у ньому є кілька реальних робочих флоу, інфраструктурна логіка, staging tests і production-like session handling.

Але він ще не “відполірований”:
- документація слабка;
- структура частково роз’їхалась;
- є техборг у файлах і конфігах;
- потрібна чистка перед передачею команді або масштабуванням.

Тобто це `працюючий прикладний інструмент з реальним функціоналом`, але не до кінця приведений до чистого продуктового стану.
