#!/usr/bin/env python3
# 首批音频资产程序化生成（docs/framework/14 清单 #6：零外部版权，Python 合成，可复跑）。
# 已存在的文件一律跳过（正式音频不被占位覆盖），--force 才覆盖。
# 用法：python3 game/tools/gen_audio.py [--new]（--new = 只生成 P6.4 第二批）→  写入 game/assets/audio/*.wav（44100Hz 16-bit 单声道）
# 循环资产（tide_loop/bgm_camp/bgm_battle）采用频率整数周期量化 + 首尾交叉淡化，循环无接缝。
import math
import os
import random
import struct
import wave

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "audio"))
rng = random.Random(20261109)  # 固定种子：可复跑逐字节一致


def write_wav(name, samples):
    import sys
    if os.path.exists(os.path.join(OUT, name)) and "--force" not in sys.argv:
        print("跳过（已存在，可能是正式音频；--force 覆盖）：%s" % name)
        return
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.89 / peak  # 归一化防削波
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print("生成 %s（%.2fs）" % (path, len(samples) / SR))


def q(freq, dur):
    """频率量化到整数周期 → 循环首尾无相位断点。"""
    return round(freq * dur) / dur


def loop_seam(samples, fade_sec=0.5):
    """尾部交叉淡化到头部：生成时多渲染 fade 段并叠回头部，循环无缝。"""
    f = int(fade_sec * SR)
    n = len(samples) - f
    out = samples[:n]
    for i in range(f):
        t = i / f
        out[i] = out[i] * t + samples[n + i] * (1.0 - t)
    return out


def lowpass(samples, coeff):
    """单极点低通。"""
    y = 0.0
    out = []
    for s in samples:
        y += coeff * (s - y)
        out.append(y)
    return out


# ---------------------------------------------------------------- 环境声

def tide_loop():
    """港口潮声：棕噪声（低频涌）+ 慢 LFO 起伏 + 高频水沫层，9s 循环。"""
    dur = 9.0
    n = int(dur * SR) + int(0.5 * SR)  # 多渲染 0.5s 供首尾交叉
    brown = 0.0
    out = []
    for i in range(n):
        t = i / SR
        white = rng.uniform(-1.0, 1.0)
        brown += 0.02 * (white - brown)  # 漏积分 → 棕噪声（低频涌动感）
        hiss = rng.uniform(-1.0, 1.0)
        # 慢 LFO：9s 整 3 周期（涌浪节奏）+ 2 周期反向（错相位增厚），整数周期保循环
        lfo = 0.55 + 0.30 * math.sin(2 * math.pi * 3 * t / dur) \
            + 0.15 * math.sin(2 * math.pi * 2 * t / dur + 1.3)
        out.append(brown * 2.2 * lfo + hiss * 0.04 * max(0.0, lfo - 0.4))
    out = lowpass(out, 0.35)
    return loop_seam(out)


# ---------------------------------------------------------------- SFX

def dice_roll():
    """骰子滚动：短促颗粒噪声串 ~0.5s（由密到疏，模拟托盘里弹跳）。"""
    dur = 0.5
    n = int(dur * SR)
    out = [0.0] * n
    t = 0.02
    while t < dur - 0.03:
        glen = int(rng.uniform(0.006, 0.014) * SR)
        amp = rng.uniform(0.4, 1.0) * (1.0 - 0.5 * t / dur)
        start = int(t * SR)
        for j in range(glen):
            if start + j >= n:
                break
            env = math.sin(math.pi * j / glen)  # 颗粒包络
            out[start + j] += rng.uniform(-1.0, 1.0) * env * amp
        t += rng.uniform(0.024, 0.042) + 0.02 * t  # 越滚越疏
    return lowpass(out, 0.6)


def dice_land():
    """落定一声：低频顿响 + 起音咔哒。"""
    dur = 0.18
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        thump = math.sin(2 * math.pi * 170 * t) * math.exp(-t * 26.0)
        click = rng.uniform(-1.0, 1.0) * math.exp(-t * 320.0) if t < 0.012 else 0.0
        out.append(thump * 0.9 + click * 0.5)
    return out


def hit():
    """命中钝响：低频衰减正弦 + 短低通噪声。"""
    dur = 0.22
    n = int(dur * SR)
    raw = []
    for i in range(n):
        t = i / SR
        body = math.sin(2 * math.pi * 115 * t) * math.exp(-t * 20.0)
        noise = rng.uniform(-1.0, 1.0) * math.exp(-t * 60.0) if t < 0.05 else 0.0
        raw.append(body + noise * 0.7)
    return lowpass(raw, 0.45)


