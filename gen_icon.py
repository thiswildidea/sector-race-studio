# -*- coding: utf-8 -*-
"""生成应用图标 app.ico（纯标准库，不依赖 Pillow）。

图案对应应用的双面板布局：上半是成交量柱，下半是累计换手率的面积曲线。
ICO 允许直接内嵌 PNG 负载（Vista 及以后），所以先写 PNG 再套 ICO 头。
"""

import struct
import sys
import zlib
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

SIZE = 256
OUT = Path(__file__).parent / "app.ico"

BG = (12, 16, 40)
BAR_COLORS = [(37, 99, 235), (6, 182, 212), (34, 211, 238), (14, 165, 233), (56, 189, 248)]
BAR_HEIGHTS = [0.45, 0.82, 0.58, 1.0, 0.66]
AREA_TOP = (236, 72, 153)
AREA_BOT = (99, 102, 241)


def rounded_alpha(x, y, size, radius):
    """圆角矩形的覆盖率，用于边缘抗锯齿。"""
    cx = min(max(x, radius), size - radius)
    cy = min(max(y, radius), size - radius)
    dx, dy = x - cx, y - cy
    d = (dx * dx + dy * dy) ** 0.5
    return max(0.0, min(1.0, radius - d + 0.5))


def curve_y(x, left, right, top, bottom):
    """单调上升的累计曲线（缓入缓出）。"""
    t = (x - left) / max(1.0, right - left)
    t = min(max(t, 0.0), 1.0)
    eased = t * t * (3 - 2 * t)
    return bottom - eased * (bottom - top)


def build_pixels():
    pad = 30
    left, right = pad + 6, SIZE - pad - 6

    # 上半：柱状图
    bar_base, bar_top = 112, 46
    n = len(BAR_HEIGHTS)
    slot = (right - left) / n
    bw = slot * 0.6

    # 下半：面积曲线
    area_base, area_top = 214, 140

    rows = []
    for y in range(SIZE):
        row = bytearray()
        for x in range(SIZE):
            r, g, b = BG

            for i, h in enumerate(BAR_HEIGHTS):
                bx = left + slot * i + (slot - bw) / 2
                if bx <= x < bx + bw:
                    by = bar_base - (bar_base - bar_top) * h
                    if by <= y <= bar_base:
                        c = BAR_COLORS[i]
                        f = 1.0 - 0.45 * ((y - by) / max(1.0, bar_base - by))
                        r, g, b = (int(v * f) for v in c)
                    break

            if left <= x <= right:
                cy = curve_y(x, left, right, area_top, area_base)
                if cy <= y <= area_base:
                    k = (y - cy) / max(1.0, area_base - cy)
                    r, g, b = (int(AREA_TOP[j] * (1 - k) + AREA_BOT[j] * k) for j in range(3))
                    if y - cy < 4:                      # 曲线本身加亮
                        r, g, b = 255, 214, 240

            a = int(255 * rounded_alpha(x + 0.5, y + 0.5, SIZE, 52))
            row += bytes((r, g, b, a))
        rows.append(bytes(row))
    return rows


def png_bytes(rows):
    raw = b"".join(b"\x00" + r for r in rows)

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)   # 8bit RGBA
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b""))


def main():
    png = png_bytes(build_pixels())
    header = struct.pack("<HHH", 0, 1, 1)
    entry = struct.pack("<BBBBHHII", 0, 0, 0, 0, 1, 32, len(png), 22)  # 0,0 表示 256x256
    OUT.write_bytes(header + entry + png)
    print(f"已生成 {OUT.name}  ({OUT.stat().st_size:,} 字节, 内嵌 PNG {len(png):,} 字节)")


if __name__ == "__main__":
    main()
