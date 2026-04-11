import { expect, test } from "@playwright/test";

const sessionCookie = process.env.PLAYWRIGHT_SESSION_COOKIE;
const testPostUrl =
  process.env.PLAYWRIGHT_TEST_POST_URL ??
  "https://www.instagram.com/p/C4k_m8HNr7v/";
const hasRealSessionCookie =
  !!sessionCookie &&
  sessionCookie.trim().length > 0 &&
  !sessionCookie.includes("<") &&
  !sessionCookie.includes(">");

function makeAccountId(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
}

async function createAdminAccount(
  request: any,
  accountId: string,
  overrides: Record<string, unknown> = {},
) {
  const response = await request.post("/api/admin/accounts", {
    data: {
      account_id: accountId,
      instagram_username: "smoke_account",
      session_settings: {
        user_agent: "Instagram 269.0.0.18.75 Android",
        device_settings: {
          model: "Pixel 7",
          manufacturer: "Google",
        },
        cookies: {},
      },
      device_profile: {
        device_agent: "Instagram 269.0.0.18.75 Android",
        region: "UA",
      },
      ...overrides,
    },
  });

  expect(response.ok()).toBeTruthy();
  return response;
}

async function waitForJobToFinish(request: any, jobId: string) {
  const deadline = Date.now() + 45_000;

  while (Date.now() < deadline) {
    const statusResponse = await request.get(`/api/job_status/${jobId}`);
    expect(statusResponse.ok()).toBeTruthy();

    const statusJson = await statusResponse.json();
    const status = statusJson.status as string;

    if (status === "finished" || status === "failed") {
      return status;
    }

    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  throw new Error(`Timed out waiting for job ${jobId} to finish`);
}

test.describe("staging admin api smoke", () => {
  test("runtime_info returns expected shape", async ({ request }) => {
    const response = await request.get("/api/runtime_info");
    expect(response.ok()).toBeTruthy();

    const json = await response.json();
    expect(json).toMatchObject({
      cwd: "/app",
      module_file: "/app/main.py",
      device_pipeline_version: expect.any(String),
      proxy_count: expect.any(Number),
      use_proxy: expect.any(Boolean),
    });
  });

  test("admin account and proxy lists return collections", async ({ request }) => {
    const [accountsResponse, proxiesResponse] = await Promise.all([
      request.get("/api/admin/accounts"),
      request.get("/api/admin/proxies"),
    ]);

    expect(accountsResponse.ok()).toBeTruthy();
    expect(proxiesResponse.ok()).toBeTruthy();

    const accounts = await accountsResponse.json();
    const proxies = await proxiesResponse.json();

    expect(accounts).toMatchObject({
      count: expect.any(Number),
      items: expect.any(Array),
    });
    expect(proxies).toMatchObject({
      count: expect.any(Number),
      items: expect.any(Array),
    });
  });

  test("admin endpoints validate required fields", async ({ request }) => {
    const proxyResponse = await request.post("/api/admin/proxies", {
      data: {},
    });
    expect(proxyResponse.status()).toBe(400);
    expect(await proxyResponse.json()).toMatchObject({
      error: "validation_error",
      detail: "proxy_url required",
    });

    const accountResponse = await request.post("/api/admin/accounts", {
      data: {
        instagram_username: "smoke_validation",
      },
    });
    expect(accountResponse.status()).toBe(400);
    expect(await accountResponse.json()).toMatchObject({
      error: "validation_error",
      detail: "session_settings or active session required",
    });

    const currentSessionResponse = await request.post(
      "/api/admin/accounts/from_current_session",
      {
        data: {
          instagram_username: "smoke_validation",
        },
      },
    );
    expect(currentSessionResponse.status()).toBe(400);
    expect(await currentSessionResponse.json()).toMatchObject({
      error: "validation_error",
      detail: "active ig session required",
    });
  });

  test("account-scoped fetch returns not_found for unknown account", async ({
    request,
  }) => {
    const response = await request.post(
      `/api/admin/accounts/${makeAccountId("missing")}/fetch_participants_async`,
      {
        data: {
          post_url: testPostUrl,
        },
      },
    );

    expect(response.status()).toBe(404);
    expect(await response.json()).toMatchObject({
      error: "not_found",
      detail: "account not found",
    });
  });

  test("account-scoped fetch validates invalid post_url before enqueue", async ({
    request,
  }) => {
    const accountId = makeAccountId("acc-invalid-url");
    await createAdminAccount(request, accountId);

    const response = await request.post(
      `/api/admin/accounts/${accountId}/fetch_participants_async`,
      {
        data: {
          post_url: "https://example.com/not-instagram",
        },
      },
    );

    expect(response.status()).toBe(400);
    expect(await response.json()).toMatchObject({
      error: "invalid_post_url",
    });
  });

  test("account-scoped fetch blocks challenge-state accounts before enqueue", async ({
    request,
  }) => {
    const accountId = makeAccountId("acc-challenge");
    await createAdminAccount(request, accountId, {
      status: "challenge",
      challenge_reason: "worker_media_fetch_challenge",
    });

    const response = await request.post(
      `/api/admin/accounts/${accountId}/fetch_participants_async`,
      {
        data: {
          post_url: testPostUrl,
        },
      },
    );

    expect(response.status()).toBe(412);
    expect(await response.json()).toMatchObject({
      error: "instagram_challenge",
      account_id: accountId,
      account_status: "challenge",
      challenge_reason: "worker_media_fetch_challenge",
    });
  });

  test("can create proxy, account, bind them, and enqueue account-scoped job", async ({
    request,
  }) => {
    const proxyId = makeAccountId("pxy");
    const accountId = makeAccountId("acc");

    const proxyCreate = await request.post("/api/admin/proxies", {
      data: {
        proxy_id: proxyId,
        proxy_url: "http://127.0.0.1:18080",
        region: "UA",
        proxy_type: "test",
        status: "active",
      },
    });
    expect(proxyCreate.ok()).toBeTruthy();
    expect(await proxyCreate.json()).toMatchObject({
      proxy: {
        proxy_id: proxyId,
        proxy_url: "http://127.0.0.1:18080",
        region: "UA",
        proxy_type: "test",
        status: "active",
      },
    });

    const accountCreate = await createAdminAccount(request, accountId);
    expect(await accountCreate.json()).toMatchObject({
      account: {
        account_id: accountId,
        instagram_username: "smoke_account",
        status: "active",
      },
      proxy: null,
    });

    const bindProxy = await request.post(`/api/admin/accounts/${accountId}/bind_proxy`, {
      data: {
        proxy_id: proxyId,
      },
    });
    expect(bindProxy.ok()).toBeTruthy();
    expect(await bindProxy.json()).toMatchObject({
      account: {
        account_id: accountId,
        proxy_id: proxyId,
      },
      proxy: {
        proxy_id: proxyId,
        assigned_account_id: accountId,
      },
    });

    const accountView = await request.get(`/api/admin/accounts/${accountId}`);
    expect(accountView.ok()).toBeTruthy();
    expect(await accountView.json()).toMatchObject({
      account: {
        account_id: accountId,
        proxy_id: proxyId,
      },
      proxy: {
        proxy_id: proxyId,
      },
    });

    const enqueue = await request.post(
      `/api/admin/accounts/${accountId}/fetch_participants_async`,
      {
        data: {
          post_url: testPostUrl,
        },
      },
    );
    expect(enqueue.status()).toBe(202);
    expect(await enqueue.json()).toMatchObject({
      account_id: accountId,
      job_id: expect.any(String),
    });
  });

  test("account-scoped async job reaches a terminal result endpoint", async ({ request }) => {
    const accountId = makeAccountId("acc-job");

    const accountCreate = await createAdminAccount(request, accountId);
    expect(accountCreate.ok()).toBeTruthy();

    const enqueue = await request.post(
      `/api/admin/accounts/${accountId}/fetch_participants_async`,
      {
        data: {
          post_url: testPostUrl,
        },
      },
    );
    expect(enqueue.status()).toBe(202);

    const enqueueJson = await enqueue.json();
    expect(enqueueJson).toMatchObject({
      account_id: accountId,
      job_id: expect.any(String),
    });

    const terminalStatus = await waitForJobToFinish(request, enqueueJson.job_id);
    expect(["finished", "failed"]).toContain(terminalStatus);

    const resultResponse = await request.get(`/api/job_result/${enqueueJson.job_id}`);
    expect([200, 400, 401, 412, 500]).toContain(resultResponse.status());

    const resultJson = await resultResponse.json();
    if (resultResponse.status() === 200) {
      expect(resultJson).toMatchObject({
        status: "finished",
        participants: expect.any(Array),
      });
    } else if (resultResponse.status() === 400) {
      expect(resultJson).toMatchObject({
        error: expect.any(String),
      });
    } else if (resultResponse.status() === 401) {
      expect(resultJson).toMatchObject({
        error: "login_required",
      });
    } else if (resultResponse.status() === 412) {
      expect(resultJson).toMatchObject({
        error: "instagram_challenge",
      });
    } else {
      expect(resultJson).toMatchObject({
        error: "internal_error",
      });
    }
  });

  test.describe("from_current_session success path", () => {
    test.skip(
      !hasRealSessionCookie,
      "PLAYWRIGHT_SESSION_COOKIE is missing or still uses the placeholder value",
    );

    test("can create account from active flask session", async ({ playwright, baseURL }) => {
      const context = await playwright.request.newContext({
        baseURL: baseURL!,
        extraHTTPHeaders: {
          Accept: "application/json",
          Cookie: `session=${sessionCookie!}`,
        },
      });

      const accountId = makeAccountId("session");
      const response = await context.post("/api/admin/accounts/from_current_session", {
        data: {
          account_id: accountId,
          instagram_username: "session_bound_account",
        },
      });

      expect(response.ok()).toBeTruthy();
      expect(await response.json()).toMatchObject({
        source: "current_session",
        account: {
          account_id: accountId,
          instagram_username: "session_bound_account",
        },
      });

      await context.dispose();
    });
  });
});