def crit():
    """暴击亮色：钝响基底（更高基频）+ 金属泛音闪光。"""
    dur = 0.35
    n = int(dur * SR)
    raw = []
    for i in range(n):
        t = i / SR
        body = math.sin(2 * math.pi * 190 * t) * math.exp(-t * 18.0)
        shimmer = (math.sin(2 * math.pi * 880 * t) * 0.5
                   + math.sin(2 * math.pi * 1318.5 * t) * 0.35
                   + math.sin(2 * math.pi * 1760 * t + 0.4) * 0.2) * math.exp(-t * 9.0)
        noise = rng.uniform(-1.0, 1.0) * math.exp(-t * 70.0) if t < 0.04 else 0.0
        raw.append(body * 0.7 + shimmer + noise * 0.5)
    return raw


def heal():
    """治疗：三连上行柔和音（Do-Mi-Sol），慢起音。"""
    dur = 0.6
    n = int(dur * SR)
    notes = [(523.25, 0.0), (659.25, 0.12), (783.99, 0.24)]
    out = []
    for i in range(n):
        t = i / SR
        s = 0.0
        for f, t0 in notes:
            if t >= t0:
                lt = t - t0
                env = min(1.0, lt / 0.03) * math.exp(-lt * 3.5)
                s += math.sin(2 * math.pi * f * lt) * env * 0.6
        out.append(s)
    return out


def page():
    """翻页：扫频低通噪声（纸面摩擦），快起慢收。"""
    dur = 0.28
    n = int(dur * SR)
    y = 0.0
    out = []
    for i in range(n):
        t = i / SR
        frac = t / dur
        coeff = 0.03 + 0.35 * math.sin(math.pi * min(1.0, frac * 1.15))  # 截止先开后合
        y += coeff * (rng.uniform(-1.0, 1.0) - y)
        env = min(1.0, t / 0.02) * (1.0 - frac ** 3)
        out.append(y * env * 1.6)
    return out


def ui_click():
    """UI 点击：极短软木鱼声（中频正弦瞬态 + 轻噪声起音），克制不抢戏。"""
    dur = 0.09
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        body = math.sin(2 * math.pi * 620 * t) * math.exp(-t * 70.0)
        tick = rng.uniform(-1.0, 1.0) * math.exp(-t * 600.0) if t < 0.006 else 0.0
        out.append(body * 0.8 + tick * 0.3)
    return out


# ---------------------------------------------------------------- BGM

def bgm_camp():
    """营地氛围垫：Am(add9) 正弦叠 + 慢包络，30s 循环。"""
    dur = 30.0
    n = int(dur * SR) + int(0.5 * SR)
    # (基频, 振幅, LFO 周期数(整), LFO 相位, 二次谐波量)
    voices = [
        (110.00, 0.50, 2, 0.0, 0.10),   # A2
        (130.81, 0.34, 3, 1.1, 0.08),   # C3
        (164.81, 0.34, 4, 2.2, 0.08),   # E3
        (246.94, 0.20, 5, 0.6, 0.05),   # B3（add9 亮色）
    ]
    out = []
    for i in range(n):
        t = i / SR
        s = 0.0
        for f, amp, cyc, ph, h2 in voices:
            fq = q(f, dur)
            lfo = 0.7 + 0.3 * math.sin(2 * math.pi * cyc * t / dur + ph)
            s += (math.sin(2 * math.pi * fq * t) + h2 * math.sin(4 * math.pi * fq * t)) * amp * lfo
        out.append(s)
    return loop_seam(out)


def bgm_battle():
    """战斗氛围垫：Dm 低音区 + 颤音压迫 + 2Hz 心跳闸口，30s 循环。"""
    dur = 30.0
    n = int(dur * SR) + int(0.5 * SR)
    voices = [
        (73.42, 0.55, 2, 0.0),   # D2
        (87.31, 0.38, 3, 0.9),   # F2
        (110.00, 0.34, 4, 1.7),  # A2
        (130.81, 0.22, 5, 2.6),  # C3
    ]
    out = []
    for i in range(n):
        t = i / SR
        s = 0.0
        for f, amp, cyc, ph in voices:
            fq = q(f, dur)
            lfo = 0.75 + 0.25 * math.sin(2 * math.pi * cyc * t / dur + ph)
            s += math.sin(2 * math.pi * fq * t) * amp * lfo
        trem = 0.7 + 0.3 * math.sin(2 * math.pi * 8 * t / dur)  # 8 整周期颤音
        pulse = (0.5 + 0.5 * math.sin(2 * math.pi * 2 * t)) ** 4  # 2Hz 心跳（60 整周期）
        s = s * trem + math.sin(2 * math.pi * q(55.0, dur) * t) * pulse * 0.35
        out.append(s)
    return loop_seam(out)


