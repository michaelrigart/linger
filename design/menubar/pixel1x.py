import struct, sys, zlib

TOP = ["." * 18] * 4
SUN_FILLED = [
    "......:####:......",
    ".....+######+.....",
    "....+########+....",
    "....##########....",
    "....##########....",
]
SUN_OUTLINE = [
    "......:####:......",
    ".....+#....#+.....",
    "....+#......#+....",
    "....#........#....",
    "....#........#....",
]
SUN_HALF = [
    "......:####:......",
    ".....+###..#+.....",
    "....+####...#+....",
    "....#####....#....",
    "....#####....#....",
]
WAVE = [
    "##+..########..+##",
    "####..........####",
    "##################",
    "..+############+..",
    "....+########+....",
]
BOTTOM = ["." * 18] * 4

ALPHA = {"#": 255, "+": 150, ":": 80, ".": 0}


def png(rows, path):
    assert len(rows) == 18 and all(len(r) == 18 for r in rows), [len(r) for r in rows]
    raw = b"".join(b"\x00" + b"".join(bytes((0, 0, 0, ALPHA[c])) for c in r) for r in rows)
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 18, 18, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(data)


catalog = sys.argv[1]
for name, asset, sun in [
    ("filled", "LingerMenuBar", SUN_FILLED),
    ("outline", "LingerMenuBarOutline", SUN_OUTLINE),
    ("half", "LingerMenuBarHalf", SUN_HALF),
]:
    rows = TOP + sun + WAVE + BOTTOM
    if name != "half":
        assert all(r == r[::-1] for r in rows), name
    print(name)
    print("\n".join(rows[3:15]))
    png(rows, f"{catalog}/{asset}.imageset/{asset}@1x.png")
