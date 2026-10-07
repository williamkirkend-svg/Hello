#!/usr/bin/env python3
"""
synth.py -- the shared procedural-audio helpers for the Farm Lasso sound pack.

Every recipe (recipes_game.py, recipes_celebration.py) builds its sound from these: oscillators that take a scalar
or a per-sample frequency array, noise, envelopes, RBJ biquad filters, FFT shaping, a convolution reverb,
Karplus-Strong plucks, mixing with offsets, seamless loops and a registry decorator that build_sfx_pack.py runs.

Conventions
- Sample rate SR = 44100, float32 arrays in [-1, 1]. Mono is a 1-D array; stereo is (2, n).
- Durations are seconds. `t(dur)` gives the time axis.
- A recipe is   @sound("name", variants=3, loop=False, stereo=False, length=.5)
                def name(v, rng): ... return array
  `v` is the variant index (0-based), `rng` a numpy Generator seeded from the name and v (deterministic).
- Recipes return un-normalised audio; the builder trims silent heads, normalises to PEAK, fades the tail and (for
  loops) crossfades the end into the head so the loop has no seam.
"""
import math
import os
import subprocess
import tempfile
import zlib

import numpy as np

SR = 44100
PEAK = 10 ** (-1 / 20)  # -1 dBFS
TAU = 2 * math.pi

REGISTRY = {}


# --------------------------------------------------------------- registry
def snake(name):
    out = []
    for i, c in enumerate(name):
        if c.isupper() and i and (not name[i - 1].isupper() or (i + 1 < len(name) and name[i + 1].islower())):
            out.append("_")
        out.append(c.lower())
    return "".join(out)


def sound(name, variants=1, loop=False, stereo=False, length=None, file=None):
    """Register a recipe. `length` is informative (the cue table), the array decides the real length.
    `file` is the pack file stem (default: snake_case of the name); variants get _1, _2 ... appended."""
    def deco(fn):
        REGISTRY[name] = {"fn": fn, "variants": variants, "loop": loop, "stereo": stereo, "length": length,
                          "name": name, "file": file or snake(name)}
        return fn
    return deco


def rng_for(name, v):
    return np.random.default_rng(zlib.crc32(f"{name}:{v}".encode()) & 0xFFFFFFFF)


# --------------------------------------------------------------- time and oscillators
def t(dur):
    return np.arange(int(round(dur * SR)), dtype=np.float32) / SR


def n_of(dur):
    return int(round(dur * SR))


def _phase(freq, dur):
    """Cumulative phase for a scalar or per-sample frequency."""
    n = n_of(dur)
    if np.isscalar(freq):
        return TAU * freq * np.arange(n, dtype=np.float64) / SR
    f = np.asarray(freq, dtype=np.float64)
    if len(f) != n:
        f = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(f)), f)
    return TAU * np.cumsum(f) / SR


def sine(freq, dur, phase=0.0):
    return np.sin(_phase(freq, dur) + phase).astype(np.float32)


def tri(freq, dur):
    p = (_phase(freq, dur) / TAU) % 1.0
    return (4 * np.abs(p - 0.5) - 1).astype(np.float32)


def saw(freq, dur):
    p = (_phase(freq, dur) / TAU) % 1.0
    return (2 * p - 1).astype(np.float32)


def square(freq, dur, duty=0.5):
    p = (_phase(freq, dur) / TAU) % 1.0
    return np.where(p < duty, 1.0, -1.0).astype(np.float32)


def softsaw(freq, dur, harmonics=12):
    """Band-limited-ish saw: the first `harmonics` partials with 1/k weights."""
    ph = _phase(freq, dur)
    out = np.zeros(len(ph), dtype=np.float64)
    for k in range(1, harmonics + 1):
        out += np.sin(k * ph) / k
    return (out * (2 / math.pi)).astype(np.float32)


def fm(fc, fmod, index, dur, mod_env=None):
    """FM: carrier fc, modulator fmod, index (array or scalar); mod_env scales the index over time."""
    n = n_of(dur)
    idx = index if np.isscalar(index) else np.asarray(index, dtype=np.float64)
    if mod_env is not None:
        idx = idx * np.asarray(mod_env, dtype=np.float64)
    mod = np.sin(_phase(fmod, dur)) * idx
    return np.sin(_phase(fc, dur) + mod).astype(np.float32)


