import json, subprocess, time, urllib.request, sys, os, tempfile
import websocket

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"


def main():
    if len(sys.argv) < 3:
        print("usage: cdp.py <url> <js-file> [wait-seconds]")
        return 1
    url = sys.argv[1]
    js_file = sys.argv[2]
    wait = float(sys.argv[3]) if len(sys.argv) > 3 else 8.0
    port = 9240 + (os.getpid() % 50)
    profile = os.path.join(tempfile.gettempdir(), "edgecdp-%d" % port)
    expr = open(js_file, encoding="utf-8").read()

    proc = subprocess.Popen([
        EDGE, "--headless=new", "--disable-gpu", "--no-first-run",
        "--no-default-browser-check", f"--remote-debugging-port={port}",
        "--remote-allow-origins=*", f"--user-data-dir={profile}", url,
    ])

    targets = None
    for _ in range(120):
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/json", timeout=1) as r:
                targets = json.load(r)
            if any(t.get("type") == "page" and t.get("url") for t in targets):
                break
        except Exception:
            pass
        time.sleep(0.5)
    if not targets:
        print("no targets")
        proc.terminate()
        return 1

    page = next(t for t in targets if t.get("type") == "page" and "devtools" not in t.get("url", ""))
    ws = websocket.create_connection(page["webSocketDebuggerUrl"], timeout=60)
    mid = 0

    def call(method, params=None):
        nonlocal mid
        mid += 1
        ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
        while True:
            msg = json.loads(ws.recv())
            if msg.get("id") == mid:
                return msg

    call("Runtime.enable")
    time.sleep(wait)
    res = call("Runtime.evaluate", {"expression": expr, "awaitPromise": True, "returnByValue": True})
    value = res.get("result", {}).get("result", {}).get("value")
    if value is None:
        print(json.dumps(res, ensure_ascii=False)[:4000])
    else:
        print(value)
    ws.close()
    proc.terminate()
    return 0


if __name__ == "__main__":
    sys.exit(main())
