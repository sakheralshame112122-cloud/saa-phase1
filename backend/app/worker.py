"""PHASE 1 placeholder worker.

PHASE 1 has no queues and no tasks (that is PHASE 2). What this process does is prove the
container stays healthy and can reach MySQL and Redis, and it writes a heartbeat file that the
container healthcheck reads. No Celery, no business logic.
"""

from __future__ import annotations

import os
import signal
import sys
import time
from pathlib import Path

from app import __version__
from app.cache import ping as redis_ping
from app.db import ping as db_ping

ROLE = os.getenv("WORKER_ROLE", "worker")
INTERVAL = int(os.getenv("WORKER_TICK_SECONDS", "15"))
HEARTBEAT = Path(os.getenv("WORKER_HEARTBEAT", "/tmp/worker.heartbeat"))

_running = True


def _stop(signum, frame):
    global _running
    _running = False


def main() -> int:
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    print(f"[{ROLE}] started v{__version__} tick={INTERVAL}s", flush=True)
    while _running:
        db_ok, db_detail = db_ping()
        redis_ok, redis_detail = redis_ping()
        HEARTBEAT.parent.mkdir(parents=True, exist_ok=True)
        HEARTBEAT.write_text(f"{time.time()}\n", encoding="utf-8")
        print(f"[{ROLE}] db={db_detail} redis={redis_detail}", flush=True)
        for _ in range(INTERVAL):
            if not _running:
                break
            time.sleep(1)
    print(f"[{ROLE}] stopped", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
