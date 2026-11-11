#!/usr/bin/env python3
# 首批美术资产程序化生成（docs/tech/05-美术管线.md §7，14 清单 #7：零外部版权，纯标准库合成，可复跑）。
# 已存在的文件一律跳过（正式美术不被占位图覆盖），--force 才覆盖。
# 用法：python3 game/tools/gen_art.py [--new | --icons | --scenes | --home]（--new = P6.4 第二批；--icons = 道具图标；--scenes = 地图/场所背景；--home = 起步包主屏插画 kit/_game/home_art.png）→  写入 game/assets/art/{units,portraits}/*.png（128px RGBA 透明底）
# 风格：剪影 + 墨色渐变 + 金墨描边（与主屏绘卷一致，04 §4 ink/金墨配色）；头像叠识别色描边。
# 管线：512px 超采样栅格化（多边形扫描线 + 圆）→ 盒滤波降采样 128px = 抗锯齿（filter on 平滑档，tech/05 §4）。
import os
import struct
import zlib

SS = 512          # 超采样边长（4x）
OUT_SIZE = 128    # 交付档（tech/05 §3：单位 128 / 头像 128）
HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, "..", "assets", "art"))

INK_TOP = (26, 26, 44)      # 墨色渐变顶（微亮的深蓝黑）
INK_BOTTOM = (4, 4, 12)     # 墨色渐变底
GOLD = (224, 181, 82)       # 金墨描边（04 §4 GOLD）
PAPER = (216, 209, 184)     # 空白页/纸面
TEAL = (92, 184, 172)       # 珂兰识别色（青）
RUST = (216, 132, 62)       # 老费识别色（橙褐）

# 固定种子 LCG（确定性噪声：可复跑逐字节一致，同 gen_audio.py 口径）
_state = [20261109]


def rnd():
    _state[0] = (_state[0] * 1103515245 + 12345) & 0x7FFFFFFF
    return _state[0] / 0x7FFFFFFF


