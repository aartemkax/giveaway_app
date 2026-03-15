from __future__ import annotations

import json
import secrets
import time
from dataclasses import asdict, dataclass, field
from typing import Any


def _now_ts() -> int:
    return int(time.time())


@dataclass
class AccountRecord:
    account_id: str
    instagram_username: str = ""
    status: str = "active"
    proxy_id: str | None = None
    session_settings: dict[str, Any] = field(default_factory=dict)
    device_profile: dict[str, Any] = field(default_factory=dict)
    last_login_at: int | None = None
    last_success_at: int | None = None
    cooldown_until: int | None = None
    challenge_reason: str | None = None
    notes: str | None = None
    updated_at: int = field(default_factory=_now_ts)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "AccountRecord":
        payload = dict(data or {})
        payload.setdefault("account_id", secrets.token_hex(8))
        payload.setdefault("instagram_username", "")
        payload.setdefault("status", "active")
        payload.setdefault("session_settings", {})
        payload.setdefault("device_profile", {})
        payload.setdefault("updated_at", _now_ts())
        return cls(**payload)


@dataclass
class ProxyRecord:
    proxy_id: str
    proxy_url: str
    region: str = ""
    proxy_type: str = "residential"
    status: str = "active"
    assigned_account_id: str | None = None
    last_ok_at: int | None = None
    last_fail_at: int | None = None
    fail_count: int = 0
    updated_at: int = field(default_factory=_now_ts)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "ProxyRecord":
        payload = dict(data or {})
        payload.setdefault("proxy_id", secrets.token_hex(8))
        payload.setdefault("region", "")
        payload.setdefault("proxy_type", "residential")
        payload.setdefault("status", "active")
        payload.setdefault("fail_count", 0)
        payload.setdefault("updated_at", _now_ts())
        return cls(**payload)


class AccountAffinityStore:
    def __init__(self, redis_client, prefix: str = "ig") -> None:
        self.redis = redis_client
        self.prefix = prefix

    def _account_key(self, account_id: str) -> str:
        return f"{self.prefix}:account:{account_id}"

    def _proxy_key(self, proxy_id: str) -> str:
        return f"{self.prefix}:proxy:{proxy_id}"

    def _account_ids_key(self) -> str:
        return f"{self.prefix}:accounts"

    def _proxy_ids_key(self) -> str:
        return f"{self.prefix}:proxies"

    def _lock_key(self, account_id: str) -> str:
        return f"{self.prefix}:account-lock:{account_id}"

    def list_accounts(self) -> list[AccountRecord]:
        ids = sorted(
            item.decode() if isinstance(item, bytes) else str(item)
            for item in self.redis.smembers(self._account_ids_key())
        )
        result: list[AccountRecord] = []
        for account_id in ids:
            record = self.get_account(account_id)
            if record:
                result.append(record)
        return result

    def get_account(self, account_id: str) -> AccountRecord | None:
        raw = self.redis.get(self._account_key(account_id))
        if not raw:
            return None
        if isinstance(raw, bytes):
            raw = raw.decode()
        return AccountRecord.from_dict(json.loads(raw))

    def put_account(self, record: AccountRecord) -> AccountRecord:
        record.updated_at = _now_ts()
        self.redis.set(self._account_key(record.account_id), json.dumps(record.to_dict()))
        self.redis.sadd(self._account_ids_key(), record.account_id)
        return record

    def sync_account_session(
        self,
        account_id: str,
        instagram_username: str | None,
        session_settings: dict[str, Any],
        device_profile: dict[str, Any],
    ) -> AccountRecord:
        record = self.get_account(account_id) or AccountRecord(account_id=account_id)
        if instagram_username is not None:
            record.instagram_username = instagram_username
        record.session_settings = dict(session_settings or {})
        record.device_profile = dict(device_profile or {})
        record.last_login_at = _now_ts()
        record.status = "active"
        return self.put_account(record)

    def mark_account_result(
        self,
        account_id: str,
        *,
        status: str | None = None,
        challenge_reason: str | None = None,
        cooldown_until: int | None = None,
        last_success: bool = False,
    ) -> AccountRecord | None:
        record = self.get_account(account_id)
        if not record:
            return None
        if status is not None:
            record.status = status
        record.challenge_reason = challenge_reason
        record.cooldown_until = cooldown_until
        if last_success:
            record.last_success_at = _now_ts()
        return self.put_account(record)

    def list_proxies(self) -> list[ProxyRecord]:
        ids = sorted(
            item.decode() if isinstance(item, bytes) else str(item)
            for item in self.redis.smembers(self._proxy_ids_key())
        )
        result: list[ProxyRecord] = []
        for proxy_id in ids:
            record = self.get_proxy(proxy_id)
            if record:
                result.append(record)
        return result

    def get_proxy(self, proxy_id: str) -> ProxyRecord | None:
        raw = self.redis.get(self._proxy_key(proxy_id))
        if not raw:
            return None
        if isinstance(raw, bytes):
            raw = raw.decode()
        return ProxyRecord.from_dict(json.loads(raw))

    def put_proxy(self, record: ProxyRecord) -> ProxyRecord:
        record.updated_at = _now_ts()
        self.redis.set(self._proxy_key(record.proxy_id), json.dumps(record.to_dict()))
        self.redis.sadd(self._proxy_ids_key(), record.proxy_id)
        return record

    def bind_proxy(self, account_id: str, proxy_id: str) -> tuple[AccountRecord, ProxyRecord]:
        account = self.get_account(account_id)
        if not account:
            raise KeyError(f"account {account_id} not found")

        proxy = self.get_proxy(proxy_id)
        if not proxy:
            raise KeyError(f"proxy {proxy_id} not found")

        if account.proxy_id and account.proxy_id != proxy_id:
            previous = self.get_proxy(account.proxy_id)
            if previous:
                previous.assigned_account_id = None
                self.put_proxy(previous)

        account.proxy_id = proxy_id
        proxy.assigned_account_id = account_id

        self.put_account(account)
        self.put_proxy(proxy)
        return account, proxy

    def acquire_account_lock(self, account_id: str, ttl_sec: int = 900) -> bool:
        return bool(self.redis.set(self._lock_key(account_id), "1", nx=True, ex=ttl_sec))

    def release_account_lock(self, account_id: str) -> None:
        self.redis.delete(self._lock_key(account_id))

    def get_account_context(self, account_id: str) -> dict[str, Any] | None:
        account = self.get_account(account_id)
        if not account:
            return None

        proxy = self.get_proxy(account.proxy_id) if account.proxy_id else None
        return {
            "account": account,
            "proxy": proxy,
            "proxy_url": proxy.proxy_url if proxy else None,
            "session_settings": account.session_settings or {},
            "device_profile": account.device_profile or {},
        }