def noise(dur, rng, color="white"):
    n = n_of(dur)
    w = rng.standard_normal(n).astype(np.float32) * 0.3
    if color == "white":
        return w
    if color == "pink":
        # Paul Kellet's economy pink filter
        b0 = b1 = b2 = 0.0
        out = np.empty(n, dtype=np.float32)
        for i in range(n):
            x = w[i]
            b0 = 0.99765 * b0 + x * 0.0990460
            b1 = 0.96300 * b1 + x * 0.2965164
            b2 = 0.57000 * b2 + x * 1.0526913
            out[i] = (b0 + b1 + b2 + x * 0.1848) * 0.2
        return out
    if color == "brown":
        out = np.cumsum(w) / 40.0
        return (out - np.mean(out)).astype(np.float32)
    raise ValueError(color)


# --------------------------------------------------------------- envelopes and curves
def env(points, dur):
    """Piecewise-linear envelope from [(time, value), ...]; times in seconds (clamped to dur)."""
    n = n_of(dur)
    xs = np.array([min(p[0], dur) for p in points], dtype=np.float64) * SR
    ys = np.array([p[1] for p in points], dtype=np.float64)
    return np.interp(np.arange(n), xs, ys).astype(np.float32)


def adsr(dur, a=0.005, d=0.1, s=0.6, r=0.1, hold=None):
    """Attack / decay / sustain / release. The release starts at dur - r (or after `hold` seconds of sustain)."""
    n = n_of(dur)
    a_n, d_n, r_n = n_of(a), n_of(d), n_of(r)
    if hold is not None:
        r_start = min(n, a_n + d_n + n_of(hold))
    else:
        r_start = max(a_n + d_n, n - r_n)
    e = np.zeros(n, dtype=np.float32)
    i = 0
    if a_n:
        e[:a_n] = np.linspace(0, 1, a_n, endpoint=False)
        i = a_n
    if d_n and i < n:
        k = min(d_n, n - i)
        e[i:i + k] = np.linspace(1, s, k, endpoint=False)
        i += k
    if i < r_start:
        e[i:r_start] = s
    if r_start < n:
        e[r_start:] = s * np.linspace(1, 0, n - r_start) ** 1.5
    return e


def decay(dur, tau, start=1.0):
    """Exponential decay from start with time constant tau (s)."""
    return (start * np.exp(-t(dur) / tau)).astype(np.float32)


def glide(f0, f1, dur, curve=1.0):
    """Frequency array from f0 to f1 (exponential in pitch); curve > 1 bends late, < 1 bends early."""
    u = np.linspace(0, 1, n_of(dur)) ** curve
    return (f0 * (f1 / f0) ** u).astype(np.float64)


def ease(x):
    x = np.clip(x, 0, 1)
    return 1 - (1 - x) ** 3


def smooth(x, ms):
    """Moving-average smoothing of a control signal."""
    k = max(1, n_of(ms / 1000))
    return np.convolve(x, np.ones(k) / k, mode="same").astype(np.float32)


def vibrato(freq, dur, rate=5.5, depth=0.01, delay=0.0):
    """Per-sample frequency array with a sine vibrato (depth as a fraction of the pitch)."""
    tt = t(dur)
    d = np.clip((tt - delay) / 0.25, 0, 1)
    return freq * (1 + depth * d * np.sin(TAU * rate * tt))


