import io
import json
import os

d = json.load(io.open(os.path.join(os.environ["TEMP"], "cvh-playlist.json"), encoding="utf-8"))
for it in d.get("items", []):
    if it.get("episode") == 2 and "flower" in it.get("voiceStudio", "").lower():
        print(it)
