import io
import json
import os
import re

d = json.load(io.open(os.path.join(os.environ["TEMP"], "yummy-videos.json"), encoding="utf-8"))["response"]
print(type(d), list(d.keys()) if isinstance(d, dict) else len(d))
# print a compact structure sample
text = json.dumps(d, ensure_ascii=False)
print("len", len(text))
print(text[:2000])
print("Flowers occurrences:", text.lower().count("flower"))
for m in re.finditer("Flowers", text, re.I):
    print("...", text[max(0, m.start()-500):m.start()+500], "...")
    break
