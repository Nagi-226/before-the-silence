"""gen_sfx.py — 离线合成复古风格音效（22050Hz 单声道 16bit WAV）

用法: py -3 tools/gen_sfx.py
输出: assets/sounds/*.wav（相对本脚本所在目录的上一级）

设计: 方波扫频 + 白噪声，风格对齐 90 年代 FPS 的低保真音效。
日后若换成真录音素材，只需替换同名文件，代码侧不用改。
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")


def write_wav(name, samples):
    path = os.path.join(OUT_DIR, name)
    frames = bytearray()
    peak = max((abs(s) for s in samples), default=1.0) or 1.0
    norm = 0.9 / peak if peak > 0.9 else 1.0
    for s in samples:
        v = int(max(-1.0, min(1.0, s * norm)) * 32767)
        frames += struct.pack("<h", v)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    print("  %-18s %6d 样本 (%.2fs)" % (name, len(samples), len(samples) / RATE))


def tone(freq, dur, wave_kind="square", vol=0.6, f_end=None, fade_tail=0.005):
    """单段音调；freq→f_end 线性扫频，指数衰减包络，尾部线性淡出防爆音。"""
    n = int(dur * RATE)
    out = []
    phase = 0.0
    tail = int(fade_tail * RATE)
    rng = random.Random(int(freq * 1000))
    for i in range(n):
        t = i / n
        f = freq + (f_end - freq) * t if f_end else freq
        phase += 2.0 * math.pi * f / RATE
        if wave_kind == "square":
            v = 1.0 if math.sin(phase) >= 0 else -1.0
        elif wave_kind == "sine":
            v = math.sin(phase)
        elif wave_kind == "noise":
            v = rng.uniform(-1.0, 1.0)
        else:
            raise ValueError(wave_kind)
        env = math.exp(-3.5 * t)
        if i >= n - tail and tail > 0:
            env *= (n - i) / tail
        out.append(v * vol * env)
    return out


def silence(dur):
    return [0.0] * int(dur * RATE)


def mix(*parts):
    total = max(len(p) for p in parts)
    out = [0.0] * total
    for p in parts:
        for i, s in enumerate(p):
            out[i] += s
    return out


def seq(*parts):
    out = []
    for p in parts:
        out += p
    return out


def gen():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("输出目录: %s" % os.path.abspath(OUT_DIR))

    # 武器
    write_wav("Shoot.wav", mix(tone(700, 0.09, "square", 0.7, f_end=120),
                               tone(0, 0.02, "noise", 0.25)))
    write_wav("EnemyShoot.wav", tone(320, 0.12, "square", 0.55, f_end=90))

    # 换弹（咔哒声 = 极短噪声 + 高频方波）
    write_wav("ReloadStart.wav", seq(tone(0, 0.015, "noise", 0.5),
                                     tone(900, 0.03, "square", 0.35, f_end=500)))
    write_wav("ReloadEnd.wav", seq(tone(0, 0.015, "noise", 0.5),
                                   tone(1200, 0.03, "square", 0.4, f_end=800)))

    # 敌人
    write_wav("EnemyHurt.wav", tone(0, 0.08, "noise", 0.5))
    write_wav("EnemyDie.wav", mix(tone(400, 0.30, "square", 0.6, f_end=60),
                                  tone(0, 0.18, "noise", 0.25)))

    # 玩家
    write_wav("PlayerHurt.wav", tone(180, 0.18, "square", 0.7, f_end=70))

    # UI
    write_wav("UIMove.wav", tone(660, 0.06, "sine", 0.45))
    write_wav("UISelect.wav", seq(tone(520, 0.06, "square", 0.4),
                                  tone(780, 0.09, "square", 0.45)))

    # 结算 jingle
    victory = seq(tone(523.25, 0.12, "square", 0.5),
                  tone(659.25, 0.12, "square", 0.5),
                  tone(783.99, 0.12, "square", 0.5),
                  tone(1046.5, 0.30, "square", 0.55))
    write_wav("Victory.wav", victory)
    defeat = seq(tone(392.0, 0.16, "square", 0.5),
                 tone(330.0, 0.16, "square", 0.5),
                 tone(262.0, 0.16, "square", 0.5),
                 tone(196.0, 0.34, "square", 0.55))
    write_wav("Defeat.wav", defeat)

    print("完成: 11 个 WAV")


if __name__ == "__main__":
    gen()
