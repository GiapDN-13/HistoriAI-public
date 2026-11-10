"""Đo hiệu năng backend HistoriAI: smoke latency + load test + /chat riêng.

Chạy:  (server uvicorn phải đang chạy ở :8000)
  python perf_test.py
"""
import asyncio
import statistics
import time

import httpx

BASE = "http://127.0.0.1:8000/api/v1"
ROOT = "http://127.0.0.1:8000"


def pct(values, p):
    if not values:
        return 0.0
    k = sorted(values)
    idx = min(len(k) - 1, int(round(p / 100 * (len(k) - 1))))
    return k[idx]


async def timed(client, method, url, **kw):
    t0 = time.perf_counter()
    try:
        r = await client.request(method, url, **kw)
        ms = (time.perf_counter() - t0) * 1000
        return ms, r.status_code
    except Exception as e:
        return (time.perf_counter() - t0) * 1000, f"ERR:{type(e).__name__}"


async def get_token(client):
    await client.post(f"{BASE}/auth/register",
                      json={"email": "perf@test.com", "full_name": "Perf", "password": "12345678"})
    r = await client.post(f"{BASE}/auth/login",
                          data={"username": "perf@test.com", "password": "12345678"})
    return r.json().get("access_token", "")


async def smoke(client, token):
    """1 request mỗi endpoint, đo latency cơ bản."""
    auth = {"Authorization": f"Bearer {token}"}
    cases = [
        ("GET", f"{ROOT}/health", {}),
        ("GET", f"{BASE}/events", {}),
        ("GET", f"{BASE}/events/bach-dang-1288", {}),
        ("GET", f"{BASE}/figures", {}),
        ("GET", f"{BASE}/artifacts", {}),
        ("GET", f"{BASE}/quiz/lam-son-1428", {"headers": auth}),
        ("GET", f"{BASE}/auth/me", {"headers": auth}),
        ("GET", f"{BASE}/leaderboard?limit=10", {}),
    ]
    print("\n=== SMOKE (1 request / endpoint) ===")
    print(f"{'endpoint':<42}{'ms':>8}  status")
    for m, url, kw in cases:
        ms, st = await timed(client, m, url, **kw)
        name = url.replace(ROOT, "")
        print(f"{m+' '+name:<42}{ms:>8.1f}  {st}")


async def load_test(client, token, url, n=200, concurrency=20, **kw):
    """Bắn n request với giới hạn đồng thời."""
    sem = asyncio.Semaphore(concurrency)
    lat, codes = [], []

    async def one():
        async with sem:
            ms, st = await timed(client, "GET", url, **kw)
            lat.append(ms)
            codes.append(st)

    t0 = time.perf_counter()
    await asyncio.gather(*[one() for _ in range(n)])
    total_s = time.perf_counter() - t0
    ok = sum(1 for c in codes if c == 200)
    print(f"\n=== LOAD: {url.replace(ROOT,'')} | n={n} conc={concurrency} ===")
    print(f"  success : {ok}/{n}")
    print(f"  throughput : {n/total_s:.1f} req/s   (total {total_s:.2f}s)")
    print(f"  latency ms : avg={statistics.mean(lat):.1f}  "
          f"p50={pct(lat,50):.1f}  p95={pct(lat,95):.1f}  p99={pct(lat,99):.1f}  max={max(lat):.1f}")


async def chat_latency(client, n=3):
    """Đo latency /chat (gọi LLM thật) — chạy tuần tự, ít request."""
    print(f"\n=== /chat LLM latency ({n} sequential requests) ===")
    for i in range(n):
        ms, st = await timed(client, "POST", f"{BASE}/chat",
                             json={"figure_slug": "tran-hung-dao",
                                   "message": f"Test question {i+1}: tell about Bach Dang battle"},
                             timeout=120)
        print(f"  req {i+1}: {ms:>8.1f} ms  status={st}")


async def main():
    async with httpx.AsyncClient(timeout=30) as client:
        token = await get_token(client)
        await smoke(client, token)
        auth = {"Authorization": f"Bearer {token}"}
        # Load test các endpoint DB
        await load_test(client, token, f"{ROOT}/health", n=300, concurrency=30)
        await load_test(client, token, f"{BASE}/events", n=300, concurrency=30)
        await load_test(client, token, f"{BASE}/quiz/lam-son-1428", n=200, concurrency=20, headers=auth)
        await load_test(client, token, f"{BASE}/leaderboard?limit=10", n=200, concurrency=20)
        # /chat đo riêng
        await chat_latency(client, n=3)


if __name__ == "__main__":
    asyncio.run(main())