# ---------------------------------------------------------------- P6.4 新增（tech/05 §7 第二批；独立种子，不扰动首批逐字节一致）

rng2 = random.Random(20261110)

NOTE = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}


def hz(name):
    """音名 → 频率（A4=440；"D3" / "F#4" / "Bb2"）。"""
    letter, rest = name[0], name[1:]
    semi = NOTE[letter]
    while rest and rest[0] in "#b":
        semi += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((semi + (octave - 4) * 12) / 12.0)


def add_wrapped(buf, start, samples):
    """把一段音符写入循环缓冲：越过末尾的尾音绕回开头 → 天然无缝循环。"""
    n = len(buf)
    for i, v in enumerate(samples):
        buf[(start + i) % n] += v


def pluck(freq, dur, amp=1.0, bright=1.0, decay=3.0):
    """拨弦：谐波叠加 + 高次更快衰减（类竖琴/诗琴）。"""
    n = int(dur * SR)
    out = []
    w = 2 * math.pi * freq / SR
    for i in range(n):
        t = i / SR
        att = min(1.0, t / 0.004)
        s = 0.0
        for k in (1, 2, 3, 4):
            s += math.sin(w * k * i) * math.exp(-t * decay * (1 + (k - 1) * 0.9 * bright)) / k
        out.append(s * att * amp)
    return out


def bell(freq, dur, amp=1.0):
    """铃音：非谐泛音（2.76 / 5.40）+ 长衰减。"""
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        att = min(1.0, t / 0.002)
        s = (math.sin(2 * math.pi * freq * t) * math.exp(-t * 2.2)
             + 0.45 * math.sin(2 * math.pi * freq * 2.76 * t) * math.exp(-t * 4.5)
             + 0.22 * math.sin(2 * math.pi * freq * 5.40 * t) * math.exp(-t * 8.0))
        out.append(s * att * amp)
    return out


def drum(dur=0.35, f0=95.0, amp=1.0):
    """手鼓：下滑基频 + 短噪声皮面。"""
    n = int(dur * SR)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = f0 * (1.0 + 0.6 * math.exp(-t * 30.0))
        ph += 2 * math.pi * f / SR
        body = math.sin(ph) * math.exp(-t * 11.0)
        skin = rng2.uniform(-1.0, 1.0) * math.exp(-t * 90.0)
        out.append((body + skin * 0.25) * amp)
    return out


def pad(buf, dur, chords, amp=0.16, beats_per_chord=None):
    """和弦垫：每段一和弦，正弦+弱二次谐波，段间余弦交叉（在循环内闭合）。"""
    n = len(buf)
    seg = n // len(chords)
    fade = int(1.2 * SR)
    for ci, chord in enumerate(chords):
        start = ci * seg
        length = seg + fade
        freqs = [q(hz(nm), dur) for nm in chord]
        for i in range(length):
            idx = (start + i) % n
            t = idx / SR
            if i < fade:
                env = 0.5 - 0.5 * math.cos(math.pi * i / fade)
            elif i > seg:
                env = 0.5 + 0.5 * math.cos(math.pi * (i - seg) / fade)
            else:
                env = 1.0
            s = 0.0
            for f in freqs:
                s += math.sin(2 * math.pi * f * t) + 0.12 * math.sin(4 * math.pi * f * t)
            buf[idx] += s * env * amp / len(freqs)


def bgm_explore():
    """探索：D 多利亚，拨弦琶音 + 稀疏旋律，84 BPM，8 小节 ≈ 22.9s 循环（Dm–C–G/B–Dm）。"""
    bpm = 84.0
    beat = 60.0 / bpm
    bars = 8
    dur = bars * 4 * beat
    n = int(dur * SR)
    buf = [0.0] * n
    chords = [["D3", "A3", "F4"], ["C3", "G3", "E4"], ["B2", "G3", "D4"], ["D3", "A3", "F4"]]
    pad(buf, dur, chords + chords, amp=0.35)
    arps = [["D4", "A4", "F4", "A4"], ["C4", "G4", "E4", "G4"],
            ["B3", "G4", "D4", "G4"], ["D4", "A4", "F4", "A4"]]
    for bar in range(bars):
        pat = arps[bar % 4]
        for e in range(8):  # 八分音符
            nm = pat[e % 4]
            t0 = (bar * 4 + e * 0.5) * beat
            add_wrapped(buf, int(t0 * SR), pluck(hz(nm), 1.6, amp=0.32 if e % 2 == 0 else 0.22))
    melody = [(1, 0, "A4", 1.5), (1, 2, "C5", 1.0), (2, 0, "B4", 2.0), (3, 0, "A4", 1.0),
              (3, 1, "G4", 1.0), (3, 2, "F4", 2.0), (5, 0, "D5", 1.5), (5, 2, "C5", 1.0),
              (6, 0, "B4", 1.0), (6, 2, "G4", 1.0), (7, 0, "A4", 3.0)]
    for bar, b, nm, ln in melody:
        t0 = (bar * 4 + b) * beat
        add_wrapped(buf, int(t0 * SR), pluck(hz(nm), ln * beat + 1.2, amp=0.5, bright=0.6, decay=1.6))
    return buf