class Canvas:
    """超采样栅格：mask=剪影覆盖，px=RGB 颜色层，al=alpha 层。"""

    def __init__(self):
        self.mask = bytearray(SS * SS)
        self.px = bytearray(SS * SS * 3)
        self.al = bytearray(SS * SS)

    # ---- 形状 primitives（写入 mask；归一化坐标，y 向下）----

    def _set(self, x, y):
        if 0 <= x < SS and 0 <= y < SS:
            self.mask[y * SS + x] = 1

    def circle(self, cx, cy, r):
        x0, x1 = int((cx - r) * SS), int((cx + r) * SS) + 1
        y0, y1 = int((cy - r) * SS), int((cy + r) * SS) + 1
        rr = r * SS
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                dx, dy = x + 0.5 - cx * SS, y + 0.5 - cy * SS
                if dx * dx + dy * dy <= rr * rr:
                    self._set(x, y)

    def ellipse(self, cx, cy, rx, ry):
        x0, x1 = int((cx - rx) * SS), int((cx + rx) * SS) + 1
        y0, y1 = int((cy - ry) * SS), int((cy + ry) * SS) + 1
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                dx = (x + 0.5 - cx * SS) / (rx * SS)
                dy = (y + 0.5 - cy * SS) / (ry * SS)
                if dx * dx + dy * dy <= 1.0:
                    self._set(x, y)

    def poly(self, pts):
        """多边形扫描线填充（even-odd）。pts = [(x,y), ...] 归一化。"""
        p = [(x * SS, y * SS) for x, y in pts]
        ys = [q[1] for q in p]
        y0, y1 = max(0, int(min(ys))), min(SS - 1, int(max(ys)) + 1)
        n = len(p)
        for y in range(y0, y1 + 1):
            yc = y + 0.5
            xs = []
            for i in range(n):
                ax, ay = p[i]
                bx, by = p[(i + 1) % n]
                if (ay <= yc < by) or (by <= yc < ay):
                    xs.append(ax + (yc - ay) * (bx - ax) / (by - ay))
            xs.sort()
            for k in range(0, len(xs) - 1, 2):
                for x in range(max(0, int(xs[k])), min(SS, int(xs[k + 1]) + 1)):
                    self._set(x, y)

    def ring(self, cx, cy, r, w):
        """圆环（mask 写入；描边环用于光环等）。"""
        x0, x1 = int((cx - r - w) * SS), int((cx + r + w) * SS) + 1
        y0, y1 = int((cy - r - w) * SS), int((cy + r + w) * SS) + 1
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                d = ((x + 0.5 - cx * SS) ** 2 + (y + 0.5 - cy * SS) ** 2) ** 0.5 / SS
                if r - w <= d <= r + w:
                    self._set(x, y)

    # ---- 着色 ----

    def ink_fill(self):
        """mask 内填墨色纵向渐变 + 固定种子噪声（墨渍颗粒感）。"""
        for y in range(SS):
            t = y / (SS - 1)
            base = [INK_TOP[i] + (INK_BOTTOM[i] - INK_TOP[i]) * t for i in range(3)]
            for x in range(SS):
                if not self.mask[y * SS + x]:
                    continue
                n = (rnd() - 0.5) * 10.0
                o = (y * SS + x) * 3
                for i in range(3):
                    self.px[o + i] = max(0, min(255, int(base[i] + n)))
                self.al[y * SS + x] = 255

    def rim(self, color, thick=2, top_only=True):
        """剪影边缘描边：朝光面（上/左）着描边色。thick 为超采样像素宽。"""
        edge = []
        for y in range(SS):
            for x in range(SS):
                if not self.mask[y * SS + x]:
                    continue
                for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                    nx, ny = x + dx, y + dy
                    out = nx < 0 or ny < 0 or nx >= SS or ny >= SS or not self.mask[ny * SS + nx]
                    if out and (not top_only or dy <= 0):
                        edge.append((x, y))
                        break
        thick2 = thick * thick
        for ex, ey in edge:
            for y in range(ey - thick, ey + thick + 1):
                for x in range(ex - thick, ex + thick + 1):
                    if 0 <= x < SS and 0 <= y < SS and (x - ex) ** 2 + (y - ey) ** 2 <= thick2 \
                            and self.mask[y * SS + x]:
                        o = (y * SS + x) * 3
                        for i in range(3):
                            # 与墨色底混合，描边不死板
                            self.px[o + i] = int(self.px[o + i] * 0.35 + color[i] * 0.65)

    def paint_circle(self, cx, cy, r, color, alpha=255):
        """细节点画（眼睛/纸面/道具），直接写颜色层，不参与 mask。"""
        x0, x1 = int((cx - r) * SS), int((cx + r) * SS) + 1
        y0, y1 = int((cy - r) * SS), int((cy + r) * SS) + 1
        rr = r * SS
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if not (0 <= x < SS and 0 <= y < SS):
                    continue
                dx, dy = x + 0.5 - cx * SS, y + 0.5 - cy * SS
                if dx * dx + dy * dy <= rr * rr:
                    o = (y * SS + x) * 3
                    a = alpha / 255.0
                    for i in range(3):
                        self.px[o + i] = int(self.px[o + i] * (1 - a) + color[i] * a)
                    self.al[y * SS + x] = max(self.al[y * SS + x], alpha)

    def paint_rect(self, x, y, w, h, color, alpha=255):
        for yy in range(int(y * SS), int((y + h) * SS)):
            for xx in range(int(x * SS), int((x + w) * SS)):
                if 0 <= xx < SS and 0 <= yy < SS:
                    o = (yy * SS + xx) * 3
                    a = alpha / 255.0
                    for i in range(3):
                        self.px[o + i] = int(self.px[o + i] * (1 - a) + color[i] * a)
                    self.al[yy * SS + xx] = max(self.al[yy * SS + xx], alpha)

    def paint_ring(self, cx, cy, r, w, color, alpha=255):
        x0, x1 = int((cx - r - w) * SS), int((cx + r + w) * SS) + 1
        y0, y1 = int((cy - r - w) * SS), int((cy + r + w) * SS) + 1
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if not (0 <= x < SS and 0 <= y < SS):
                    continue
                d = ((x + 0.5 - cx * SS) ** 2 + (y + 0.5 - cy * SS) ** 2) ** 0.5 / SS
                if r - w <= d <= r + w:
                    o = (y * SS + x) * 3
                    a = alpha / 255.0
                    for i in range(3):
                        self.px[o + i] = int(self.px[o + i] * (1 - a) + color[i] * a)
                    self.al[y * SS + x] = max(self.al[y * SS + x], alpha)

    # ---- 图标用：分件着色（每件独立剪影 → 渐变填色 → 描边 → 清 mask）----

    def stroke(self, pts, r):
        """折线粗描（mask）：沿线段等距落圆。"""
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            n = max(2, int(((bx - ax) ** 2 + (by - ay) ** 2) ** 0.5 / (r * 0.5)))
            for i in range(n + 1):
                t = i / n
                self.circle(ax + (bx - ax) * t, ay + (by - ay) * t, r)

    def part(self, top, bottom, rim=GOLD, thick=2, noise=8.0):
        """当前 mask 填纵向渐变（含颗粒）+ 描边，然后清 mask 供下一件。"""
        for y in range(SS):
            t = y / (SS - 1)
            base = [top[i] + (bottom[i] - top[i]) * t for i in range(3)]
            row = y * SS
            for x in range(SS):
                if not self.mask[row + x]:
                    continue
                nz = (rnd() - 0.5) * noise
                o = (row + x) * 3
                for i in range(3):
                    self.px[o + i] = max(0, min(255, int(base[i] + nz)))
                self.al[row + x] = 255
        if rim is not None:
            self.rim(rim, thick=thick)
        self.mask = bytearray(SS * SS)

    def paint_line(self, pts, r, color, alpha=255):
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            n = max(2, int(((bx - ax) ** 2 + (by - ay) ** 2) ** 0.5 / (r * 0.5)))
            for i in range(n + 1):
                t = i / n
                self.paint_circle(ax + (bx - ax) * t, ay + (by - ay) * t, r, color, alpha)

    def save(self, path):
        """盒滤波 4x 降采样到 128px 并写 PNG（RGBA8）。"""
        f = SS // OUT_SIZE
        out = bytearray()
        for y in range(OUT_SIZE):
            out.append(0)  # filter type 0
            for x in range(OUT_SIZE):
                r = g = b = a = 0
                for yy in range(y * f, y * f + f):
                    for xx in range(x * f, x * f + f):
                        o = (yy * SS + xx) * 3
                        r += self.px[o]
                        g += self.px[o + 1]
                        b += self.px[o + 2]
                        a += self.al[yy * SS + xx]
                n = f * f
                out += bytes((r // n, g // n, b // n, a // n))
        write_png(path, OUT_SIZE, OUT_SIZE, bytes(out))


def write_png(path, w, h, raw_rgba_scanlines):
    import sys
    if os.path.exists(path) and "--force" not in sys.argv and ART in os.path.abspath(path) \
            or os.path.exists(path) and "--force" not in sys.argv and "kit" in path:
        print("跳过（已存在，可能是正式美术；--force 覆盖）：%s" % path)
        return
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(raw_rgba_scanlines, 9)) + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fp:
        fp.write(png)
    print("生成 %s（%dx%d，%d 字节）" % (path, w, h, len(png)))


# ---------------------------------------------------------------- 首批资产（tech/05 §7）

def unit_ink_imp():
    """墨魈幼体：小团墨滴剪影，双角芽，底部墨须，金墨眼睛。"""
    c = Canvas()
    c.circle(0.5, 0.56, 0.26)                       # 主体墨团
    c.poly([(0.36, 0.40), (0.30, 0.20), (0.46, 0.34)])  # 左角芽
    c.poly([(0.64, 0.40), (0.70, 0.20), (0.54, 0.34)])  # 右角芽
    for i, x in enumerate((0.38, 0.5, 0.62)):       # 底部墨须滴
        c.poly([(x - 0.05, 0.76), (x + 0.05, 0.76), (x, 0.90 - 0.04 * (i % 2))])
    c.ink_fill()
    c.rim(GOLD, thick=2)
    c.paint_circle(0.42, 0.52, 0.030, GOLD)         # 双眼
    c.paint_circle(0.58, 0.52, 0.030, GOLD)
    return c


def unit_ink_fiend():
    """墨魈：魁梧墨团 + 肩部隆起 + 犄角 + 底部滴墨锯齿。"""
    c = Canvas()
    c.ellipse(0.5, 0.55, 0.28, 0.33)                # 躯干
    c.circle(0.28, 0.44, 0.12)                      # 左肩
    c.circle(0.72, 0.44, 0.12)                      # 右肩
    c.poly([(0.32, 0.34), (0.22, 0.10), (0.44, 0.28)])  # 左犄角
    c.poly([(0.68, 0.34), (0.78, 0.10), (0.56, 0.28)])  # 右犄角
    for i in range(5):                              # 底部滴墨锯齿
        x = 0.28 + i * 0.11
        c.poly([(x - 0.05, 0.80), (x + 0.05, 0.80), (x, 0.94 - 0.05 * (i % 2))])
    c.ink_fill()
    c.rim(GOLD, thick=2)
    c.paint_circle(0.41, 0.46, 0.034, GOLD)         # 双目（更大更凶）
    c.paint_circle(0.59, 0.46, 0.034, GOLD)
    return c


def unit_page_warden():
    """守页人：长袍傀儡剪影，头后残页光环，面甲金缝。"""
    c = Canvas()
    c.poly([(0.30, 0.96), (0.40, 0.30), (0.60, 0.30), (0.70, 0.96)])  # 长袍
    c.circle(0.5, 0.235, 0.075)                     # 头
    c.poly([(0.40, 0.32), (0.30, 0.52), (0.38, 0.56)])  # 左垂臂
    c.poly([(0.60, 0.32), (0.70, 0.52), (0.62, 0.56)])  # 右垂臂
    c.ink_fill()
    c.rim(GOLD, thick=2)
    c.paint_ring(0.5, 0.235, 0.135, 0.018, GOLD, 200)   # 残页光环
    c.paint_rect(0.44, 0.225, 0.12, 0.014, GOLD)    # 面甲金缝
    return c


def portrait_player_blank():
    """白页者：兜帽剪影 + 空白页脸，识别色金。"""
    c = Canvas()
    c.poly([(0.28, 0.92), (0.34, 0.30), (0.5, 0.14), (0.66, 0.30), (0.72, 0.92)])  # 兜帽袍
    c.circle(0.5, 0.34, 0.13)                       # 头部（兜帽内）
    c.ink_fill()
    c.rim(GOLD, thick=2)
    c.paint_rect(0.425, 0.27, 0.15, 0.19, PAPER)    # 空白页脸
    c.paint_ring(0.5, 0.34, 0.145, 0.012, GOLD, 160)
    return c


def portrait_companion_kelan():
    """珂兰：清瘦剪影 + 抄本挎包，识别色青。"""
    c = Canvas()
    c.poly([(0.35, 0.92), (0.41, 0.28), (0.5, 0.19), (0.59, 0.28), (0.65, 0.92)])  # 清瘦袍身
    c.circle(0.5, 0.155, 0.075)                     # 头
    c.ink_fill()
    c.rim(TEAL, thick=2)
    c.paint_circle(0.5, 0.16, 0.045, PAPER)         # 面部纸色
    c.paint_rect(0.585, 0.52, 0.11, 0.13, TEAL, 230)  # 抄本挎包（识别色块）
    c.paint_rect(0.60, 0.535, 0.08, 0.02, PAPER)    # 挎包书脊线
    return c


def portrait_companion_laofei():
    """老费：敦实剪影 + 铁钩手，识别色橙褐。"""
    c = Canvas()
    c.ellipse(0.5, 0.62, 0.27, 0.30)                # 敦实躯干
    c.circle(0.5, 0.25, 0.105)                      # 头
    c.poly([(0.42, 0.30), (0.5, 0.46), (0.58, 0.30)])   # 胡须楔
    c.ink_fill()
    c.rim(RUST, thick=2)
    c.paint_circle(0.5, 0.23, 0.055, PAPER)         # 面部纸色
    # 铁钩手（识别色粗折线：小圆串近似 J 钩）
    for t in range(12):
        a = -0.5 + t / 11.0 * 1.6
        c.paint_circle(0.74 + 0.055 * __import__("math").cos(a + 2.2),
                       0.52 + 0.07 * __import__("math").sin(a + 2.2) + 0.03 * t / 11.0,
                       0.016, RUST)
    return c


ASSETS = [
    ("units", "unit_ink_imp_128.png", unit_ink_imp),
    ("units", "unit_ink_fiend_128.png", unit_ink_fiend),
    ("units", "unit_page_warden_128.png", unit_page_warden),
    ("portraits", "portrait_player_blank_128.png", portrait_player_blank),
    ("portraits", "portrait_companion_kelan_128.png", portrait_companion_kelan),
    ("portraits", "portrait_companion_laofei_128.png", portrait_companion_laofei),
]


# ---------------------------------------------------------------- P6.4 第二批（职业头像 / 未配图敌人 / 起步包单位）

import math as _m

STEEL = (120, 160, 212)     # 港卫识别色（钢蓝）
MOSS = (150, 180, 96)       # 拾荒者识别色（苔绿）
VIOLET = (168, 128, 220)    # 墨术士识别色（紫墨）
CRIMSON = (196, 72, 72)     # 敌方人类识别色（暗红）
BONE = (200, 196, 176)


def portrait_class_harbor_guard():
    """港卫：宽肩披甲剪影 + 圆盾，识别色钢蓝。"""
    c = Canvas()
    c.poly([(0.22, 0.94), (0.28, 0.46), (0.40, 0.36), (0.60, 0.36), (0.72, 0.46), (0.78, 0.94)])  # 披甲躯干
    c.circle(0.5, 0.25, 0.10)                       # 头
    c.poly([(0.38, 0.20), (0.5, 0.10), (0.62, 0.20), (0.60, 0.24), (0.40, 0.24)])  # 盔顶
    c.circle(0.30, 0.66, 0.15)                      # 圆盾
    c.ink_fill()
    c.rim(STEEL, thick=2)
    c.paint_ring(0.30, 0.66, 0.13, 0.014, STEEL, 230)   # 盾缘
    c.paint_circle(0.30, 0.66, 0.035, GOLD)         # 盾心铆钉
    c.paint_rect(0.44, 0.235, 0.12, 0.016, STEEL)   # 面甲缝
    return c


def portrait_class_scavenger():
    """拾荒者：低伏兜帽剪影 + 钩刀 + 腰间布袋，识别色苔绿。"""
    c = Canvas()
    c.poly([(0.30, 0.94), (0.34, 0.40), (0.46, 0.22), (0.62, 0.26), (0.70, 0.94)])  # 斜兜帽袍
    c.circle(0.52, 0.34, 0.11)                      # 头（兜帽内）
    c.ellipse(0.40, 0.74, 0.08, 0.07)               # 布袋
    c.ink_fill()
    c.rim(MOSS, thick=2)
    c.paint_circle(0.55, 0.35, 0.05, PAPER, 200)    # 半遮面
    c.paint_rect(0.44, 0.33, 0.16, 0.035, INK_BOTTOM, 230)  # 面巾
    for t in range(14):                             # 钩刀：刀杆 + 弯钩
        a = t / 13.0
        c.paint_circle(0.72 + 0.02 * a, 0.80 - 0.32 * a, 0.012, BONE)
    for t in range(10):
        a = -0.3 + t / 9.0 * 2.4
        c.paint_circle(0.70 + 0.05 * _m.cos(a), 0.46 - 0.05 * _m.sin(a), 0.013, MOSS)
    return c


def portrait_class_ink_adept():
    """墨术士：长袍剪影 + 举起的笔 + 环绕墨符，识别色紫墨。"""
    c = Canvas()
    c.poly([(0.30, 0.94), (0.40, 0.32), (0.5, 0.22), (0.60, 0.32), (0.70, 0.94)])  # 长袍
    c.circle(0.5, 0.22, 0.085)                      # 头
    c.poly([(0.60, 0.40), (0.76, 0.24), (0.80, 0.28), (0.64, 0.46)])  # 举笔的手臂
    c.ink_fill()
    c.rim(VIOLET, thick=2)
    c.paint_circle(0.5, 0.225, 0.05, PAPER)         # 面部纸色
    c.paint_rect(0.78, 0.10, 0.018, 0.16, GOLD)     # 笔杆
    c.paint_circle(0.789, 0.27, 0.018, VIOLET)      # 笔尖墨滴
    for k in range(7):                              # 墨符环
        a = k / 7.0 * 2 * _m.pi + 0.4
        c.paint_circle(0.5 + 0.30 * _m.cos(a), 0.56 + 0.20 * _m.sin(a), 0.022, VIOLET, 210)
    return c


def unit_ink_swarm():
    """墨魈群：三团小墨滴挤成一簇，眼点成串。"""
    c = Canvas()
    for cx, cy, r in ((0.34, 0.62, 0.16), (0.64, 0.60, 0.17), (0.50, 0.40, 0.15)):
        c.circle(cx, cy, r)
        c.poly([(cx - 0.04, cy + r - 0.02), (cx + 0.04, cy + r - 0.02), (cx, cy + r + 0.10)])
    c.ink_fill()
    c.rim(GOLD, thick=2)
    for cx, cy in ((0.30, 0.60), (0.38, 0.60), (0.60, 0.58), (0.68, 0.58), (0.46, 0.38), (0.54, 0.38)):
        c.paint_circle(cx, cy, 0.020, GOLD)
    return c


def unit_uninked_guard():
    """断墨会守卫：裹布头巾 + 长棍，胸前空白徽记。"""
    c = Canvas()
    c.poly([(0.30, 0.94), (0.36, 0.40), (0.64, 0.40), (0.70, 0.94)])
    c.circle(0.5, 0.28, 0.11)
    c.poly([(0.36, 0.26), (0.5, 0.14), (0.64, 0.26), (0.66, 0.34), (0.34, 0.34)])  # 头巾
    c.poly([(0.74, 0.12), (0.78, 0.12), (0.80, 0.94), (0.76, 0.94)])  # 长棍
    c.ink_fill()
    c.rim(PAPER, thick=2)
    c.paint_circle(0.5, 0.56, 0.06, PAPER)          # 空白徽记
    c.paint_rect(0.42, 0.30, 0.16, 0.02, GOLD)      # 眼缝
    return c


def unit_tax_guard():
    """墨税卫：高帽制服 + 账簿 + 长戟，识别色暗红。"""
    c = Canvas()
    c.poly([(0.30, 0.94), (0.36, 0.40), (0.64, 0.40), (0.70, 0.94)])
    c.circle(0.5, 0.29, 0.10)
    c.poly([(0.40, 0.22), (0.42, 0.06), (0.58, 0.06), (0.60, 0.22)])  # 高帽
    c.poly([(0.20, 0.10), (0.24, 0.10), (0.26, 0.94), (0.22, 0.94)])  # 戟杆
    c.poly([(0.16, 0.12), (0.22, 0.02), (0.28, 0.12), (0.22, 0.20)])  # 戟头
    c.ink_fill()
    c.rim(CRIMSON, thick=2)
    c.paint_rect(0.56, 0.52, 0.12, 0.15, PAPER)     # 账簿
    c.paint_rect(0.58, 0.56, 0.08, 0.012, CRIMSON)
    c.paint_rect(0.58, 0.60, 0.08, 0.012, CRIMSON)
    c.paint_rect(0.42, 0.135, 0.16, 0.02, CRIMSON)  # 帽箍
    return c


def unit_dock_ambusher():
    """码头伏击者：蹲伏剪影 + 双短刀。"""
    c = Canvas()
    c.ellipse(0.5, 0.66, 0.26, 0.22)                # 蹲伏躯干
    c.circle(0.5, 0.40, 0.10)
    c.poly([(0.22, 0.60), (0.10, 0.48), (0.14, 0.44), (0.28, 0.54)])  # 左臂刀
    c.poly([(0.78, 0.60), (0.90, 0.48), (0.86, 0.44), (0.72, 0.54)])
    c.ink_fill()
    c.rim(CRIMSON, thick=2)
    c.paint_rect(0.42, 0.39, 0.16, 0.02, GOLD)
    c.paint_rect(0.08, 0.44, 0.06, 0.012, BONE)
    c.paint_rect(0.86, 0.44, 0.06, 0.012, BONE)
    return c


def unit_mercenary():
    """雇佣兵：披风 + 大剑斜背。"""
    c = Canvas()
    c.poly([(0.26, 0.94), (0.34, 0.38), (0.66, 0.38), (0.74, 0.94)])
    c.circle(0.5, 0.27, 0.10)
    c.poly([(0.22, 0.20), (0.27, 0.16), (0.80, 0.86), (0.75, 0.90)])  # 大剑
    c.ink_fill()
    c.rim(CRIMSON, thick=2)
    c.paint_rect(0.42, 0.26, 0.16, 0.02, GOLD)
    c.paint_circle(0.25, 0.18, 0.03, GOLD)          # 剑柄头
    return c


def unit_tide_avatar():
    """墨潮化身：浪头形巨影 + 多目 + 墨滴王冠。"""
    c = Canvas()
    c.poly([(0.10, 0.94), (0.16, 0.50), (0.30, 0.26), (0.52, 0.14), (0.74, 0.22),
            (0.86, 0.40), (0.76, 0.46), (0.82, 0.62), (0.90, 0.94)])
    for k in range(5):
        x = 0.30 + k * 0.10
        c.poly([(x - 0.03, 0.18 + 0.02 * (k % 2)), (x, 0.04 + 0.03 * (k % 2)), (x + 0.03, 0.18 + 0.02 * (k % 2))])
    c.ink_fill()
    c.rim(GOLD, thick=3)
    for cx, cy in ((0.40, 0.40), (0.52, 0.36), (0.62, 0.42), (0.47, 0.50)):
        c.paint_circle(cx, cy, 0.030, GOLD)
    return c


def unit_bandit():
    """（起步包）山贼：兜帽 + 斧。"""
    c = Canvas()
    c.poly([(0.30, 0.94), (0.36, 0.40), (0.5, 0.18), (0.64, 0.40), (0.70, 0.94)])
    c.circle(0.5, 0.32, 0.10)
    c.poly([(0.72, 0.20), (0.76, 0.20), (0.78, 0.80), (0.74, 0.80)])
    c.poly([(0.70, 0.20), (0.86, 0.16), (0.86, 0.32), (0.72, 0.30)])
    c.ink_fill()
    c.rim(CRIMSON, thick=2)
    c.paint_rect(0.43, 0.31, 0.14, 0.02, GOLD)
    return c


def unit_wolf():
    """（起步包）狼：侧身剪影，竖耳长尾。"""
    c = Canvas()
    c.ellipse(0.50, 0.58, 0.28, 0.14)               # 躯干
    c.poly([(0.70, 0.52), (0.88, 0.42), (0.92, 0.50), (0.80, 0.60)])  # 头吻
    c.poly([(0.74, 0.46), (0.76, 0.32), (0.82, 0.44)])  # 耳
    c.poly([(0.24, 0.56), (0.06, 0.44), (0.10, 0.54), (0.24, 0.64)])  # 尾
    for x in (0.32, 0.42, 0.58, 0.68):              # 腿
        c.poly([(x - 0.03, 0.66), (x + 0.03, 0.66), (x + 0.02, 0.86), (x - 0.02, 0.86)])
    c.ink_fill()
    c.rim(BONE, thick=2)
    c.paint_circle(0.84, 0.47, 0.016, GOLD)
    return c


def unit_scout():
    """（起步包）斥候：轻装 + 短弓。"""
    c = Canvas()
    c.poly([(0.34, 0.94), (0.40, 0.40), (0.60, 0.40), (0.66, 0.94)])
    c.circle(0.5, 0.29, 0.09)
    c.ink_fill()
    c.rim(MOSS, thick=2)
    for t in range(16):                             # 弓弧
        a = -1.1 + t / 15.0 * 2.2
        c.paint_circle(0.70 + 0.10 * _m.cos(a), 0.56 + 0.20 * _m.sin(a), 0.012, BONE)
    c.paint_rect(0.799, 0.37, 0.006, 0.38, PAPER, 180)  # 弓弦
    c.paint_rect(0.43, 0.285, 0.14, 0.018, GOLD)
    return c


ASSETS_P64 = [
    ("portraits", "portrait_class_harbor_guard_128.png", portrait_class_harbor_guard),
    ("portraits", "portrait_class_scavenger_128.png", portrait_class_scavenger),
    ("portraits", "portrait_class_ink_adept_128.png", portrait_class_ink_adept),
    ("units", "unit_ink_swarm_128.png", unit_ink_swarm),
    ("units", "unit_uninked_guard_128.png", unit_uninked_guard),
    ("units", "unit_tax_guard_128.png", unit_tax_guard),
    ("units", "unit_dock_ambusher_128.png", unit_dock_ambusher),
    ("units", "unit_mercenary_128.png", unit_mercenary),
    ("units", "unit_tide_avatar_128.png", unit_tide_avatar),
    ("units", "unit_bandit_128.png", unit_bandit),
    ("units", "unit_wolf_128.png", unit_wolf),
    ("units", "unit_scout_128.png", unit_scout),
]


# ---------------------------------------------------------------- 道具图标（icons/，128px；tech/05 §7.2）
# 风格同单位：分件剪影 + 渐变 + 金墨描边；物件色区分种类（药剂蓝 / 墨紫 / 木褐 / 钢灰 / 纸黄 / 金）。

GLASS = ((120, 170, 220), (40, 80, 140))
INKC = ((70, 56, 110), (16, 12, 34))
WOODC = ((140, 100, 62), (70, 46, 26))
STEELC = ((190, 200, 214), (90, 100, 118))
PAPERC = ((236, 228, 200), (180, 168, 134))
GOLDC = ((246, 210, 120), (170, 120, 40))
LEATHER = ((150, 104, 66), (84, 54, 32))
REDC = ((210, 80, 70), (120, 30, 30))
BONEC = ((236, 228, 206), (170, 160, 134))
WHITE = (250, 250, 240)


def _potion(liquid):
    c = Canvas()
    c.circle(0.5, 0.62, 0.25)
    c.poly([(0.43, 0.42), (0.43, 0.24), (0.57, 0.24), (0.57, 0.42)])
    c.part(*liquid)
    c.poly([(0.41, 0.24), (0.41, 0.14), (0.59, 0.14), (0.59, 0.24)])
    c.part(*WOODC)
    c.paint_circle(0.41, 0.56, 0.05, WHITE, 140)       # 玻璃高光
    c.paint_rect(0.30, 0.60, 0.40, 0.012, WHITE, 70)   # 液面线
    return c


def icon_heal_potion():
    return _potion(GLASS)


def icon_potion():
    return _potion(((220, 90, 90), (120, 30, 40)))


def icon_ink_flask():
    c = Canvas()
    c.poly([(0.24, 0.86), (0.28, 0.46), (0.40, 0.38), (0.60, 0.38), (0.72, 0.46), (0.76, 0.86)])
    c.poly([(0.42, 0.40), (0.42, 0.24), (0.58, 0.24), (0.58, 0.40)])
    c.part(*INKC)
    c.circle(0.5, 0.22, 0.09)
    c.part(*REDC, rim=None)                             # 蜡封
    c.paint_circle(0.36, 0.60, 0.04, WHITE, 90)
    return c


def icon_ink_salve():
    c = Canvas()
    c.ellipse(0.5, 0.66, 0.32, 0.14)
    c.poly([(0.18, 0.66), (0.18, 0.52), (0.82, 0.52), (0.82, 0.66)])
    c.part(*STEELC)
    c.ellipse(0.5, 0.52, 0.32, 0.12)
    c.part((168, 128, 220), (80, 50, 130))               # 紫墨膏面
    c.paint_circle(0.42, 0.50, 0.04, WHITE, 120)
    return c


def icon_tide_bomb():
    c = Canvas()
    c.circle(0.48, 0.58, 0.28)
    c.part((176, 132, 96), (90, 60, 40))
    for k in range(5):                                  # 网绳
        x = 0.28 + k * 0.10
        c.paint_line([(x, 0.34), (x + 0.04, 0.84)], 0.008, (60, 44, 30), 220)
    c.paint_line([(0.22, 0.52), (0.74, 0.50)], 0.008, (60, 44, 30), 220)
    c.paint_line([(0.24, 0.66), (0.72, 0.68)], 0.008, (60, 44, 30), 220)
    c.paint_line([(0.62, 0.34), (0.72, 0.20), (0.80, 0.16)], 0.014, (90, 70, 50))
    c.paint_circle(0.82, 0.14, 0.04, (255, 200, 90))    # 火花
    c.paint_circle(0.82, 0.14, 0.07, (255, 160, 60), 90)
    c.paint_circle(0.40, 0.52, 0.05, (120, 180, 220), 120)  # 内里海水光
    return c


def icon_ink_core():
    c = Canvas()
    c.poly([(0.5, 0.10), (0.78, 0.40), (0.62, 0.90), (0.38, 0.90), (0.22, 0.40)])
    c.part(*INKC)
    c.paint_line([(0.5, 0.10), (0.5, 0.90)], 0.006, GOLD, 120)
    c.paint_line([(0.22, 0.40), (0.78, 0.40)], 0.006, GOLD, 120)
    c.paint_circle(0.5, 0.52, 0.09, GOLD, 230)
    c.paint_circle(0.5, 0.52, 0.16, GOLD, 70)
    return c


def _page(torn_right=False):
    c = Canvas()
    pts = [(0.22, 0.12), (0.78, 0.12)]
    if torn_right:
        pts = [(0.18, 0.12), (0.58, 0.12), (0.52, 0.30), (0.62, 0.46), (0.54, 0.62), (0.64, 0.78), (0.56, 0.90), (0.18, 0.90)]
    else:
        pts += [(0.80, 0.40), (0.74, 0.56), (0.82, 0.72), (0.76, 0.90), (0.22, 0.90)]
    c.poly(pts)
    c.part(*PAPERC)
    return c


def icon_codex_fragment():
    c = _page()
    for k in range(6):
        c.paint_rect(0.30, 0.24 + k * 0.10, 0.36 - 0.04 * (k % 3), 0.018, GOLD, 200)
    return c


def icon_half_tide_table():
    c = _page(torn_right=True)
    for k in range(4):
        y = 0.30 + k * 0.14
        c.paint_line([(0.24 + j * 0.05, y + 0.03 * _m.sin(j * 1.4)) for j in range(7)], 0.010, (60, 110, 170), 230)
    return c


def icon_riddle_page():
    c = _page()
    for k in range(30):                                 # 金色螺旋（谜题）
        a = k / 29.0 * 4.5 * _m.pi
        r = 0.02 + k * 0.006
        c.paint_circle(0.5 + r * _m.cos(a), 0.50 + r * _m.sin(a), 0.012, GOLD)
    return c


def icon_fatedie():
    c = Canvas()
    hexa = [(0.5 + 0.38 * _m.cos(_m.pi / 2 + k * _m.pi / 3), 0.52 - 0.38 * _m.sin(_m.pi / 2 + k * _m.pi / 3)) for k in range(6)]
    c.poly(hexa)
    c.part(*BONEC)
    tri = [(0.5, 0.26), (0.73, 0.64), (0.27, 0.64)]
    for a, b in ((0, 1), (1, 2), (2, 0)):
        c.paint_line([tri[a], tri[b]], 0.009, GOLD)
    for v in tri:
        for h in hexa:
            if ((v[0] - h[0]) ** 2 + (v[1] - h[1]) ** 2) ** 0.5 < 0.30:
                c.paint_line([v, h], 0.006, (190, 150, 70), 200)
    return c


def icon_scriptorium_signet():
    c = Canvas()
    c.ring(0.5, 0.62, 0.22, 0.06)
    c.part(*GOLDC)
    c.ellipse(0.5, 0.36, 0.17, 0.12)
    c.part(*GOLDC)
    c.paint_line([(0.44, 0.42), (0.56, 0.30)], 0.012, (120, 80, 20))   # 羽笔印纹
    return c


def icon_scribe_ring():
    c = Canvas()
    c.ring(0.5, 0.54, 0.26, 0.045)
    c.part(*STEELC)
    c.paint_line([(0.42, 0.30), (0.58, 0.26)], 0.008, (90, 90, 110))
    return c


def icon_black_feather_token():
    c = Canvas()
    c.poly([(0.30, 0.86), (0.36, 0.60), (0.52, 0.30), (0.70, 0.10), (0.66, 0.34), (0.50, 0.62), (0.34, 0.88)])
    c.part((60, 60, 74), (10, 10, 16), rim=(140, 140, 160))
    c.paint_line([(0.32, 0.88), (0.68, 0.12)], 0.006, (160, 160, 180), 160)
    c.circle(0.66, 0.74, 0.12)
    c.part(*BONEC)
    c.paint_circle(0.66, 0.74, 0.03, (40, 40, 50))
    return c


def icon_boathook_axe():
    c = Canvas()
    c.stroke([(0.24, 0.90), (0.66, 0.16)], 0.035)
    c.part(*WOODC)
    c.poly([(0.56, 0.20), (0.82, 0.12), (0.86, 0.40), (0.66, 0.38)])
    c.poly([(0.56, 0.24), (0.42, 0.14), (0.38, 0.22), (0.52, 0.30)])
    c.part(*STEELC)
    for k in range(4):
        c.paint_rect(0.30 + k * 0.03, 0.74 - k * 0.05, 0.05, 0.012, (200, 180, 140), 200)  # 缠绳
    return c


def icon_longsword():
    c = Canvas()
    c.poly([(0.70, 0.12), (0.78, 0.18), (0.40, 0.62), (0.34, 0.56)])
    c.part(*STEELC)
    c.stroke([(0.26, 0.50), (0.48, 0.70)], 0.025)
    c.part(*GOLDC)
    c.stroke([(0.34, 0.62), (0.20, 0.80)], 0.025)
    c.part(*LEATHER)
    c.paint_circle(0.18, 0.82, 0.035, GOLD)
    return c


def icon_padded_coat():
    c = Canvas()
    c.poly([(0.30, 0.14), (0.42, 0.20), (0.58, 0.20), (0.70, 0.14), (0.90, 0.40), (0.78, 0.48), (0.74, 0.40),
            (0.74, 0.90), (0.26, 0.90), (0.26, 0.40), (0.22, 0.48), (0.10, 0.40)])
    c.part((150, 124, 92), (80, 62, 42))
    for k in range(5):
        c.paint_rect(0.28, 0.34 + k * 0.11, 0.44, 0.008, (70, 52, 34), 200)  # 绗缝
    c.paint_rect(0.495, 0.20, 0.01, 0.70, (70, 52, 34), 220)
    return c


def icon_dock_buckler():
    c = Canvas()
    c.circle(0.5, 0.5, 0.36)
    c.part(*STEELC)
    c.paint_ring(0.5, 0.5, 0.30, 0.012, (90, 100, 118), 220)
    c.paint_circle(0.5, 0.5, 0.07, GOLD)
    return c


def icon_tide_charm():
    c = Canvas()
    c.poly([(0.5, 0.80)] + [(0.5 + 0.32 * _m.cos(a), 0.62 - 0.32 * _m.sin(a)) for a in [k * _m.pi / 10 for k in range(11)]])
    c.part((240, 214, 196), (176, 130, 116))
    for k in range(1, 10, 2):
        a = k * _m.pi / 10
        c.paint_line([(0.5, 0.80), (0.5 + 0.30 * _m.cos(a), 0.62 - 0.30 * _m.sin(a))], 0.006, (150, 100, 90), 200)
    c.paint_line([(0.5, 0.30), (0.5, 0.10)], 0.008, (120, 90, 60))
    c.paint_circle(0.5, 0.76, 0.06, (240, 240, 250))
    return c


def icon_salvage_gloves():
    c = Canvas()
    c.poly([(0.30, 0.90), (0.28, 0.46), (0.32, 0.20), (0.38, 0.20), (0.40, 0.42), (0.44, 0.14), (0.50, 0.14),
            (0.52, 0.40), (0.56, 0.16), (0.62, 0.16), (0.62, 0.44), (0.68, 0.30), (0.74, 0.34), (0.68, 0.62), (0.66, 0.90)])
    c.part(*LEATHER)
    c.paint_rect(0.32, 0.46, 0.32, 0.05, (210, 170, 80))   # 黄铜护指
    c.paint_rect(0.30, 0.80, 0.36, 0.04, (110, 76, 46))
    return c


def icon_dock_tally():
    c = Canvas()
    c.poly([(0.20, 0.80), (0.72, 0.16), (0.82, 0.24), (0.30, 0.88)])
    c.part(*WOODC)
    for k in range(6):
        t = 0.18 + k * 0.12
        x, y = 0.25 + (0.77 - 0.25) * t, 0.84 - (0.84 - 0.20) * t
        c.paint_line([(x - 0.03, y - 0.03), (x + 0.03, y + 0.03)], 0.008, (60, 40, 22))
    return c


def icon_novice_quill():
    c = Canvas()
    c.poly([(0.26, 0.84), (0.40, 0.56), (0.62, 0.24), (0.82, 0.10), (0.74, 0.34), (0.54, 0.58), (0.30, 0.86)])
    c.part((248, 246, 236), (180, 176, 160))
    c.paint_line([(0.26, 0.86), (0.80, 0.12)], 0.006, (150, 146, 130), 200)
    c.paint_circle(0.25, 0.87, 0.03, (40, 30, 60))         # 墨尖
    return c


def icon_torn_ribbon():
    c = Canvas()
    c.poly([(0.16, 0.30), (0.84, 0.30), (0.78, 0.40), (0.84, 0.50), (0.16, 0.50), (0.22, 0.40)])
    c.poly([(0.40, 0.46), (0.52, 0.46), (0.42, 0.88), (0.36, 0.82)])
    c.poly([(0.52, 0.46), (0.62, 0.46), (0.70, 0.80), (0.62, 0.86)])
    c.part(*REDC)
    c.circle(0.5, 0.42, 0.10)
    c.part(*BONEC)
    return c


def icon_appraisal_loupe():
    c = Canvas()
    c.ring(0.44, 0.44, 0.22, 0.05)
    c.part(*GOLDC)
    c.paint_circle(0.44, 0.44, 0.17, (170, 210, 230), 150)
    c.paint_circle(0.38, 0.38, 0.05, WHITE, 160)
    for k in range(7):                                   # 链
        c.paint_ring(0.62 + k * 0.045, 0.62 + k * 0.045, 0.018, 0.006, (210, 170, 80))
    return c


ICON_FNS = {
    "heal_potion": icon_heal_potion, "potion": icon_potion, "ink_flask": icon_ink_flask, "ink_salve": icon_ink_salve,
    "tide_bomb": icon_tide_bomb, "ink_core": icon_ink_core, "codex_fragment": icon_codex_fragment,
    "half_tide_table": icon_half_tide_table, "riddle_page": icon_riddle_page, "fatedie": icon_fatedie,
    "scriptorium_signet": icon_scriptorium_signet, "scribe_ring": icon_scribe_ring,
    "black_feather_token": icon_black_feather_token, "boathook_axe": icon_boathook_axe, "longsword": icon_longsword,
    "padded_coat": icon_padded_coat, "dock_buckler": icon_dock_buckler, "tide_charm": icon_tide_charm,
    "salvage_gloves": icon_salvage_gloves, "dock_tally": icon_dock_tally, "novice_quill": icon_novice_quill,
    "torn_ribbon": icon_torn_ribbon, "appraisal_loupe": icon_appraisal_loupe,
}
ASSETS_ICONS = [("icons", "icon_%s_128.png" % k, f) for k, f in ICON_FNS.items()]


# ---------------------------------------------------------------- 地图 / 场所背景（scenes/，16 §6）
# 每张图覆盖 maps.json background.frame 的网格矩形：g(x, y) 把网格坐标换成图内归一化坐标，地标画在地点附近（略偏上，按钮不全遮）。

SEA = (96, 124, 140)
INKLINE = (70, 60, 48)
FOG = (236, 236, 232)


def _grid(frame):
    x0, y0, x1, y1 = frame
    return lambda gx, gy: ((gx - x0) / (x1 - x0), (gy - y0) / (y1 - y0))


def _house(P, x, y, w, col=(120, 96, 70), roof=(80, 50, 40)):
    P.rect(x - w / 2, y - w * 0.6, w, w * 0.6, col)
    P.poly([(x - w * 0.62, y - w * 0.58), (x, y - w * 1.05), (x + w * 0.62, y - w * 0.58)], roof)


def _tree(P, x, y, s, col=(70, 96, 64)):
    P.poly([(x - s * 0.5, y), (x, y - s * 1.4), (x + s * 0.5, y)], col)
    P.rect(x - s * 0.06, y, s * 0.12, s * 0.25, (90, 66, 44))


def scene_map_fog_coast():
    frame = (0, 0, 8, 6)
    g = _grid(frame)
    P = Paint(1080, 810)
    _state[0] = 20261111
    P.paper((228, 218, 190), (176, 160, 126))
    sea = [(0, 0), (0.82, 0), (0.72, 0.08), (0.66, 0.20), (0.57, 0.24), (0.46, 0.29), (0.34, 0.35),
           (0.22, 0.39), (0.13, 0.50), (0.0, 0.60)]
    P.poly(sea, SEA, 0.55)
    P.line(sea[1:], 0.004, INKLINE, 0.8)                  # 海岸线
    for k in range(18):                                  # 波纹
        x, y = rnd() * 0.6, rnd() * 0.3
        if y < 0.28 - x * 0.35:
            P.line([(x, y), (x + 0.02, y - 0.008), (x + 0.04, y)], 0.0018, (60, 80, 96), 0.7)
    # 自由市广场：屋顶群
    px, py = g(1, 5)
    for dx, dy, w in ((-0.05, -0.07, 0.045), (0.0, -0.09, 0.05), (0.05, -0.07, 0.04), (-0.02, -0.03, 0.035)):
        _house(P, px + dx, py + dy, w)
    # 渔人巷：岸边小屋 + 海上小船
    rx, ry = g(2, 3)
    for k in range(4):
        _house(P, rx - 0.07 + k * 0.035, ry - 0.08 + k * 0.012, 0.028, (130, 110, 84), (70, 60, 52))
    for bx, by in ((0.08, 0.40), (0.14, 0.33)):
        P.poly([(bx - 0.025, by), (bx + 0.025, by), (bx + 0.015, by + 0.015), (bx - 0.015, by + 0.015)], (90, 64, 40))
        P.line([(bx, by), (bx, by - 0.04)], 0.002, INKLINE)
    # 沉钟礼拜堂：半淹的礼拜堂 + 水洼
    cx, cy = g(4, 5)
    P.blob(cx + 0.02, cy - 0.04, 0.09, 0.06, SEA, 0.7)
    P.rect(cx - 0.035, cy - 0.16, 0.05, 0.08, (150, 140, 128))
    P.poly([(cx - 0.045, cy - 0.16), (cx - 0.01, cy - 0.21), (cx + 0.025, cy - 0.16)], (90, 80, 76))
    P.rect(cx + 0.015, cy - 0.20, 0.022, 0.12, (140, 130, 118))
    P.circle(cx + 0.026, cy - 0.17, 0.006, (200, 160, 70))   # 钟
    # 旧灯塔：岬角高塔 + 光束
    lx, ly = g(5, 1)
    P.blob(lx + 0.06, ly - 0.02, 0.22, 0.10, (255, 236, 170), 0.35)
    P.poly([(lx - 0.07, ly + 0.05), (lx - 0.01, ly - 0.02), (lx + 0.06, ly + 0.05)], (130, 120, 104))
    P.poly([(lx - 0.025, ly + 0.02), (lx - 0.015, ly - 0.13), (lx + 0.005, ly - 0.13), (lx + 0.015, ly + 0.02)], (200, 196, 186))
    P.rect(lx - 0.022, ly - 0.155, 0.03, 0.03, (250, 220, 120))
    for k in range(3):
        P.rect(lx - 0.02, ly - 0.10 + k * 0.035, 0.03, 0.008, (170, 60, 50))
    # 盐沼：芦苇 + 水洼 + 浓雾
    mx, my = g(7, 3)
    for k in range(6):
        P.blob(mx - 0.08 + rnd() * 0.16, my - 0.1 + rnd() * 0.18, 0.04 + rnd() * 0.03, 0.02, SEA, 0.5)
    for k in range(40):
        x, y = mx - 0.1 + rnd() * 0.2, my - 0.12 + rnd() * 0.24
        P.line([(x, y), (x + 0.004, y - 0.03)], 0.0016, (90, 110, 70), 0.9)
    # 丘陵与树丛（填空白）
    for k in range(14):
        x, y = 0.30 + rnd() * 0.45, 0.45 + rnd() * 0.45
        if abs(x - cx) < 0.08 and abs(y - cy) < 0.12:
            continue
        _tree(P, x, y, 0.022, (96, 112, 80))
    for k in range(8):
        x, y = 0.05 + rnd() * 0.25, 0.70 + rnd() * 0.25
        P.line([(x, y), (x + 0.03, y - 0.025), (x + 0.06, y)], 0.002, INKLINE, 0.7)
    # 雾团：东侧最浓，海上薄雾
    for k in range(16):
        x = 0.62 + rnd() * 0.42
        y = 0.18 + rnd() * 0.7
        P.blob(x, y, 0.10 + rnd() * 0.08, 0.05 + rnd() * 0.04, FOG, 0.45)
    for k in range(6):
        P.blob(rnd() * 0.6, rnd() * 0.25, 0.12, 0.04, FOG, 0.3)
    return P


def scene_site_lighthouse():
    frame = (0, 0, 6, 4)
    g = _grid(frame)
    P = Paint(1080, 720)
    _state[0] = 20261112
    P.paper((70, 68, 76), (30, 28, 34))                # 暗石底
    for row in range(16):                               # 石砖缝
        y = row / 16.0
        P.rect(0, y, 1.0, 0.003, (24, 22, 28), 0.8)
        off = 0.0 if row % 2 == 0 else 0.04
        for k in range(13):
            P.rect(off + k * 0.08, y, 0.003, 1 / 16.0, (24, 22, 28), 0.8)
    hx, hy = g(1, 3)
    kx, ky = g(3, 2)
    sx, sy = g(4, 3)
    lx, ly = g(5, 1)
    # 入口门厅：拱门
    P.rect(hx - 0.06, hy - 0.08, 0.05, 0.16, (20, 16, 14))
    P.circle(hx - 0.035, hy - 0.08, 0.025, (20, 16, 14))
    # 守塔人房：床 + 桌 + 窗月光
    P.rect(kx - 0.12, ky + 0.06, 0.08, 0.04, (110, 80, 56))
    P.rect(kx - 0.12, ky + 0.05, 0.03, 0.02, (210, 204, 188))
    P.rect(kx + 0.07, ky - 0.10, 0.02, 0.07, (190, 210, 230), 0.8)
    P.blob(kx + 0.08, ky - 0.04, 0.08, 0.10, (190, 210, 230), 0.15)
    # 暗格储藏室：木箱
    for dx, dy in ((0.06, 0.04), (0.10, 0.04), (0.08, -0.02)):
        P.rect(sx + dx - 0.02, sy + dy - 0.03, 0.04, 0.05, (120, 88, 56))
        P.rect(sx + dx - 0.02, sy + dy - 0.01, 0.04, 0.006, (70, 50, 30))
    # 灯室：巨镜与暖光
    P.blob(lx, ly, 0.20, 0.26, (255, 220, 140), 0.45)
    P.circle(lx, ly - 0.02, 0.05, (255, 236, 170))
    P.circle(lx, ly - 0.02, 0.03, (255, 250, 220))
    return P


def scene_map_wilds():
    frame = (0, 0, 5, 5)
    g = _grid(frame)
    P = Paint(1080, 1080)
    _state[0] = 20261113
    P.paper((214, 222, 196), (156, 170, 132))
    P.line([(0.0, 0.32), (0.25, 0.38), (0.45, 0.52), (0.58, 0.70), (0.70, 1.0)], 0.018, (110, 150, 170), 0.8)  # 河
    ix, iy = g(1, 3)
    _house(P, ix, iy - 0.05, 0.07, (140, 110, 80), (90, 60, 44))
    P.rect(ix - 0.01, iy - 0.08, 0.014, 0.014, (250, 210, 120))
    gx, gy = g(3, 1)
    for k in range(16):
        _tree(P, gx - 0.12 + rnd() * 0.24, gy - 0.02 + rnd() * 0.12, 0.035, (70, 110, 66))
    ux, uy = g(4, 4)
    for k in range(4):
        h = 0.04 + rnd() * 0.06
        P.rect(ux - 0.08 + k * 0.045, uy - 0.04 - h, 0.02, h, (170, 166, 150))
    P.rect(ux - 0.09, uy - 0.04, 0.17, 0.012, (150, 146, 130))
    for k in range(20):
        x, y = rnd(), rnd()
        if ((x - ix) ** 2 + (y - iy) ** 2) < 0.02 or ((x - ux) ** 2 + (y - uy) ** 2) < 0.02:
            continue
        _tree(P, x, y, 0.025, (96, 126, 84))
    return P


def scene_site_ruin():
    frame = (0, 1, 4, 3)
    g = _grid(frame)
    P = Paint(1080, 540)
    _state[0] = 20261114
    P.paper((120, 116, 104), (60, 58, 52))
    for k in range(10):                                 # 地砖
        P.rect(k * 0.1, 0, 0.003, 1.0, (50, 48, 42), 0.7)
    for k in range(5):
        P.rect(0, k * 0.2, 1.0, 0.004, (50, 48, 42), 0.7)
    gx, gy = g(1, 2)
    P.rect(gx - 0.12, gy - 0.30, 0.03, 0.40, (150, 146, 132))
    P.rect(gx - 0.12, gy - 0.32, 0.12, 0.04, (150, 146, 132))
    P.rect(gx - 0.03, gy - 0.30, 0.03, 0.18, (150, 146, 132))      # 断裂的门柱
    hx, hy = g(3, 2)
    for k in range(3):
        P.circle(hx - 0.10 + k * 0.10, hy - 0.26, 0.025, (160, 156, 140))
        P.rect(hx - 0.112 + k * 0.10, hy - 0.26, 0.024, 0.12 + 0.06 * (k % 2), (160, 156, 140))
    for k in range(25):                                 # 碎石
        P.circle(rnd(), rnd(), 0.004 + rnd() * 0.006, (90, 86, 76))
    return P


SCENES = [
    ("scene_map_fog_coast_1080.png", scene_map_fog_coast),
    ("scene_site_lighthouse_1080.png", scene_site_lighthouse),
    ("scene_map_wilds_1080.png", scene_map_wilds),
    ("scene_site_ruin_1080.png", scene_site_ruin),
]


# ---------------------------------------------------------------- 起步包主屏插画（tech/07 §5 theme.home_art 示例）
# 十字路口夜景：热点与 home_scroll.gd HOTSPOTS 归一化矩形对齐——
# 瞭望塔(入口) / 客栈与货摊(背包) / 营火(角色) / 告示板(事件) / 箱子与书堆(历史)。

HW, HH = 720, 1280   # 交付尺寸（竖屏 9:16）
HS = 2               # 2x 超采样


class Paint:
    def __init__(self, ow=HW, oh=HH):
        self.ow, self.oh = ow, oh
        self.w, self.h = ow * HS, oh * HS
        self.px = bytearray(self.w * self.h * 3)

    def _blend(self, o, col, a):
        px = self.px
        px[o] = int(px[o] * (1 - a) + col[0] * a)
        px[o + 1] = int(px[o + 1] * (1 - a) + col[1] * a)
        px[o + 2] = int(px[o + 2] * (1 - a) + col[2] * a)

    def vgrad(self, y0, y1, c0, c1):
        for y in range(int(y0 * self.h), int(y1 * self.h)):
            t = (y / self.h - y0) / max(1e-6, (y1 - y0))
            col = bytes(int(c0[i] + (c1[i] - c0[i]) * t) for i in range(3))
            row = col * self.w
            self.px[y * self.w * 3:(y + 1) * self.w * 3] = row

    def poly(self, pts, col, a=1.0):
        p = [(x * self.w, y * self.h) for x, y in pts]
        ys = [q[1] for q in p]
        n = len(p)
        for y in range(max(0, int(min(ys))), min(self.h, int(max(ys)) + 1)):
            yc = y + 0.5
            xs = []
            for i in range(n):
                ax, ay = p[i]
                bx, by = p[(i + 1) % n]
                if (ay <= yc < by) or (by <= yc < ay):
                    xs.append(ax + (yc - ay) * (bx - ax) / (by - ay))
            xs.sort()
            for k in range(0, len(xs) - 1, 2):
                for x in range(max(0, int(xs[k])), min(self.w, int(xs[k + 1]) + 1)):
                    self._blend((y * self.w + x) * 3, col, a)

    def rect(self, x, y, w, h, col, a=1.0):
        self.poly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], col, a)

    def circle(self, cx, cy, r, col, a=1.0, soft=False):
        R = r * self.w
        X, Y = cx * self.w, cy * self.h
        for y in range(max(0, int(Y - R)), min(self.h, int(Y + R) + 1)):
            for x in range(max(0, int(X - R)), min(self.w, int(X + R) + 1)):
                d = ((x + 0.5 - X) ** 2 + (y + 0.5 - Y) ** 2) ** 0.5
                if d <= R:
                    aa = a * (1.0 - d / R) ** 2 if soft else a
                    self._blend((y * self.w + x) * 3, col, aa)

    def blob(self, cx, cy, rx, ry, col, a=1.0):
        """柔边椭圆（雾团 / 水洼）：中心 a，边缘 0。"""
        X, Y, RX, RY = cx * self.w, cy * self.h, rx * self.w, ry * self.h
        for y in range(max(0, int(Y - RY)), min(self.h, int(Y + RY) + 1)):
            for x in range(max(0, int(X - RX)), min(self.w, int(X + RX) + 1)):
                d = ((x + 0.5 - X) / RX) ** 2 + ((y + 0.5 - Y) / RY) ** 2
                if d < 1.0:
                    self._blend((y * self.w + x) * 3, col, a * (1.0 - d))

    def paper(self, light, dark):
        """旧纸底：纵向渐变 + 颗粒 + 四周暗角（地图 "摊在桌上" 的边）。"""
        for y in range(self.h):
            ty = y / (self.h - 1)
            for x in range(self.w):
                tx = x / (self.w - 1)
                edge = min(tx, 1 - tx, ty, 1 - ty)
                k = 1.0 - min(1.0, edge / 0.08) if edge < 0.08 else 0.0
                n = (rnd() - 0.5) * 4.0
                o = (y * self.w + x) * 3
                for i in range(3):
                    base = light[i] + (dark[i] - light[i]) * (0.35 * ty + 0.65 * k)
                    self.px[o + i] = max(0, min(255, int(base + n)))

    def line(self, pts, r, col, a=1.0):
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            n = max(2, int(((bx - ax) * self.w) ** 2 + ((by - ay) * self.h) ** 2) ** 0.5 // max(1, r * self.w * 0.7))
            n = max(2, int(n))
            for i in range(n + 1):
                t = i / n
                self.circle(ax + (bx - ax) * t, ay + (by - ay) * t, r, col, a)

    def save(self, path):
        out = bytearray()
        for y in range(self.oh):
            out.append(0)
            for x in range(self.ow):
                r = g = b = 0
                for yy in range(y * HS, y * HS + HS):
                    o = (yy * self.w + x * HS) * 3
                    for k in range(HS):
                        r += self.px[o + k * 3]
                        g += self.px[o + k * 3 + 1]
                        b += self.px[o + k * 3 + 2]
                n = HS * HS
                out += bytes((r // n, g // n, b // n, 255))
        write_png(path, self.ow, self.oh, bytes(out))


def home_kit():
    P = Paint()
    NIGHT0, NIGHT1 = (10, 18, 16), (28, 44, 38)
    LEAF = (143, 199, 122)          # 起步包强调色 #8fc77a
    FIRE = (240, 150, 60)
    LAMP = (250, 210, 120)
    DARK = (8, 12, 10)
    WOOD = (60, 44, 30)
    P.vgrad(0.0, 0.56, NIGHT0, NIGHT1)                 # 夜空
    P.vgrad(0.56, 1.0, (20, 30, 22), (12, 18, 14))     # 地面
    _state[0] = 20261110
    for _ in range(60):                                # 星
        P.circle(rnd(), rnd() * 0.42, 0.0016 + rnd() * 0.002, (220, 230, 210), 0.5 + 0.5 * rnd())
    P.circle(0.80, 0.14, 0.11, (200, 230, 190), 0.25, soft=True)   # 月晕
    P.circle(0.80, 0.14, 0.045, (226, 236, 214))                   # 月
    hills = [(x / 40.0, 0.46 + 0.04 * _m.sin(x / 40.0 * 7.0) + 0.02 * _m.sin(x / 40.0 * 17.0)) for x in range(41)]
    P.poly(hills + [(1.0, 0.60), (0.0, 0.60)], (18, 30, 24))       # 远山
    hills2 = [(x / 40.0, 0.53 + 0.025 * _m.sin(x / 40.0 * 11.0 + 1.0)) for x in range(41)]
    P.poly(hills2 + [(1.0, 0.62), (0.0, 0.62)], (14, 22, 18))
    for k in range(9):                                 # 松林剪影
        x = 0.22 + k * 0.035
        if 0.47 < x < 0.78:
            continue
        P.poly([(x - 0.025, 0.58), (x, 0.47 - 0.02 * (k % 3)), (x + 0.025, 0.58)], DARK)
    # 道路：自下而上收窄至地平线
    P.poly([(0.40, 1.0), (0.78, 1.0), (0.62, 0.70), (0.56, 0.58), (0.53, 0.58), (0.52, 0.70)], (46, 52, 40))
    P.poly([(0.0, 0.80), (0.0, 0.86), (0.45, 0.72), (0.52, 0.70), (0.52, 0.68)], (40, 46, 36))  # 岔路
    # 瞭望塔（入口热点 0.06~0.21 × 0.10~0.52）
    P.poly([(0.08, 0.52), (0.105, 0.18), (0.165, 0.18), (0.19, 0.52)], DARK)
    P.poly([(0.07, 0.19), (0.135, 0.10), (0.20, 0.19)], DARK)
    for fy in (0.24, 0.33, 0.42):
        P.rect(0.128, fy, 0.016, 0.03, LAMP)
        P.circle(0.136, fy + 0.015, 0.04, LAMP, 0.18, soft=True)
    P.poly([(0.135, 0.10), (0.135, 0.06), (0.17, 0.075), (0.135, 0.09)], LEAF)   # 塔旗
    # 客栈与货摊（背包热点 0.50~0.76 × 0.48~0.66）
    P.rect(0.53, 0.50, 0.21, 0.13, (30, 26, 22))
    P.poly([(0.51, 0.51), (0.635, 0.43), (0.76, 0.51)], DARK)
    for wx in (0.56, 0.61, 0.67):
        P.rect(wx, 0.535, 0.035, 0.03, LAMP)
        P.circle(wx + 0.017, 0.55, 0.045, LAMP, 0.15, soft=True)
    P.rect(0.625, 0.585, 0.03, 0.045, (20, 16, 12))   # 门
    P.poly([(0.50, 0.615), (0.56, 0.595), (0.56, 0.605), (0.50, 0.625)], LEAF)   # 货摊遮檐
    P.poly([(0.70, 0.595), (0.77, 0.615), (0.77, 0.625), (0.70, 0.605)], LEAF)
    P.rect(0.505, 0.625, 0.05, 0.03, WOOD)
    P.rect(0.715, 0.625, 0.05, 0.03, WOOD)
    # 营火（角色热点 0.28~0.46 × 0.62~0.86）
    P.circle(0.37, 0.76, 0.16, FIRE, 0.22, soft=True)
    P.poly([(0.31, 0.79), (0.43, 0.76), (0.43, 0.775), (0.31, 0.805)], WOOD)
    P.poly([(0.31, 0.76), (0.43, 0.79), (0.43, 0.805), (0.31, 0.775)], WOOD)
    P.poly([(0.335, 0.775), (0.37, 0.68), (0.405, 0.775)], FIRE)
    P.poly([(0.35, 0.775), (0.37, 0.72), (0.39, 0.775)], LAMP)
    for sx, sy in ((0.30, 0.74), (0.44, 0.74)):         # 围坐剪影
        P.circle(sx, sy - 0.035, 0.022, DARK)
        P.poly([(sx - 0.03, sy + 0.04), (sx - 0.02, sy - 0.015), (sx + 0.02, sy - 0.015), (sx + 0.03, sy + 0.04)], DARK)
    # 告示板（事件热点 0.78~0.96 × 0.64~0.90）
    P.rect(0.80, 0.70, 0.012, 0.18, WOOD)
    P.rect(0.93, 0.70, 0.012, 0.18, WOOD)
    P.rect(0.79, 0.67, 0.165, 0.12, (70, 52, 34))
    for k, (nx, ny) in enumerate(((0.80, 0.685), (0.855, 0.68), (0.905, 0.69), (0.825, 0.735), (0.89, 0.73))):
        P.rect(nx, ny, 0.04, 0.04, (220, 214, 190) if k % 2 == 0 else (200, 220, 190))
    P.circle(0.875, 0.665, 0.008, LEAF)
    # 箱子与书堆（历史热点 0.04~0.24 × 0.72~0.96）
    P.rect(0.06, 0.84, 0.12, 0.08, WOOD)
    P.rect(0.06, 0.835, 0.12, 0.02, (90, 66, 40))
    P.rect(0.112, 0.865, 0.016, 0.02, LAMP)
    for k in range(4):
        P.rect(0.15 + 0.004 * k, 0.81 - k * 0.022, 0.08 - 0.008 * k, 0.02, ((140, 60, 50), (60, 90, 120), (150, 130, 70), (80, 110, 70))[k])
    P.circle(0.13, 0.86, 0.12, LAMP, 0.08, soft=True)
    return P


def main():
    import sys
    if "--home" in sys.argv:
        home_kit().save(os.path.normpath(os.path.join(HERE, "..", "kit", "_game", "home_art.png")))
        return
    if "--scenes" in sys.argv:
        for name, fn in SCENES:
            fn().save(os.path.join(ART, "scenes", name))
        return
    if "--icons" in sys.argv:
        todo = ASSETS_ICONS
    else:
        todo = ASSETS_P64 if "--new" in sys.argv else ASSETS + ASSETS_P64 + ASSETS_ICONS
    for sub, name, fn in todo:
        _state[0] = 20261109  # 每张图独立同种子起点：增删资产互不影响
        fn().save(os.path.join(ART, sub, name))
    print("完成：%d 个资产（tech/05 §7 清单）" % len(todo))


if __name__ == "__main__":
    main()
