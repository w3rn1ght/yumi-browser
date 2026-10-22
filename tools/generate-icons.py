from PIL import Image, ImageDraw
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Resources")
S = 1024


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def make_base():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    c1 = (108, 92, 231)
    c2 = (0, 184, 217)
    for y in range(S):
        for x in range(S):
            t = (x / S * 0.55 + y / S * 0.45)
            px[x, y] = lerp(c1, c2, t) + (255,)

    draw = ImageDraw.Draw(img)
    # soft highlight
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-S * 0.25, -S * 0.55, S * 0.85, S * 0.45), fill=(255, 255, 255, 26))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    w = 78
    # Y
    draw.line([(318, 282), (512, 520)], fill=(255, 255, 255, 255), width=w)
    draw.line([(512, 520), (706, 282)], fill=(255, 255, 255, 255), width=w)
    draw.line([(512, 520), (512, 724)], fill=(255, 255, 255, 255), width=w)
    for pt in [(318, 282), (706, 282), (512, 724)]:
        r = w // 2
        draw.ellipse((pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r), fill=(255, 255, 255, 255))
    # play triangle
    draw.polygon([(590, 590), (742, 670), (590, 750)], fill=(255, 255, 255, 238))
    return img


base = make_base()
sizes = {
    "Icon-20.png": 20,
    "Icon-20@2x.png": 40,
    "Icon-20@3x.png": 60,
    "Icon-29.png": 29,
    "Icon-29@2x.png": 58,
    "Icon-29@3x.png": 87,
    "Icon-40.png": 40,
    "Icon-40@2x.png": 80,
    "Icon-40@3x.png": 120,
    "Icon-60@2x.png": 120,
    "Icon-60@3x.png": 180,
    "Icon-76.png": 76,
    "Icon-76@2x.png": 152,
    "Icon-83.5@2x.png": 167,
    "Icon-1024.png": 1024,
}

for name, size in sizes.items():
    resized = base.resize((size, size), Image.LANCZOS)
    # iOS icons should be opaque
    bg = Image.new("RGB", (size, size), (108, 92, 231))
    bg.paste(resized, (0, 0), resized)
    bg.save(os.path.join(OUT, name), "PNG")
    print(name, size)