# --------------------------------------------------------------- filters
def biquad(x, kind, fc, q=0.707, gain_db=0.0):
    """RBJ cookbook biquad on a mono array. kind: lowpass, highpass, bandpass, notch, peak, lowshelf, highshelf."""
    fc = max(10.0, min(fc, SR * 0.49))
    w0 = TAU * fc / SR
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2 * q)
    A = 10 ** (gain_db / 40)
    if kind == "lowpass":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
        a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    elif kind == "highpass":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
        a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    elif kind == "bandpass":
        b0, b1, b2 = alpha, 0, -alpha
        a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    elif kind == "notch":
        b0, b1, b2 = 1, -2 * cw, 1
        a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    elif kind == "peak":
        b0, b1, b2 = 1 + alpha * A, -2 * cw, 1 - alpha * A
        a0, a1, a2 = 1 + alpha / A, -2 * cw, 1 - alpha / A
    elif kind == "lowshelf":
        sq = 2 * math.sqrt(A) * alpha
        b0 = A * ((A + 1) - (A - 1) * cw + sq)
        b1 = 2 * A * ((A - 1) - (A + 1) * cw)
        b2 = A * ((A + 1) - (A - 1) * cw - sq)
        a0 = (A + 1) + (A - 1) * cw + sq
        a1 = -2 * ((A - 1) + (A + 1) * cw)
        a2 = (A + 1) + (A - 1) * cw - sq
    elif kind == "highshelf":
        sq = 2 * math.sqrt(A) * alpha
        b0 = A * ((A + 1) + (A - 1) * cw + sq)
        b1 = -2 * A * ((A - 1) + (A + 1) * cw)
        b2 = A * ((A + 1) + (A - 1) * cw - sq)
        a0 = (A + 1) - (A - 1) * cw + sq
        a1 = 2 * ((A - 1) - (A + 1) * cw)
        a2 = (A + 1) - (A - 1) * cw - sq
    else:
        raise ValueError(kind)
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    return _iir2(np.asarray(x, dtype=np.float64), b0, b1, b2, a1, a2).astype(np.float32)


def _iir2(x, b0, b1, b2, a1, a2):
    n = len(x)
    y = np.empty(n, dtype=np.float64)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(n):
        xi = x[i]
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def lowpass(x, fc, q=0.707):
    return biquad(x, "lowpass", fc, q)


def highpass(x, fc, q=0.707):
    return biquad(x, "highpass", fc, q)


def bandpass(x, fc, q=2.0):
    return biquad(x, "bandpass", fc, q)


