# Playwright API smoke tests

This suite targets the staging admin/account-affinity endpoints over HTTP.

Required for basic smoke run:

```powershell
npm install
npx playwright test
```

Optional environment variables:

```powershell
$env:PLAYWRIGHT_BASE_URL="https://stage-exemplary-appreciation-staging.up.railway.app"
$env:PLAYWRIGHT_TEST_POST_URL="https://www.instagram.com/p/C4k_m8HNr7v/"
$env:PLAYWRIGHT_SESSION_COOKIE="<flask session cookie>"
```

`PLAYWRIGHT_SESSION_COOKIE` is only needed for the `from_current_session` success-path test.
