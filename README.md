# giveaway_app

`giveaway_app` is a Flutter client plus Flask backend for Instagram/Facebook giveaway workflows.

The repository supports two main product flows:

1. `Facebook / Instagram Graph API flow`
   - user signs in with Facebook
   - app loads connected Instagram accounts
   - media and comments are fetched through Graph API
   - winners are selected from the filtered participant pool

2. `Instagram session / account-affinity flow`
   - user signs in through Instagram login/password or WebView session capture
   - backend stores session/device context
   - participant fetch runs asynchronously through Redis/RQ
   - client polls job status and then performs winner selection

## What The Product Does

At a high level the system combines:

- login and session handling
- Instagram account/media/comment access
- participant filtering
- winner selection
- async backend jobs for participant loading
- staging verification through API smoke tests

## Tech Stack

- Flutter / Dart
- Riverpod
- Dio + cookie jar
- Flask
- Redis
- RQ
- `instagrapi`
- Facebook Graph API
- Playwright

## Active Project Shape

Main active entrypoints:

- [`lib/main.dart`](lib/main.dart)
- [`api/main.py`](api/main.py)
- [`api/tasks.py`](api/tasks.py)
- [`api/account_affinity.py`](api/account_affinity.py)
- [`tests/playwright/admin-api.spec.ts`](tests/playwright/admin-api.spec.ts)
- [`PROJECT_SUMMARY_FOR_CHAT.md`](PROJECT_SUMMARY_FOR_CHAT.md)

Important note:

- `docs/` contains both handwritten docs and built Flutter web artifacts
- for repo context, prefer the markdown files explicitly linked below

## Run The Project

### Flutter client

Prerequisites:

- Flutter SDK
- root `.env`

Minimum root `.env`:

```env
API_BASE_URL=http://localhost:8080
```

Install and run:

```bash
flutter pub get
flutter run
```

The app reads `API_BASE_URL` through [`lib/utils/constants.dart`](lib/utils/constants.dart).

### Backend API

Prerequisites:

- Python 3.11
- Redis
- `api/.env`

Setup:

```bash
cd api
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

Run the API:

```bash
cd api
. .venv/bin/activate
python main.py
```

Default local port:

- `8080`

### Background worker

Async participant loading requires the RQ worker:

```bash
cd api
. .venv/bin/activate
python -m rq worker --with-scheduler -u "$REDIS_URL" -P .
```

Expected runtime process shape is documented in [`api/Procfile`](api/Procfile).

## Required Environment Variables

### Root `.env` for Flutter

Required:

- `API_BASE_URL`

Optional:

- `GEO_SERVICE_URL`

Reference:

- [`.env.example`](.env.example)

### `api/.env` for backend

Required for practical local backend use:

- `FLASK_SECRET_KEY`
- `REDIS_URL`
- `SESSION_COOKIE_SECURE`

Required for Graph API flow:

- `FB_APP_ID`
- `FB_APP_SECRET`
- `FB_REDIRECT_URI`

Optional or flow-specific:

- `IG_USERNAME`
- `IG_PASSWORD`
- `SESSION_JSON_B64`
- `USE_PROXY`
- `INSTAGRAM_AUTH_PROXIES`
- `INSTAGRAM_PROXIES`
- `PROXIES`
- `CORS_ORIGIN`
- `PORT`

Reference:

- [`api/.env.example`](api/.env.example)

## Testing

### Flutter

```bash
flutter analyze
flutter test
```

### Playwright API smoke tests

```bash
npm install
npm run test:api
```

Optional smoke-test variables:

- `PLAYWRIGHT_BASE_URL`
- `PLAYWRIGHT_TEST_POST_URL`
- `PLAYWRIGHT_SESSION_COOKIE`

Related files:

- [`package.json`](package.json)
- [`playwright.config.ts`](playwright.config.ts)
- [`tests/playwright/README.md`](tests/playwright/README.md)

## Deployment Notes

Current deploy files:

- [`railway.json`](railway.json)
- [`api/Dockerfile`](api/Dockerfile)
- [`api/Procfile`](api/Procfile)

Current deploy reality:

- Railway builds from `api/Dockerfile`
- Railway service Root Directory should be `api`
- active backend entrypoint is [`api/main.py`](api/main.py)
- web service runs `main:app` inside the container
- worker must be deployed in sync with API when queue/job signatures change

## Current Product Reality

The repository is already beyond a simple prototype, but it is still in a transition phase.

Important current facts:

- Graph API flow exists
- legacy session-based backend flow still exists
- new account-affinity flow exists and is actively being wired in
- staging API and worker are running
- account-affinity jobs execute
- the main remaining blocker is worker-side Instagram challenge behavior during server-side media/comment fetch

## Docs You Should Read First

- [`PROJECT_SUMMARY_FOR_CHAT.md`](PROJECT_SUMMARY_FOR_CHAT.md)
- [`docs/ROADMAP_14_DAYS.md`](docs/ROADMAP_14_DAYS.md)
- [`docs/DEV_SETUP.md`](docs/DEV_SETUP.md)
- [`docs/TESTING.md`](docs/TESTING.md)
- [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md)
- [`docs/DOCS_POLICY.md`](docs/DOCS_POLICY.md)

As more repo structure is documented, also use:

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- [`docs/CODEBASE_NOTES.md`](docs/CODEBASE_NOTES.md)

## Handoff

If you need to transfer context into another chat, start with:

- [`PROJECT_SUMMARY_FOR_CHAT.md`](PROJECT_SUMMARY_FOR_CHAT.md)

That file is the canonical short handoff document for the repo.
