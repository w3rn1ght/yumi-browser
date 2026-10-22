import zipfile
import plistlib

z = zipfile.ZipFile("artifacts/v1.0.2/Yumi-unsigned.ipa")
h = z.read("Payload/Yumi.app/Info.plist")
d = plistlib.loads(h)
print("IPA version:", d.get("CFBundleShortVersionString"), d.get("CFBundleVersion"))
print("IPA min OS:", d.get("MinimumOSVersion"))
print("IPA icons:", d.get("CFBundleIconFiles"))
