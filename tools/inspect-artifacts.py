import io, os, tarfile, lzma, gzip, plistlib, sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
deb = os.path.join(root, "artifacts", "v1.0.1", "packages", "Yumi-1.0.1.deb")
ipa = os.path.join(root, "artifacts", "v1.0.1", "build", "Yumi-unsigned.ipa")

def ar_members(path):
    with open(path, "rb") as f:
        assert f.read(8) == b"!<arch>\n", "not an ar archive"
        while True:
            hdr = f.read(60)
            if len(hdr) < 60:
                break
            name = hdr[0:16].decode("utf-8", "replace").strip().rstrip("/")
            size = int(hdr[48:58].decode("ascii").strip())
            data = f.read(size)
            if size % 2 == 1:
                f.read(1)
            yield name, data

def open_tar(data):
    if data[:2] == b"\x1f\x8b":
        return tarfile.open(fileobj=io.BytesIO(gzip.decompress(data)))
    return tarfile.open(fileobj=io.BytesIO(data), mode="r:xz")

print("== DEB ==")
for name, data in ar_members(deb):
    print(f"{name}: {len(data)} bytes")
    if name.startswith("control.tar"):
        with open_tar(data) as t:
            for m in t.getmembers():
                if m.name.endswith("control"):
                    print(t.extractfile(m).read().decode("utf-8", "replace"))
    if name.startswith("data.tar"):
        with open_tar(data) as t:
            names = t.getnames()
            app = [n for n in names if n.endswith("Yumi.app")][0]
            print("app dir:", app)
            for n in names:
                if n.startswith(app + "/") and n.count("/") == app.count("/") + 1:
                    print("  ", n)
                if n.endswith("LaunchScreen.storyboardc/Info.plist"):
                    print("  storyboardc present:", n)

print("== IPA ==")
import zipfile
with zipfile.ZipFile(ipa) as z:
    names = z.namelist()
    print("entries:", len(names))
    for n in names:
        if n.count("/") <= 3:
            print("  ", n)

    info_name = [n for n in names if n.endswith("/Yumi.app/Info.plist")][0]
    pl = plistlib.loads(z.read(info_name))
    print("== Info.plist ==")
    print("CFBundleShortVersionString:", pl.get("CFBundleShortVersionString"))
    print("MinimumOSVersion:", pl.get("MinimumOSVersion"))
    print("CFBundleExecutable:", pl.get("CFBundleExecutable"))
    bin_name = [n for n in names if n.endswith("/" + pl["CFBundleExecutable"])][0]
    blob = z.read(bin_name)
    print("binary:", bin_name, len(blob), "bytes")
    for needle in ["Серии", "Не удалось определить id аниме", "plapi.cdnvideohub.com"]:
        u8 = needle.encode("utf-8") in blob
        u16 = needle.encode("utf-16-le") in blob
        print(f"  contains {needle!r}: utf8={u8} utf16={u16}")
