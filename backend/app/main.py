"""SAA Core API — PHASE 1 foundation.

Scope is intentionally narrow: liveness, readiness, and nothing else.
No auth, no CRUD, no Facebook calls, no AI calls.
"""

from __future__ import annotations

import time

from fastapi import FastAPI
from fastapi.responses import JSONResponse

from app import __version__
from app.cache import ping as redis_ping
from app.config import SETTINGS
from app.db import ping as db_ping

app = FastAPI(title="SAA Core API", version=__version__, docs_url="/docs", redoc_url=None)

_STARTED_AT = time.monotonic()


def uptime_seconds() -> int:
    """Seconds elapsed since this process started, per the HealthResponse contract."""
    return int(time.monotonic() - _STARTED_AT)


@app.get("/health")
def health() -> JSONResponse:
    """Liveness + dependency snapshot. Always 200 so the process is never killed for a dependency."""
    db_ok, db_detail = db_ping()
    redis_ok, redis_detail = redis_ping()
    body = {
        "status": "ok" if (db_ok and redis_ok) else "degraded",
        "version": SETTINGS.version,
        "uptime_seconds": uptime_seconds(),
        "db": db_detail,
        "redis": redis_detail,
    }
    return JSONResponse(status_code=200, content=body)


@app.get("/health/ready")
def ready() -> JSONResponse:
    """200 only when MySQL and Redis answer a real round-trip right now."""
    db_ok, db_detail = db_ping()
    redis_ok, redis_detail = redis_ping()
    is_ready = db_ok and redis_ok
    body = {
        "ready": is_ready,
        "version": SETTINGS.version,
        "db": db_detail,
        "redis": redis_detail,
    }
    return JSONResponse(status_code=200 if is_ready else 503, content=body)
