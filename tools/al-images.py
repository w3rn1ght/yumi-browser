import io
import os
import re

h = io.open(os.path.join(os.environ["TEMP"], "al-home-ios.html"), encoding="utf-8", errors="replace").read()
imgs = re.findall(r"<img[^>]+>", h)
print("imgs", len(imgs))
for t in imgs[:25]:
    print(t[:400])
print("webp", h.count(".webp"), "avif", h.count(".avif"), "next/image", h.count("/_next/image"))
