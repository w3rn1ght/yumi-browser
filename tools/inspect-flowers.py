import io
import json
import os
import re

d = json.load(io.open(os.path.join(os.environ["TEMP"], "yummy-videos.json"), encoding="utf-8"))["response"]
for item in d:
    dub = item.get("data", {}).get("dubbing", "")
    if "flowers" in dub.lower():
        print("ep", item.get("number"), "player", item.get("data", {}).get("player"), "dub", dub)
        print("  ", item.get("iframe_url"))
