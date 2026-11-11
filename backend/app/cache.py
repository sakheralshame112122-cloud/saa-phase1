"""Redis connectivity — real PING, never an env-var guess."""

from __future__ import annotations

import redis

from app.config import SETTINGS


def ping() -> tuple[bool, str]:
    client = None
    try:
        client = redis.Redis.from_url(SETTINGS.redis_url, socket_connect_timeout=2, socket_timeout=2)
        pong = client.ping()
        return (bool(pong), "ok" if pong else "no-pong")
    except Exception as exc:
        return (False, f"{type(exc).__name__}")
    finally:
        if client is not None:
            try:
                client.close()
            except Exception:
                pass
