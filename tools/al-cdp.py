import json, subprocess, time, urllib.request, sys, os
import websocket

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
PORT = 9232
PROFILE = os.path.join(os.environ["TEMP"], "edgeal-cdp")
URL = "https://anilibria.fun/anime/gensou-suikoden?ep=1"

proc = subprocess.Popen([
    EDGE, "--headless=new", "--disable-gpu", "--no-first-run",
    "--no-default-browser-check", f"--remote-debugging-port={PORT}",
    "--remote-allow-origins=*",
    f"--user-data-dir={PROFILE}", URL,
])

targets = None
for _ in range(60):
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json", timeout=1) as r:
            targets = json.load(r)
        if any(t.get("type") == "page" and "anilibria" in t.get("url", "") for t in targets):
            break
    except Exception:
        pass
    time.sleep(0.5)

if not targets:
    print("no targets")
    sys.exit(1)

page = next(t for t in targets if t.get("type") == "page")
ws = websocket.create_connection(page["webSocketDebuggerUrl"], timeout=30)
mid = 0

def call(method, params=None):
    global mid
    mid += 1
    ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
    while True:
        msg = json.loads(ws.recv())
        if msg.get("id") == mid:
            return msg

call("Runtime.enable")
time.sleep(8)

expr = r"""
(async () => {
  try {
    const r = await fetch('/api/sources?shikimoriId=10335', {cache:'no-store'}).then(x=>x.json());
    const ep = r.episodes[0];
    const body = {url: ep.sources[0].iframeUrl, episode: ep.number, shikimoriId: 10335, translation: ep.sources[0].dubbing};
    const resp = await fetch('/api/aniliberty/resolve', {method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body)});
    const text = await resp.text();
    return JSON.stringify({body, status: resp.status, text});
  } catch (e) { return 'ERR ' + e; }
})()
"""
res = call("Runtime.evaluate", {"expression": expr, "awaitPromise": True, "returnByValue": True})
value = res.get("result", {}).get("result", {}).get("value")
if value is None:
    print(json.dumps(res, ensure_ascii=False)[:2000])
else:
    print(value)

ws.close()
try:
    proc.terminate()
except Exception:
    pass
