import io
import tarfile
import lzma
import zipfile

# quick check of the packaged home.html and icons
with zipfile.ZipFile("artifacts/v1.0.2/Yumi-unsigned.ipa") as z:
    home = z.read("Payload/Yumi.app/home.html").decode("utf-8")
    print("home has add button:", "Добавить сайт" in home)
    print("home has old default sites:", "yummyani" in home or "anilibria" in home)
    print("home size:", len(home))
    icon = z.read("Payload/Yumi.app/Icon-60@3x.png")
    print("icon size:", len(icon))
