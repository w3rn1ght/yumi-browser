import sys

for path in sys.argv[1:]:
    with open(path, "rb") as f:
        data = f.read()
    if data.startswith(b"\xef\xbb\xbf"):
        data = data[3:]
    data = data.replace(b"\r\n", b"\n")
    with open(path, "wb") as f:
        f.write(data)
    print(path, len(data), data[:4])
