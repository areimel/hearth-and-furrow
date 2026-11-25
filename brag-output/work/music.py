"""Synthesised launch-video soundtrack: 90 BPM, D major, 21.333 s, 48 kHz stereo.

Run: uv run --with numpy python -I music.py   (writes music.wav next to this file)

Everything is generated from scratch (no samples). Layout, by integer sample:
beat = 32000, bar = 128000, eighth = 16000. Video frame f sits at sample f * 1600.
"""
import os
import wave

import numpy as np

SR = 48000
N = 1_024_000
BEAT = 32000
BAR = 4 * BEAT
EIGHTH = BEAT // 2
FRAME = 1600  # samples per 30 fps video frame
HERE = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(530)


# ---------------------------------------------------------------- utilities
def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def fft_filter(x, lo=None, hi=None, order=2):
    """Zero-phase smooth band filter (Butterworth-shaped magnitude)."""
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    h = np.ones_like(f)
    if hi:
        h = h / np.sqrt(1 + (f / hi) ** (2 * order))
    if lo:
        h = h / np.sqrt(1 + (lo / np.maximum(f, 1e-9)) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(x) * h, len(x))


def ramp(n):
    """Smooth 0 -> 1 ramp of n samples (raised cosine)."""
    return 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, max(n, 2)))


def declick(x, a=96, r=96):
    x = x.copy()
    a, r = min(a, len(x) // 2), min(r, len(x) // 2)
    x[:a] *= ramp(a)
    x[len(x) - r:] *= ramp(r)[::-1]
    return x


def add(buf, sig, start, pan=0.0, gain=1.0):
    """Mix a mono signal into the stereo buffer (2, N) with constant-power pan."""
    start = int(start)
    end = min(N, start + len(sig))
    if end <= start:
        return
    s = sig[: end - start] * gain
    ang = (pan + 1) * np.pi / 4
    buf[0, start:end] += s * np.cos(ang)
    buf[1, start:end] += s * np.sin(ang)


# Pre-filtered noise banks so per-note noise is a cheap slice.
NOISE_BREATH = fft_filter(rng.normal(size=N), 1500, 5500)
NOISE_BREATH /= NOISE_BREATH.std()
NOISE_SKIN = fft_filter(rng.normal(size=N), 500, 3200)
NOISE_SKIN /= NOISE_SKIN.std()


def noise_slice(bank, n):
    off = int(rng.integers(0, N - n - 1))
    return bank[off: off + n]


# ---------------------------------------------------------------- instruments
def pluck(freq, dur, vel=0.5, t60=1.4):
    """Karplus-Strong lute string: warm (pre-smoothed noise burst), damped loop."""
    p = max(int(round(SR / freq - 0.5)), 4)
    n = int(dur * SR)
    g = 10 ** (-3.0 * p / (SR * t60))
    y = np.zeros(n + 2 * p + 4)
    burst = rng.uniform(-1, 1, p + 1)
    for _ in range(3):  # soften the pluck
        burst = np.convolve(burst, [0.25, 0.5, 0.25], mode="same")
    burst -= burst.mean()
    y[: p + 1] = burst / (np.abs(burst).max() + 1e-9)
    for s in range(p + 1, n, p):
        e = min(s + p, n)
        y[s:e] = g * 0.5 * (y[s - p: e - p] + y[s - p - 1: e - p - 1])
    y = y[:n] * vel
    return declick(y, a=48, r=int(0.15 * n))


def strum(buf, start, notes, vel, pan=-0.3, up=False, dur=1.0, t60=1.3, gap=380):
    """Roll a chord across strings (downstroke low->high, upstroke reversed)."""
    order = notes[::-1] if up else notes
    for i, m in enumerate(order):
        w = 1.0 - 0.08 * i if not up else 0.8 + 0.06 * i
        add(buf, pluck(mtof(m), dur, vel * w, t60), start + i * gap, pan)


def bass_note(freq, dur=0.5, vel=0.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(4 * np.pi * freq * t)
    env = np.exp(-t / 0.28)
    env[: int(0.008 * SR)] *= ramp(int(0.008 * SR))
    return declick(y * env * vel, a=8, r=int(0.1 * n))


def recorder(freq, dur, vel=0.5, release=0.06):
    """Recorder/flute: sine + weak harmonics, breath noise, late vibrato."""
    n_body = int(dur * SR)
    n = n_body + int(release * SR)
    t = np.arange(n) / SR
    vib_depth = 0.004 * np.clip((t - 0.12) / 0.25, 0, 1)
    f = freq * (1 + vib_depth * np.sin(2 * np.pi * 5.3 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    breath = noise_slice(NOISE_BREATH, n) * (0.025 + 0.10 * np.exp(-t / 0.05))
    env = np.ones(n)
    a = int(0.03 * SR)
    env[:a] = ramp(a)
    env[n_body:] = ramp(n - n_body)[::-1] if n > n_body else env[n_body:]
    env *= 1 - 0.12 * np.clip(t / max(dur, 0.1), 0, 1)  # gentle decay across the note
    return (tone * 0.9 + breath) * env * vel


def thump(vel=0.6):
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    f = 62 + 60 * np.exp(-t / 0.025)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.09)
    skin = noise_slice(NOISE_SKIN, n) * np.exp(-t / 0.018) * 0.25
    return declick((body + skin) * vel, a=24, r=400)


def tek(vel=0.3):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    skin = noise_slice(NOISE_SKIN, n) * np.exp(-t / 0.022)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.04) * 0.5
    return declick((skin * 0.5 + tone) * vel, a=24, r=300)


def tock(freq=880.0, vel=0.3):
    """Soft wooden block: pitched sine + inexact overtone, very short."""
    n = int(0.14 * SR)
    t = np.arange(n) / SR
    y = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.035)
    y += 0.3 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / 0.015)
    return declick(y * vel, a=24, r=400)


