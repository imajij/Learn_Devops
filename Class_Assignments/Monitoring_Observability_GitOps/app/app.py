"""shop-app: a tiny instrumented web service (Python standard library only).

One image, two roles (set with the ROLE env var):
  ROLE=shop      -> public front end, GET /order calls the payments service
  ROLE=payments  -> internal service, GET /pay

Observability built in:
  * Metrics : Prometheus text format on GET /metrics
  * Logs    : one JSON object per line on stdout, each with trace_id/span_id
  * Traces  : spans sent to Jaeger as OTLP/HTTP JSON (OTLP_TRACES_URL); the trace
              context is passed from shop to payments in B3 headers (X-B3-TraceId/SpanId)
  * Health  : GET /healthz (liveness) and GET /readyz (readiness)

Fault injection for the monitoring demo:
  GET /admin/errors?pct=60    -> make 60 % of /order (or /pay) requests fail with HTTP 500
  GET /admin/burn?seconds=120 -> burn one CPU core for N seconds
"""
import json
import os
import random
import secrets
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ROLE = os.getenv("ROLE", "shop")
VERSION = os.getenv("APP_VERSION", "1.0.0")
PORT = int(os.getenv("PORT", "8080"))
PAYMENTS_URL = os.getenv("PAYMENTS_URL", "http://payments:8080/pay")
OTLP_URL = os.getenv("OTLP_TRACES_URL", "")  # e.g. http://jaeger:4318/v1/traces

BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5]
lock = threading.Lock()
requests_total = {}      # (path, code) -> count
duration_buckets = {}    # path -> [count per bucket]
duration_sum = {}
duration_count = {}
state = {"error_pct": 0, "burn_until": 0.0}
START = time.time()


def log(level, msg, **fields):
    rec = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime()) + "Z",
           "level": level, "service": ROLE, "version": VERSION, "msg": msg}
    rec.update(fields)
    print(json.dumps(rec), flush=True)


def observe(path, code, seconds):
    with lock:
        requests_total[(path, code)] = requests_total.get((path, code), 0) + 1
        b = duration_buckets.setdefault(path, [0] * len(BUCKETS))
        for i, le in enumerate(BUCKETS):
            if seconds <= le:
                b[i] += 1
        duration_sum[path] = duration_sum.get(path, 0.0) + seconds
        duration_count[path] = duration_count.get(path, 0) + 1


def render_metrics():
    out = ["# HELP app_info Static information about the running app.",
           "# TYPE app_info gauge",
           f'app_info{{service="{ROLE}",version="{VERSION}"}} 1',
           "# HELP app_uptime_seconds Seconds since the process started.",
           "# TYPE app_uptime_seconds gauge",
           f"app_uptime_seconds {time.time() - START:.1f}",
           "# HELP app_error_injection_percent Current injected error rate (demo knob).",
           "# TYPE app_error_injection_percent gauge",
           f"app_error_injection_percent {state['error_pct']}",
           "# HELP http_requests_total Total HTTP requests by path and status code.",
           "# TYPE http_requests_total counter"]
    with lock:
        for (path, code), v in sorted(requests_total.items()):
            out.append(f'http_requests_total{{path="{path}",code="{code}"}} {v}')
        out += ["# HELP http_request_duration_seconds Request latency.",
                "# TYPE http_request_duration_seconds histogram"]
        for path, b in sorted(duration_buckets.items()):
            for le, v in zip(BUCKETS, b):
                out.append(f'http_request_duration_seconds_bucket{{path="{path}",le="{le}"}} {v}')
            out.append(f'http_request_duration_seconds_bucket{{path="{path}",le="+Inf"}} {duration_count[path]}')
            out.append(f'http_request_duration_seconds_sum{{path="{path}"}} {duration_sum[path]:.6f}')
            out.append(f'http_request_duration_seconds_count{{path="{path}"}} {duration_count[path]}')
    return "\n".join(out) + "\n"


