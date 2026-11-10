#!/usr/bin/env python3
# 首批美术资产程序化生成（docs/tech/05-美术管线.md §7，14 清单 #7：零外部版权，纯标准库合成，可复跑）。
# 用法：python3 game/tools/gen_art.py [--new | --home]（--new = 只生成 P6.4 第二批；--home = 起步包主屏插画 kit/_game/home_art.png）→  写入 game/assets/art/{units,portraits}/*.png（128px RGBA 透明底）
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


# ---------------------------------------------------------------- 起步包主屏插画（tech/07 §5 theme.home_art 示例）
# 十字路口夜景：热点与 home_scroll.gd HOTSPOTS 归一化矩形对齐——
# 瞭望塔(入口) / 客栈与货摊(背包) / 营火(角色) / 告示板(事件) / 箱子与书堆(历史)。

HW, HH = 720, 1280   # 交付尺寸（竖屏 9:16）
HS = 2               # 2x 超采样


class Paint:
    def __init__(self):
        self.w, self.h = HW * HS, HH * HS
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

    def save(self, path):
        out = bytearray()
        for y in range(HH):
            out.append(0)
            for x in range(HW):
                r = g = b = 0
                for yy in range(y * HS, y * HS + HS):
                    o = (yy * self.w + x * HS) * 3
                    for k in range(HS):
                        r += self.px[o + k * 3]
                        g += self.px[o + k * 3 + 1]
                        b += self.px[o + k * 3 + 2]
                n = HS * HS
                out += bytes((r // n, g // n, b // n, 255))
        write_png(path, HW, HH, bytes(out))


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
    todo = ASSETS_P64 if "--new" in sys.argv else ASSETS + ASSETS_P64
    for sub, name, fn in todo:
        _state[0] = 20261109  # 每张图独立同种子起点：增删资产互不影响
        fn().save(os.path.join(ART, sub, name))
    print("完成：%d 个资产（tech/05 §7 清单）" % len(todo))


if __name__ == "__main__":
    main()