def whoosh(pre=24000, tail=6000, vel=0.1):
    """Swell into a cut: band noise that brightens and peaks on the cut sample."""
    n = pre + tail
    out = []
    for _ in range(2):  # decorrelated L/R
        w = rng.normal(size=n)
        lo, hi = fft_filter(w, 250, 1200), fft_filter(w, 1200, 4800)
        x = np.concatenate([np.linspace(0, 1, pre) ** 1.0, np.zeros(tail)])
        sig = lo * (1 - x) + hi * x
        env = np.concatenate([ramp(pre) ** 2, np.exp(-np.arange(tail) / 1800.0)])
        out.append(declick(sig * env / (sig.std() + 1e-9) * vel, a=64, r=64))
    return out


# ---------------------------------------------------------------- storm (bar 1)
def storm_stem():
    """Rain bed, minor drone and distant thunder; hard-gated before sample BAR."""
    n = BAR
    t = np.arange(n) / SR
    rain = fft_filter(rng.normal(size=n), 450, 4200) + 0.8 * fft_filter(rng.normal(size=n), None, 1300)
    wob = fft_filter(rng.normal(size=n), None, 2.5, order=2)
    rain = rain * (1 + 0.18 * wob / wob.std())
    rain *= 0.075 / rain.std()
    drone = np.zeros(n)
    for f, a in [(73.42, 0.5), (110.0, 0.28), (146.83, 0.22), (174.61, 0.16), (293.66, 0.05)]:
        for det in (-0.3, 0.3):  # slow beating = unease
            drone += a * (np.sin(2 * np.pi * (f + det) * t) + 0.25 * np.sin(4 * np.pi * (f + det) * t))
    drone *= 1 + 0.12 * np.sin(2 * np.pi * 0.19 * t)
    drone *= 0.085
    drone[: int(0.5 * SR)] *= ramp(int(0.5 * SR))
    thunder = np.zeros(n)
    for start, amp, length in [(56000, 1.0, 70000), (84000, 0.45, 40000)]:
        m = length
        tt = np.arange(m) / SR
        r = fft_filter(rng.normal(size=m), 25, 130, order=3)
        mod = fft_filter(rng.normal(size=m), None, 6)
        r *= 1 + 0.5 * mod / mod.std()
        r *= (1 - np.exp(-tt / 0.2)) * np.exp(-tt / 0.75)
        thunder[start: start + m] += r / r.std() * 0.09 * amp
    stem = rain + drone + thunder
    stem[:96] *= ramp(96)
    gate = 240  # 5 ms hard stop, ends exactly at BAR
    stem[n - gate:] *= ramp(gate)[::-1]
    full = np.zeros(N)
    full[:n] = stem
    return full, rain