def bgm_map():
    """地图行旅：A 小调五声，手鼓步行律动 + 五声旋律，96 BPM，8 小节 = 20s 循环。"""
    bpm = 96.0
    beat = 60.0 / bpm
    bars = 8
    dur = bars * 4 * beat
    n = int(dur * SR)
    buf = [0.0] * n
    chords = [["A2", "E3", "C4"], ["G2", "D3", "B3"], ["F2", "C3", "A3"], ["E2", "B2", "G#3"]]
    pad(buf, dur, chords + chords, amp=0.28)
    for b in range(bars * 4):  # 步行律动：每拍一鼓，第 1/3 拍重
        t0 = b * beat
        add_wrapped(buf, int(t0 * SR), drum(amp=0.55 if b % 2 == 0 else 0.3))
        if b % 4 == 3:
            add_wrapped(buf, int((t0 + beat * 0.5) * SR), drum(f0=140.0, amp=0.22))
    bass = ["A2", "G2", "F2", "E2"]
    for bar in range(bars):
        for b in (0, 2):
            add_wrapped(buf, int((bar * 4 + b) * beat * SR), pluck(hz(bass[bar % 4]), 1.4, amp=0.45, decay=2.4))
    melody = [(0, 0, "E4", 1), (0, 1, "G4", 1), (0, 2, "A4", 2), (1, 0, "G4", 1), (1, 1, "E4", 1),
              (1, 2, "D4", 2), (2, 0, "C4", 1), (2, 1, "D4", 1), (2, 2, "E4", 1), (2, 3, "G4", 1),
              (3, 0, "E4", 4), (4, 0, "A4", 1), (4, 1, "C5", 1), (4, 2, "D5", 2), (5, 0, "C5", 1),
              (5, 1, "A4", 1), (5, 2, "G4", 2), (6, 0, "E4", 1), (6, 1, "G4", 1), (6, 2, "A4", 2),
              (7, 0, "A4", 3)]
    for bar, b, nm, ln in melody:
        t0 = (bar * 4 + b) * beat
        add_wrapped(buf, int(t0 * SR), pluck(hz(nm), ln * beat + 0.9, amp=0.42, bright=0.8, decay=2.0))
    return buf


def bgm_ending():
    """结局：F 大调温暖终章，慢琶音 + 铃音点缀，66 BPM，8 小节 ≈ 29.1s 循环（F–C/E–Dm–Bb）。"""
    bpm = 66.0
    beat = 60.0 / bpm
    bars = 8
    dur = bars * 4 * beat
    n = int(dur * SR)
    buf = [0.0] * n
    chords = [["F3", "C4", "A4"], ["E3", "C4", "G4"], ["D3", "A3", "F4"], ["Bb2", "F3", "D4"]]
    pad(buf, dur, chords + chords, amp=0.4)
    arps = [["F3", "C4", "A4", "C5"], ["E3", "C4", "G4", "C5"],
            ["D3", "A3", "F4", "A4"], ["Bb2", "F3", "D4", "F4"]]
    for bar in range(bars):
        pat = arps[bar % 4]
        for e in range(4):
            add_wrapped(buf, int((bar * 4 + e) * beat * SR), pluck(hz(pat[e]), 2.6, amp=0.3, decay=1.4))
    for bar, nm in ((0, "C6"), (2, "A5"), (4, "F5"), (6, "D6"), (7, "C6")):
        add_wrapped(buf, int((bar * 4 + 2) * beat * SR), bell(hz(nm), 3.0, amp=0.18))
    return buf


