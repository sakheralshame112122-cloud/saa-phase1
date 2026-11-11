"""PHASE 1 placeholder scheduler.

No jobs are registered yet (PHASE 2 owns the queue table in D7a §4). This only keeps the
container alive, heartbeats, and proves DB/Redis reachability.
"""

from __future__ import annotations

import os
import signal
import sys
import time
from pathlib import Path

from app import __version__
from app.db import ping as db_ping

INTERVAL = int(os.getenv("BEAT_TICK_SECONDS", "60"))
HEARTBEAT = Path(os.getenv("BEAT_HEARTBEAT", "/tmp/beat.heartbeat"))

_running = True


def _stop(signum, frame):
    global _running
    _running = False


def main() -> int:
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    print(f"[beat] started v{__version__} tick={INTERVAL}s", flush=True)
    while _running:
        db_ok, db_detail = db_ping()
        HEARTBEAT.parent.mkdir(parents=True, exist_ok=True)
        HEARTBEAT.write_text(f"{time.time()}\n", encoding="utf-8")
        print(f"[beat] tick db={db_detail} next_in={INTERVAL}s", flush=True)
        for _ in range(INTERVAL):
            if not _running:
                break
            time.sleep(1)
    print("[beat] stopped", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