# ---------------------------------------------------------------- score
CHORDS = {  # lute voicings (midi)
    "D": [57, 62, 66, 69],
    "G": [55, 59, 62, 67],
    "A": [57, 61, 64, 69],
}
BASS = {"D": (38, 45), "G": (43, 50), "A": (45, 52)}  # root, fifth
# chord for beats 1-2 and beats 3-4 of each bar (index = bar number, 0-based)
PROG = {1: ("D", "A"), 2: ("D", "D"), 3: ("G", "A"), 4: ("D", "D"),
        5: ("G", "A"), 6: ("G", "A")}
# melody: (bar, eighth slot, midi, length in eighths)
MELODY = (
    # phrase A (bars 3-4)
    [(2, 0, 74, 1), (2, 1, 78, 1), (2, 2, 81, 2), (2, 4, 78, 1), (2, 5, 81, 1), (2, 6, 83, 2),
     (3, 0, 81, 2), (3, 2, 79, 1), (3, 3, 78, 1), (3, 4, 76, 2), (3, 6, 73, 1), (3, 7, 76, 1)]
    # phrase A' (bars 5-6), varied ending
    + [(4, 0, 74, 1), (4, 1, 78, 1), (4, 2, 81, 2), (4, 4, 83, 1), (4, 5, 81, 1), (4, 6, 78, 2),
       (5, 0, 79, 2), (5, 2, 78, 1), (5, 3, 76, 1), (5, 4, 73, 2), (5, 6, 76, 1), (5, 7, 81, 1)]
    # answer (bar 7) leaning into the cadence
    + [(6, 0, 83, 2), (6, 2, 81, 1), (6, 3, 79, 1), (6, 4, 81, 2), (6, 6, 76, 1), (6, 7, 73, 1)]
)
STRUM_SLOTS = [(0, False, 0.5), (2, False, 0.28), (3, True, 0.24), (4, False, 0.42), (6, False, 0.26), (7, True, 0.22)]
DRUM_SLOTS = [(0, "thump", 0.8), (2, "tek", 0.5), (3, "tek", 0.3), (4, "thump", 0.55), (6, "tek", 0.45)]
WHOOSH_FRAMES = [160, 240, 360, 440, 480, 520, 560]
TOCK_FRAMES = [260, 280, 300, 320]


def chord_at(bar, slot):
    return PROG[bar][0 if slot < 4 else 1]


def build():
    lute = np.zeros((2, N))
    reco = np.zeros((2, N))
    drum = np.zeros((2, N))
    bass = np.zeros((2, N))
    fx = np.zeros((2, N))

    # bar 2: the turn. Soft "ta-da" chord, then jig strum from bar 2 through bar 7
    strum(lute, BAR, CHORDS["D"] + [74], 0.55, dur=1.6, t60=1.6, gap=300)
    for bar in range(1, 7):
        for slot, up, vel in STRUM_SLOTS:
            if bar == 1 and slot == 0:
                continue  # ta-da already played
            start = bar * BAR + slot * EIGHTH
            strum(lute, start, CHORDS[chord_at(bar, slot)], vel, up=up, dur=0.9, t60=1.0, gap=330)
        for slot in (0, 3, 4, 6):
            ch = chord_at(bar, slot)
            root, fifth = BASS[ch]
            m = fifth if slot in (3, 6) else root
            add(bass, bass_note(mtof(m), 0.5, 0.5 if slot in (0, 4) else 0.32), bar * BAR + slot * EIGHTH, 0.0)

    # drums from bar 2 (lighter there), melody bars 3-7
    for bar in range(1, 7):  # bar 2 gets a lighter pattern so the turn isn't thin
        for slot, kind, vel in DRUM_SLOTS:
            vel = vel * (0.65 if bar == 1 else 1.0)
            sig = thump(vel) if kind == "thump" else tek(vel * 0.6)
            add(drum, sig, bar * BAR + slot * EIGHTH, 0.05)
        if bar == 6:
            add(drum, tek(0.2), bar * BAR + 7 * EIGHTH, 0.05)
    for bar, slot, midi, length in MELODY:
        dur = length * EIGHTH / SR * 0.93
        add(reco, recorder(mtof(midi), dur, 0.5), bar * BAR + slot * EIGHTH, 0.3)

    # bar 8: resolution on frame 560
    s8 = 7 * BAR
    strum(lute, s8, [50, 57, 62, 66, 69], 0.6, dur=2.6, t60=2.2, gap=420)
    add(bass, bass_note(mtof(38), 1.6, 0.55), s8, 0.0)
    add(drum, thump(0.5), s8, 0.05)
    add(reco, recorder(mtof(74), 2.2, 0.5, release=0.9), s8, 0.3)

    # woody tocks on the beat, scene 4
    for fr in TOCK_FRAMES:
        add(fx, tock(880.0, 0.22), fr * FRAME, 0.15)

    # whooshes leading into cuts
    for fr in WHOOSH_FRAMES:
        l, r = whoosh()
        s = fr * FRAME - 24000
        add(fx, l, s, -1.0)
        add(fx, r, s, 1.0)
    return lute, reco, drum, bass, fx