def coin():
    """金币：两声明亮金属叮（非谐泛音），第二声略高。"""
    dur = 0.5
    n = int(dur * SR)
    out = [0.0] * n
    for t0, f in ((0.0, 1975.5), (0.07, 2637.0)):
        b = bell(f, dur - t0, amp=0.6)
        s = int(t0 * SR)
        for i, v in enumerate(b):
            if s + i < n:
                out[s + i] += v
    return out


def door():
    """木门：低沉吱呀（慢扫频锯齿近似 + 低通）+ 落定闷响。"""
    dur = 0.9
    n = int(dur * SR)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = 70.0 + 55.0 * math.sin(math.pi * min(1.0, t / 0.65)) + 8.0 * math.sin(2 * math.pi * 11 * t)
        ph += 2 * math.pi * f / SR
        saw = sum(math.sin(ph * k) / k for k in (1, 2, 3, 4, 5))
        env = min(1.0, t / 0.05) * (1.0 if t < 0.6 else max(0.0, 1.0 - (t - 0.6) / 0.15))
        creak = saw * env * 0.35
        tt = t - 0.68
        thud = math.sin(2 * math.pi * 85 * tt) * math.exp(-tt * 22.0) if tt >= 0 else 0.0
        out.append(creak + thud * 0.9)
    return lowpass(out, 0.25)


def card():
    """翻牌：短促纸面刷声 + 收尾轻弹。"""
    dur = 0.22
    n = int(dur * SR)
    y = 0.0
    out = []
    for i in range(n):
        t = i / SR
        y += 0.5 * (rng2.uniform(-1.0, 1.0) - y)
        swish = y * math.sin(math.pi * min(1.0, t / 0.12)) if t < 0.12 else 0.0
        tt = t - 0.13
        flick = math.sin(2 * math.pi * 900 * tt) * math.exp(-tt * 80.0) if tt >= 0 else 0.0
        out.append(swish * 1.2 + flick * 0.5)
    return out


def link():
    """联络：两音上滑的空灵和声 + 颤动泛光。"""
    dur = 0.8
    n = int(dur * SR)
    out = []
    p1 = p2 = 0.0
    for i in range(n):
        t = i / SR
        glide = min(1.0, t / 0.25)
        f1 = 660.0 * (1.0 + 0.5 * glide)
        f2 = 990.0 * (1.0 + 0.335 * glide)
        p1 += 2 * math.pi * f1 / SR
        p2 += 2 * math.pi * f2 / SR
        env = min(1.0, t / 0.04) * math.exp(-t * 3.2)
        shimmer = 0.75 + 0.25 * math.sin(2 * math.pi * 14 * t)
        out.append((math.sin(p1) + 0.6 * math.sin(p2)) * env * shimmer)
    return out


def throw():
    """投掷：带通噪声呼啸，起伏一次（掠过）。"""
    dur = 0.4
    n = int(dur * SR)
    lo = hi = 0.0
    out = []
    for i in range(n):
        t = i / SR
        x = rng2.uniform(-1.0, 1.0)
        c = 0.05 + 0.25 * math.sin(math.pi * t / dur)
        hi += c * (x - hi)
        lo += 0.02 * (hi - lo)
        env = math.sin(math.pi * t / dur) ** 2
        out.append((hi - lo) * env * 2.4)
    return out


def fade_out(samples, sec=0.04):
    """SFX 尾部线性淡出：截断处不留咔哒。"""
    f = min(len(samples), int(sec * SR))
    n = len(samples)
    for i in range(f):
        samples[n - f + i] *= 1.0 - (i + 1) / f
    return samples


def main_p64():
    write_wav("bgm_explore.wav", bgm_explore())
    write_wav("bgm_map.wav", bgm_map())
    write_wav("bgm_ending.wav", bgm_ending())
    write_wav("coin.wav", fade_out(coin()))
    write_wav("door.wav", fade_out(door()))
    write_wav("card.wav", fade_out(card()))
    write_wav("link.wav", fade_out(link()))
    write_wav("throw.wav", fade_out(throw()))


def main():
    write_wav("tide_loop.wav", tide_loop())
    write_wav("dice_roll.wav", dice_roll())
    write_wav("dice_land.wav", dice_land())
    write_wav("hit.wav", hit())
    write_wav("crit.wav", crit())
    write_wav("heal.wav", heal())
    write_wav("page.wav", page())
    write_wav("ui_click.wav", ui_click())
    write_wav("bgm_camp.wav", bgm_camp())
    write_wav("bgm_battle.wav", bgm_battle())
    main_p64()


if __name__ == "__main__":
    import sys
    if "--new" in sys.argv:
        main_p64()
    else:
        main()
