import zipfile

z = zipfile.ZipFile("artifacts/v1.0.2/Yumi-unsigned.ipa")
b = z.read("Payload/Yumi.app/Yumi")
print("bin len", len(b))
checks = [
    b"anilibria.fun",
    b"YumiResumeStore",
    "Продолжить".encode("utf-16-le"),
    b"YumiAnilibriaResolver",
    b"plapi.cdnvideohub.com",
    "Серии и озвучки".encode("utf-16-le"),
]
for s in checks:
    print(s[:50], s in b)
h = z.read("Payload/Yumi.app/Info.plist")
print("info len", len(h))
print(h[:300])