def reverb(x, rt60=0.9, pre=480):
    """Short stereo reverb: convolution with a synthetic decaying-noise IR."""
    n = int(rt60 * 1.3 * SR)
    t = np.arange(n) / SR
    out = np.zeros_like(x)
    nfft = 1 << 21
    for ch in range(2):
        ir = fft_filter(rng.normal(size=n), 150, 4500) * 10 ** (-3 * t / rt60)
        ir[: int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
        ir = np.concatenate([np.zeros(pre), ir])
        ir /= np.sqrt((ir ** 2).sum())
        out[ch] = np.fft.irfft(np.fft.rfft(x[ch], nfft) * np.fft.rfft(ir, nfft), nfft)[:N]
    return out


def main():
    storm, rain = storm_stem()
    lute, reco, drum, bass, fx = build()

    # levels: melody forward, lute and bass support, drums soft, effects beneath
    music = 0.55 * lute + 0.62 * reco + 0.34 * drum
    wet = reverb(music + 0.8 * fx)
    mix = music + 0.9 * bass + fx + 0.22 * wet + 0.7 * storm  # storm ~3 dB down so the turn lands

    # natural ring-out: fade from two beats into the final bar, zero last 0.1 s
    f0, f1 = 7 * BAR + 2 * BEAT, N - 4800
    mix[:, f0:f1] *= (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, f1 - f0))) ** 1.5
    mix[:, f1:] = 0.0

    # soft limiter, then normalise to -3 dBFS (about -14 LUFS for web)
    y = np.tanh(1.3 * mix / np.abs(mix).max())
    y *= 10 ** (-3 / 20) / np.abs(y).max()

    pcm = np.round(y.T * 32767).astype("<i2")
    assert pcm.shape == (N, 2)
    path = os.path.join(HERE, "music.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())

    # ---- verification
    print(f"samples: {pcm.shape[0]}  ({pcm.shape[0] / SR:.4f} s)")
    for b in range(8):
        seg = y[:, b * BAR:(b + 1) * BAR]
        pk = 20 * np.log10(np.abs(seg).max() + 1e-12)
        rms = 20 * np.log10(np.sqrt((seg ** 2).mean()) + 1e-12)
        print(f"bar {b + 1}: peak {pk:6.1f} dBFS  rms {rms:6.1f} dBFS")
    print(f"overall peak {20 * np.log10(np.abs(y).max()):.2f} dBFS")
    print("storm stem max abs from sample 128000:", float(np.abs(storm[BAR:]).max()),
          "| last 240 samples of bar 1:", float(np.abs(storm[BAR - 240:BAR]).max()))
    # rain-band check on the final mix: 6-12 kHz energy just before vs just after the cut
    for name, a, b in [("before cut", BAR - 9600, BAR - 480), ("after cut", BAR + 480, BAR + 9600)]:
        seg = fft_filter(y[0, a:b], 6000, 12000)
        print(f"  {name}: 6-12 kHz rms {20 * np.log10(np.sqrt((seg ** 2).mean()) + 1e-12):.1f} dBFS")
    print("last 4800 samples max abs:", float(np.abs(y[:, -4800:]).max()))
    print("max sample-to-sample jump:", float(np.abs(np.diff(y, axis=1)).max()))


if __name__ == "__main__":
    main()
