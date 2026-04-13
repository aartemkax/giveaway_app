# Account Recovery Runbook

## Purpose

This runbook describes the shortest reliable way to diagnose the account-based Instagram flow in staging after `sessionid` onboarding.

Use it when the app reaches the participants screen but the active account is blocked, unverified, in cooldown, or challenged.

## Canonical Runtime Path

The primary supported path is:

1. direct login may fail with `401 invalid_credentials`
2. user falls back to `sessionid` login in the Instagram WebView
3. app calls `POST /api/admin/accounts/from_sessionid`
4. app immediately calls `POST /api/admin/accounts/<account_id>/verify`
5. participants screen shows the resulting account state

This means the key diagnostic boundary is no longer "did sessionid save?" but "what state did `/verify` set?"

## What To Check First

### 1. App state on emulator

Look for one of these screens:

- `Вхід в Instagram`
- `Instagram Login`
- `Учасники Giveaway`

If the app is already on `Учасники Giveaway`, check whether the banner shows:

- challenge
- cooldown
- unverified

### 2. Active account record

Check the latest account state:

```powershell
$base = "https://stage-exemplary-appreciation-staging.up.railway.app"
Invoke-RestMethod -Uri "$base/api/admin/accounts" -Method Get
```

For a single account:

```powershell
Invoke-RestMethod -Uri "$base/api/admin/accounts/<account_id>" -Method Get
```

Important fields:

- `status`
- `challenge_reason`
- `cooldown_until`
- `instagram_username`

## Expected Status Meanings

### `active`

- account is currently usable
- fetch may proceed

### `unverified`

- stored account exists, but current session is not trusted
- expected recovery path:
  - go back to login
  - repeat `sessionid` onboarding

### `challenge`

- Instagram accepted enough of the flow to identify the account, but blocked server-side verification or fetch
- expected recovery path:
  - re-login
  - complete any challenge/checkpoint in Instagram
  - try verification again

### `cooldown`

- the backend should not keep retrying immediately
- wait until `cooldown_until`, then refresh the status

## Key API Calls To Watch

### Session onboarding

```text
POST /api/admin/accounts/from_sessionid
```

Expected:

- `200`
- response contains `account.account_id`

### Verification

```text
POST /api/admin/accounts/<account_id>/verify
```

Expected terminal results:

- `200` -> account usable
- `401 login_required` -> session invalid or expired
- `412 instagram_challenge` -> challenge/checkpoint style block
- `429 rate_limited` -> cooldown state

### Fetch participants

```text
POST /api/admin/accounts/<account_id>/fetch_participants_async
```

Expected:

- `202` only if the account is allowed to proceed
- blocked accounts should fail earlier and more honestly

## Log Signatures

### Direct login failed

```text
POST /api/login
401 invalid_credentials
```

### Session onboarding succeeded

```text
POST /api/admin/accounts/from_sessionid
200 OK
```

### Verification challenge

```text
POST /api/admin/accounts/<account_id>/verify
412 instagram_challenge
challenge_reason = verify_session_challenge
```

### Worker-side media fetch challenge

```text
job_result -> 412 instagram_challenge
challenge_reason = worker_media_fetch_challenge
```

### Session no longer usable

```text
401 login_required
challenge_reason = verify_session_invalid
```

## Railway Checks

When debugging staging, check both services:

- API service logs
- worker service logs

Important rule:

- if job signatures or queue behavior changed, redeploy API and worker together

## Practical Recovery Order

1. confirm the app is on staging
2. inspect the active account state
3. if blocked, use the participants-screen banner action:
   - `Перейти до входу`
   - or `Перевірити ще раз`
4. if verification still returns `verify_session_challenge`, stop blind retries
5. only then decide whether to:
   - re-login the same account
   - try another account
   - wait out cooldown

## Escalation Rule

If the same account repeatedly lands in:

- `verify_session_challenge`
- or `worker_media_fetch_challenge`

do not treat it as a generic app bug.

At that point the likely blocker is Instagram trust/network context, not the UI flow.
