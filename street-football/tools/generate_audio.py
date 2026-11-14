"""Generates all Street Football sounds and the menu music as WAV files (original, synthesized).

Run from the street-football folder:   python3 tools/generate_audio.py
Needs Python 3 and numpy. Writes assets/audio/*.wav (22050 Hz, mono, 16-bit).
Everything here is made from scratch (sine waves, noise, envelopes): no samples, no licenses.
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(5)


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def env_exp(seconds, decay):
    return np.exp(-t_axis(seconds) / decay)


def sweep(seconds, f0, f1):
    t = t_axis(seconds)
    freq = f0 * (f1 / f0) ** (t / seconds)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def noise(seconds):
    return rng.uniform(-1.0, 1.0, int(seconds * RATE))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, low, high):
    return lowpass(highpass(x, low), high)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def fade_edges(x, ms=4):
    n = max(1, int(RATE * ms / 1000))
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def save(name, x, peak=0.9):
    x = fade_edges(np.asarray(x, dtype=float))
    m = np.max(np.abs(x)) or 1.0
    x = np.tanh(x / m * 1.2) / np.tanh(1.2) * peak
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f"{name}.wav  {len(data) / RATE:.2f} s")


# --- Effects -----------------------------------------------------------------------------------

def kick(seconds, f0, f1, click):
    body = sweep(seconds, f0, f1) * env_exp(seconds, seconds / 3.5)
    snap = highpass(noise(0.02), 1500) * env_exp(0.02, 0.004) * click
    return mix(body, snap)


def metallic(freqs, seconds, decays):
    t = t_axis(seconds)
    return sum(np.sin(2 * np.pi * f * t) * np.exp(-t / d) for f, d in zip(freqs, decays))


def whistle(seconds):
    t = t_axis(seconds)
    trill = 0.55 + 0.45 * np.sin(2 * np.pi * 28 * t)
    tone = np.sin(2 * np.pi * (2750 + 40 * np.sin(2 * np.pi * 28 * t)) * t) * trill
    breath = bandpass(noise(seconds), 2000, 4000) * 0.15
    envelope = np.minimum(1, t / 0.02) * np.minimum(1, (seconds - t) / 0.05)
    return (tone + breath) * envelope


def silence(seconds):
    return np.zeros(int(seconds * RATE))


def effects():
    save("kick_soft", kick(0.09, 170, 70, 0.35), 0.6)
    save("kick_hard", kick(0.16, 220, 55, 0.8), 0.95)
    save("bounce", sweep(0.07, 130, 80) * env_exp(0.07, 0.02), 0.45)
    rattle = bandpass(noise(0.35), 1800, 4200) * env_exp(0.35, 0.08) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 35 * t_axis(0.35))))
    save("wall", mix(sweep(0.14, 110, 60) * env_exp(0.14, 0.04), rattle * 0.7), 0.7)
    save("post", mix(metallic([950, 1430, 2380, 3170], 0.9, [0.35, 0.25, 0.15, 0.1]),
                     highpass(noise(0.01), 3000) * 0.5), 0.6)
    swish = lowpass(noise(0.4), 2500)
    swish_env = np.minimum(1, t_axis(0.4) / 0.03) * env_exp(0.4, 0.12)
    save("net", swish * swish_env, 0.4)
    save("whistle_short", whistle(0.35), 0.5)
    save("whistle_end", np.concatenate([whistle(0.22), silence(0.12), whistle(0.22), silence(0.12), whistle(0.8)]), 0.5)
    t = t_axis(1.1)
    pitch_drop = 1 + 0.06 * np.exp(-t / 0.05)
    horn = sum(2 * ((f * pitch_drop * t) % 1) - 1 for f in (330, 415, 494))
    horn = lowpass(horn, 2200) * np.minimum(1, t / 0.02) * np.minimum(1, (1.1 - t) / 0.15)
    save("goal_horn", horn, 0.55)
    save("tackle", mix(bandpass(noise(0.16), 400, 2000) * env_exp(0.16, 0.05),
                       sweep(0.1, 120, 70) * env_exp(0.1, 0.03) * 0.6), 0.55)
    save("save", mix(highpass(noise(0.05), 800) * env_exp(0.05, 0.012), sweep(0.09, 160, 90) * env_exp(0.09, 0.03)), 0.6)
    save("ui_click", np.sin(2 * np.pi * 1900 * t_axis(0.03)) * env_exp(0.03, 0.006), 0.35)


# --- Music: 8-bar street beat, 90 BPM, A minor (Am Am F G) ------------------------------------

BPM = 90
BEAT = 60 / BPM


def music():
    bars = 8
    total = int(bars * 4 * BEAT * RATE)
    out = np.zeros(total)

    def put(sound, beat_pos, gain=1.0):
        start = int(beat_pos * BEAT * RATE)
        end = min(total, start + len(sound))
        out[start:end] += sound[: end - start] * gain

    drum_kick = sweep(0.25, 120, 45) * env_exp(0.25, 0.08)
    snare = mix(bandpass(noise(0.2), 700, 5000) * env_exp(0.2, 0.05), np.sin(2 * np.pi * 190 * t_axis(0.12)) * env_exp(0.12, 0.03) * 0.6)
    hat = highpass(noise(0.05), 6000) * env_exp(0.05, 0.012)
    open_hat = highpass(noise(0.25), 5000) * env_exp(0.25, 0.08)
    roots = [55.0, 55.0, 43.65, 49.0]
    chords = [[220.0, 261.63, 329.63], [220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66]]
    for bar in range(bars):
        b = bar * 4
        for k in (0, 2.5 if bar % 2 else 2, 3.5 if bar % 4 == 3 else None):
            if k is not None:
                put(drum_kick, b + k, 0.9)
        for s in (1, 3):
            put(snare, b + s, 0.55)
        for h in range(8):
            put(hat, b + h * 0.5, 0.18 if h % 2 else 0.25)
        if bar % 4 == 3:
            put(open_hat, b + 3.5, 0.2)
        root = roots[bar % 4]
        bass_t = t_axis(BEAT * 1.9)
        bass = np.tanh(2.2 * np.sin(2 * np.pi * root * bass_t)) * np.minimum(1, bass_t / 0.01) * np.exp(-bass_t / 0.9)
        put(bass, b, 0.5)
        put(bass, b + 2, 0.45)
        stab_t = t_axis(0.18)
        stab = sum(lowpass(2 * ((f * stab_t) % 1) - 1, 1800) for f in chords[bar % 4]) * env_exp(0.18, 0.06)
        for s in (1.5, 3.5):
            put(stab, b + s, 0.12)
    save("music_loop", out, 0.8)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    effects()
    music()