def send_span(trace_id, span_id, parent_id, name, start, end, kind, tags, failed=False):
    """Report one span to Jaeger as OTLP/HTTP JSON (the OpenTelemetry wire format), fire and forget."""
    if not OTLP_URL:
        return
    attrs = [{"key": k, "value": {"stringValue": str(v)}} for k, v in tags.items()]
    span = {"traceId": trace_id, "spanId": span_id, "name": name,
            "kind": {"SERVER": 2, "CLIENT": 3}[kind],
            "startTimeUnixNano": str(int(start * 1e9)), "endTimeUnixNano": str(int(end * 1e9)),
            "attributes": attrs,
            "status": {"code": 2 if failed else 1}}  # OTLP status: 1 = OK, 2 = ERROR
    if parent_id:
        span["parentSpanId"] = parent_id
    payload = {"resourceSpans": [{
        "resource": {"attributes": [
            {"key": "service.name", "value": {"stringValue": ROLE}},
            {"key": "service.version", "value": {"stringValue": VERSION}},
            {"key": "k8s.pod.name", "value": {"stringValue": os.getenv("HOSTNAME", "")}}]},
        "scopeSpans": [{"scope": {"name": "shop-app-manual"}, "spans": [span]}]}]}

    def _post():
        try:
            req = urllib.request.Request(OTLP_URL, data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json"})
            urllib.request.urlopen(req, timeout=2).read()
        except Exception as e:  # tracing must never break the app
            log("warn", "span export failed", error=str(e))
    threading.Thread(target=_post, daemon=True).start()


def burn():
    while True:
        if time.time() < state["burn_until"]:
            x = 0
            for i in range(200000):
                x += i * i
        else:
            time.sleep(0.2)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):  # silence default access log, we log JSON ourselves
        pass

    def reply(self, code, body, ctype="application/json"):
        data = body.encode() if isinstance(body, str) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        if u.path == "/metrics":
            return self.reply(200, render_metrics(), "text/plain; version=0.0.4")
        if u.path in ("/healthz", "/readyz"):
            return self.reply(200, {"status": "ok"})
        if u.path == "/admin/errors":
            state["error_pct"] = int(q.get("pct", ["0"])[0])
            log("warn", "error injection changed", error_pct=state["error_pct"])
            return self.reply(200, {"error_pct": state["error_pct"]})
        if u.path == "/admin/burn":
            secs = int(q.get("seconds", ["60"])[0])
            state["burn_until"] = time.time() + secs
            log("warn", "cpu burn started", seconds=secs)
            return self.reply(200, {"burning_for": secs})

        route = {"shop": {"/", "/order"}, "payments": {"/pay"}}[ROLE]
        if u.path not in route:
            return self.reply(404, {"error": "not found"})

        # --- trace context: continue the caller's trace (B3 headers) or start a new one
        trace_id = self.headers.get("X-B3-TraceId") or secrets.token_hex(16)
        parent_id = self.headers.get("X-B3-SpanId")
        span_id = secrets.token_hex(8)
        t0 = time.time()
        code, body = 200, {}
        try:
            if u.path == "/":
                body = {"service": ROLE, "version": VERSION, "hint": "try /order"}
            elif u.path == "/order":
                order_id = random.randint(1000, 9999)
                # child span 1: pretend DB lookup
                db_id, d0 = secrets.token_hex(8), time.time()
                time.sleep(random.uniform(0.005, 0.03))
                send_span(trace_id, db_id, span_id, "db SELECT inventory", d0, time.time(),
                          "CLIENT", {"db.system": "sqlite", "order.id": order_id})
                # child span 2: HTTP call to payments, propagating the trace
                pay_id, p0 = secrets.token_hex(8), time.time()
                req = urllib.request.Request(PAYMENTS_URL, headers={
                    "X-B3-TraceId": trace_id, "X-B3-SpanId": pay_id, "X-B3-Sampled": "1"})
                try:
                    with urllib.request.urlopen(req, timeout=3) as r:
                        pay = json.loads(r.read())
                    pay_status = 200
                except urllib.error.HTTPError as e:
                    pay, pay_status = {"error": "payment failed"}, e.code
                send_span(trace_id, pay_id, span_id, "GET /pay", p0, time.time(), "CLIENT",
                          {"http.status_code": pay_status, "peer.service": "payments"},
                          failed=pay_status != 200)
                if pay_status != 200:
                    code, body = 502, {"order": order_id, "error": "payment failed"}
                elif random.randint(1, 100) <= state["error_pct"]:
                    code, body = 500, {"order": order_id, "error": "injected failure"}
                else:
                    body = {"order": order_id, "payment": pay, "status": "confirmed"}
            elif u.path == "/pay":
                time.sleep(random.uniform(0.01, 0.06))
                if random.randint(1, 100) <= state["error_pct"]:
                    code, body = 500, {"error": "card declined (injected)"}
                else:
                    body = {"paid": True, "txn": secrets.token_hex(4)}
        except Exception as e:
            code, body = 500, {"error": str(e)}
        t1 = time.time()
        observe(u.path, str(code), t1 - t0)
        send_span(trace_id, span_id, parent_id, f"GET {u.path}", t0, t1, "SERVER",
                  {"http.method": "GET", "http.route": u.path, "http.status_code": code},
                  failed=code >= 500)
        log("error" if code >= 500 else "info", "request handled", method="GET", path=u.path,
            status=code, duration_ms=round((t1 - t0) * 1000, 1), trace_id=trace_id, span_id=span_id)
        body["trace_id"] = trace_id
        self.reply(code, body)


if __name__ == "__main__":
    threading.Thread(target=burn, daemon=True).start()
    log("info", "starting", port=PORT, payments_url=PAYMENTS_URL if ROLE == "shop" else None,
        tracing=bool(OTLP_URL))
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