def sweep_lowpass(x, fc_curve, q=0.9, blocks=64):
    """Lowpass whose cutoff follows fc_curve (array over the sound), applied in blocks (cheap filter sweeps)."""
    n = len(x)
    out = np.zeros(n, dtype=np.float32)
    edges = np.linspace(0, n, blocks + 1).astype(int)
    fc_curve = np.asarray(fc_curve)
    prev = None
    for i in range(blocks):
        a, b = edges[i], edges[i + 1]
        if b <= a:
            continue
        # filter a little before the block so the state is warm, then keep only the block
        a0 = max(0, a - 2048)
        fc = float(fc_curve[min(len(fc_curve) - 1, int((a + b) // 2 * len(fc_curve) / n))])
        seg = biquad(x[a0:b], "lowpass", fc, q)
        out[a:b] = seg[a - a0:]
    return out


def fft_shape(x, fn):
    """Multiply the spectrum by fn(freq_hz_array) (a gain curve). Fast brick-wall / tilt shaping for noise."""
    n = len(x)
    X = np.fft.rfft(np.asarray(x, dtype=np.float64))
    f = np.fft.rfftfreq(n, 1 / SR)
    X *= fn(f)
    return np.fft.irfft(X, n).astype(np.float32)


def band_noise(dur, rng, lo, hi, color="white"):
    """Noise restricted to [lo, hi] Hz with soft edges."""
    x = noise(dur, rng, color)
    def g(f):
        return np.clip((f - lo * 0.8) / (lo * 0.2 + 1e-9), 0, 1) * np.clip((hi * 1.2 - f) / (hi * 0.2 + 1e-9), 0, 1)
    return fft_shape(x, g)


# --------------------------------------------------------------- effects
def reverb(x, decay_s=1.2, mix=0.3, predelay=0.01, tone=4000.0, seed=7):
    """Convolution reverb with a synthetic exponentially decaying noise impulse (FFT convolution)."""
    rng = np.random.default_rng(seed)
    n_ir = n_of(decay_s * 1.2)
    ir = rng.standard_normal(n_ir) * np.exp(-np.arange(n_ir) / (decay_s * SR / 4.6))
    ir = fft_shape(ir.astype(np.float32), lambda f: 1 / (1 + (f / tone) ** 2))
    ir = np.concatenate([np.zeros(n_of(predelay)), ir])
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = fft_convolve(x, ir)[: len(x)]
    wet *= 0.35 * np.sqrt(decay_s) * 2
    return (np.asarray(x, dtype=np.float32) * (1 - mix) + wet * mix).astype(np.float32)


def fft_convolve(x, h):
    n = len(x) + len(h) - 1
    N = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(h, N), N)[:n]
    return y.astype(np.float32)


def delay(x, time_s, feedback=0.3, mix=0.3, taps=6):
    out = np.asarray(x, dtype=np.float32).copy()
    d = n_of(time_s)
    wet = np.zeros_like(out)
    buf = out.copy()
    for k in range(1, taps + 1):
        shifted = np.zeros_like(out)
        if k * d < len(out):
            shifted[k * d:] = buf[: len(out) - k * d]
        wet += shifted * (feedback ** k)
    return out * (1 - mix) + wet * mix


def chorus(x, depth_ms=6.0, rate=0.8, mix=0.4):
    """Simple modulated-delay chorus (stereo widening when applied with opposite phases)."""
    n = len(x)
    tt = np.arange(n) / SR
    d = (depth_ms / 1000 * SR) * (0.5 + 0.5 * np.sin(TAU * rate * tt))
    idx = np.arange(n) - d - depth_ms / 1000 * SR
    idx = np.clip(idx, 0, n - 1)
    wet = np.interp(idx, np.arange(n), x)
    return (x * (1 - mix) + wet * mix).astype(np.float32)


def distort(x, drive=2.0):
    return np.tanh(np.asarray(x, dtype=np.float32) * drive) / math.tanh(drive)


def bitcrush(x, bits=6, hold=4):
    q = 2 ** (bits - 1)
    y = np.round(np.asarray(x) * q) / q
    if hold > 1:
        y = np.repeat(y[::hold], hold)[: len(x)]
    return y.astype(np.float32)


def pitch_shift_simple(x, ratio):
    """Resample (changes length). ratio > 1 is higher and shorter."""
    n = len(x)
    m = int(n / ratio)
    return np.interp(np.linspace(0, n - 1, m), np.arange(n), x).astype(np.float32)


def reverse(x):
    return np.asarray(x)[::-1].copy()


# --------------------------------------------------------------- plucks and percussion
def pluck(freq, dur, rng, bright=0.5, damp=0.996):
    """Karplus-Strong string, block-vectorised per period. bright 0..1 sets the initial noise colour."""
    n = n_of(dur)
    period = max(2, int(round(SR / freq)))
    burst = rng.standard_normal(period).astype(np.float32)
    if bright < 1:
        burst = lowpass(burst, 1200 + 9000 * bright)
    burst /= (np.max(np.abs(burst)) + 1e-9)
    # one zero sample in front so the two-tap average never reads before the buffer
    out = np.zeros(n + period + 2, dtype=np.float32)
    out[1:period + 1] = burst
    i = period + 1
    end = n + 1
    while i < end:
        k = min(period, end - i)
        out[i:i + k] = damp * 0.5 * (out[i - period:i - period + k] + out[i - period - 1:i - period - 1 + k])
        i += k
    return out[1:end]


def kick(dur, f0=150.0, f1=45.0, rng=None, click=0.3):
    body = sine(glide(f0, f1, dur, curve=0.5), dur) * decay(dur, dur / 4)
    if click and rng is not None:
        body[: n_of(0.01)] += (noise(0.01, rng) * click)[: len(body[: n_of(0.01)])]
    return body


def click(rng, dur=0.02, fc=3000.0):
    return bandpass(noise(dur, rng), fc, 3) * decay(dur, dur / 3)


# --------------------------------------------------------------- notes
A4 = 440.0
NOTE_NAMES = {"C": -9, "C#": -8, "Db": -8, "D": -7, "D#": -6, "Eb": -6, "E": -5, "F": -4, "F#": -3, "Gb": -3, "G": -2,
              "G#": -1, "Ab": -1, "A": 0, "A#": 1, "Bb": 1, "B": 2}


def note(name):
    """'A4' -> 440, 'C#5' -> 554.4 ..."""
    i = 1
    while i < len(name) and name[i] in "#b":
        i += 1
    semis = NOTE_NAMES[name[:i]] + 12 * (int(name[i:]) - 4)
    return A4 * 2 ** (semis / 12)


def semis(freq, n):
    return freq * 2 ** (n / 12)


PENTA_MAJOR = [0, 2, 4, 7, 9]


def scale_note(root, degree, scale=PENTA_MAJOR):
    octave, d = divmod(degree, len(scale))
    return semis(root, scale[d] + 12 * octave)


def bell(freq, dur, rng=None, partials=((1.0, 1.0, 1.0), (2.76, 0.5, 0.6), (5.4, 0.25, 0.35), (8.9, 0.12, 0.2))):
    """A struck bell / glockenspiel: inharmonic partials with their own decays. partials: (ratio, amp, decay_frac)."""
    out = np.zeros(n_of(dur), dtype=np.float32)
    for ratio, amp, dec in partials:
        out += sine(freq * ratio, dur) * decay(dur, dur * dec * 0.4) * amp
    out[: n_of(0.003)] *= np.linspace(0, 1, n_of(0.003))
    return out


def chime(freq, dur):
    """A softer sine-ish chime with a touch of 2nd and 3rd harmonic."""
    out = sine(freq, dur) + 0.35 * sine(freq * 2, dur) * decay(dur, dur * 0.2) + 0.15 * sine(freq * 3, dur) * decay(dur, dur * 0.12)
    out *= decay(dur, dur * 0.3)
    out[: n_of(0.004)] *= np.linspace(0, 1, n_of(0.004))
    return out.astype(np.float32)


# --------------------------------------------------------------- mixing and shaping
def mix(*parts, dur=None):
    """mix(a, (b, 0.25), (c, 0.5, 0.6)) -> sum with start offsets (s) and gains. Length grows to fit unless dur set."""
    items = []
    for p in parts:
        if isinstance(p, tuple):
            arr, off, g = (p + (1.0,))[:3] if len(p) == 2 else p[:3]
        else:
            arr, off, g = p, 0.0, 1.0
        items.append((np.asarray(arr, dtype=np.float32), n_of(off), g))
    n = n_of(dur) if dur else max(o + len(a) for a, o, _ in items)
    out = np.zeros(n, dtype=np.float32)
    for a, o, g in items:
        k = min(len(a), n - o)
        if k > 0:
            out[o:o + k] += a[:k] * g
    return out


def gain_db(x, db):
    return (np.asarray(x) * 10 ** (db / 20)).astype(np.float32)


def normalize(x, peak=PEAK):
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    return (x / m * peak).astype(np.float32) if m > 1e-9 else np.asarray(x, dtype=np.float32)


def fade(x, fin=0.0, fout=0.0):
    x = np.asarray(x, dtype=np.float32).copy()
    a, b = n_of(fin), n_of(fout)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def trim_head(x, thresh=0.01):
    """Cut the silent head so one-shots start within 5 ms (keeps a 1 ms pre-roll)."""
    x = np.asarray(x)
    mono = x if x.ndim == 1 else x.mean(axis=0)
    idx = np.argmax(np.abs(mono) > thresh * (np.max(np.abs(mono)) + 1e-9))
    start = max(0, idx - n_of(0.001))
    return x[..., start:]


def make_loop(x, frac=0.1):
    """Crossfade the last `frac` of the sound into its head so it loops seamlessly (shortens by that amount)."""
    x = np.asarray(x, dtype=np.float32)
    n = x.shape[-1]
    k = int(n * frac)
    if k < 2:
        return x
    ramp = np.linspace(0, 1, k, dtype=np.float32)
    head = x[..., :k] * ramp + x[..., n - k:] * (1 - ramp)
    out = np.concatenate([head, x[..., k:n - k]], axis=-1)
    return out


def stereo(left, right=None):
    if right is None:
        right = left
    n = min(len(left), len(right))
    return np.stack([left[:n], right[:n]]).astype(np.float32)


def widen(x, ms=12.0, amount=0.6, seed=3):
    """Mono to a gentle stereo spread (short decorrelated delays)."""
    x = np.asarray(x, dtype=np.float32)
    d = n_of(ms / 1000)
    l = x.copy()
    r = np.concatenate([np.zeros(d, dtype=np.float32), x[:-d]]) if d < len(x) else x
    l = x * (1 - amount * 0.5) + r * amount * 0.5
    r2 = x * (1 - amount * 0.5) + chorus(x, 4.0, 0.3, amount) * amount * 0.5
    return stereo(l, r2)


def pan(x, p):
    """Mono to stereo with constant-power pan, p in [-1, 1]."""
    a = (p + 1) / 2 * math.pi / 2
    return stereo(x * math.cos(a), x * math.sin(a))


def place(parts, dur):
    """Stereo mix: parts are (stereo_or_mono_array, offset_s, gain). Returns (2, n)."""
    n = n_of(dur)
    out = np.zeros((2, n), dtype=np.float32)
    for arr, off, g in parts:
        arr = np.asarray(arr, dtype=np.float32)
        if arr.ndim == 1:
            arr = stereo(arr)
        o = n_of(off)
        k = min(arr.shape[1], n - o)
        if k > 0:
            out[:, o:o + k] += arr[:, :k] * g
    return out


def compress(x, thresh=0.5, ratio=3.0, attack_ms=2.0, release_ms=80.0):
    """Simple peak compressor on the mono or stereo envelope."""
    x = np.asarray(x, dtype=np.float32)
    mono = x if x.ndim == 1 else np.max(np.abs(x), axis=0)
    a = math.exp(-1 / (attack_ms / 1000 * SR))
    r = math.exp(-1 / (release_ms / 1000 * SR))
    envl = np.empty(len(mono), dtype=np.float64)
    e = 0.0
    absx = np.abs(mono)
    for i in range(len(mono)):
        v = absx[i]
        e = a * e + (1 - a) * v if v > e else r * e + (1 - r) * v
        envl[i] = e
    g = np.ones_like(envl)
    over = envl > thresh
    g[over] = (thresh + (envl[over] - thresh) / ratio) / envl[over]
    return (x * g.astype(np.float32)).astype(np.float32)


def finish(x, loop=False, tail=0.004):
    """What the builder applies to every recipe output."""
    x = np.asarray(x, dtype=np.float32)
    if not loop:
        x = trim_head(x)
    x = np.nan_to_num(x)
    x = normalize(x)
    if loop:
        x = make_loop(x, 0.1)
    else:
        x = fade(x, 0.0, tail) if x.ndim == 1 else np.stack([fade(c, 0.0, tail) for c in x])
    return np.clip(x, -1, 1).astype(np.float32)


# --------------------------------------------------------------- output
def write_wav(path, x):
    import wave
    x = np.asarray(x, dtype=np.float32)
    ch = 1 if x.ndim == 1 else x.shape[0]
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    if ch > 1:
        data = data.T.reshape(-1)
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def write_ogg(path, x, quality=5):
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    tmp.close()
    try:
        write_wav(tmp.name, x)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    finally:
        os.unlink(tmp.name)


def spectrogram(x, width=240, height=64, fmax=12000.0):
    """A small log-ish spectrogram image (uint8, height x width) for the contact sheet."""
    x = np.asarray(x)
    mono = x if x.ndim == 1 else x.mean(axis=0)
    n = len(mono)
    win = 1024
    hop = max(1, (n - win) // max(1, width - 1))
    cols = []
    hann = np.hanning(win)
    for c in range(width):
        a = min(c * hop, max(0, n - win))
        seg = mono[a:a + win]
        if len(seg) < win:
            seg = np.pad(seg, (0, win - len(seg)))
        spec = np.abs(np.fft.rfft(seg * hann))
        cols.append(spec)
    S = np.array(cols).T  # bins x width
    f = np.fft.rfftfreq(win, 1 / SR)
    # resample bins onto a log frequency axis
    fl = np.geomspace(60, fmax, height)
    rows = np.array([S[np.argmin(np.abs(f - fi))] for fi in fl])
    db = 20 * np.log10(rows + 1e-6)
    db = np.clip((db + 70) / 70, 0, 1)
    return (db[::-1] * 255).astype(np.uint8)
