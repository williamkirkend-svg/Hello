#!/usr/bin/env python3
"""
recipes_celebration.py -- the celebration shows' sounds (docs/sound-pitch.md, 3.1 "Celebrations, shared" and
"Celebrations, signatures"). Every recipe is mono, 3D, Celebration group; build_sfx_pack.py renders them.

Grammar (pitch, section 1): every hit is a sub thump (felt), a transient (heard) and an air tail (shimmer).
CelDetonate is the reference hit. Loops are rendered circularly (FFT-shaped noise, oscillators quantised to whole
cycles per period, events wrap around the end) and returned as period + period/9 so the builder's 10 percent
crossfade overlaps identical material and the seam is exact.

Speed: noise beds are FFT shaped (fft_shape / band_noise), reverbs are FFT convolutions; biquads only touch short
sounds. The whole module builds in well under a minute.
"""
import math

import numpy as np

from synth import (SR, TAU, sound, t, n_of, sine, softsaw, fm, noise, decay, glide, vibrato, sweep_lowpass,
                   fft_shape, band_noise, reverb, reverse, note, scale_note, bell, chime, mix, fade)

C5 = note("C5")
C6 = note("C6")
_PENTA = np.array([scale_note(note("C4"), d) for d in range(32)])  # C4 .. beyond C10, major pentatonic


# =============================================================== helpers
def _z(dur):
    return np.zeros(n_of(dur), dtype=np.float32)


def _unit(x):
    x = np.asarray(x, dtype=np.float32)
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    return x / m if m > 1e-9 else x


def _pad(x, extra):
    return np.concatenate([np.asarray(x, np.float32), _z(extra)])


def _ramp(dur, a=0.0, b=1.0, curve=1.0):
    return (a + (b - a) * np.linspace(0, 1, n_of(dur)) ** curve).astype(np.float32)


def _u(dur):
    return np.linspace(0, 1, n_of(dur), dtype=np.float64)


def _verb(x, decay_s=0.8, mixv=0.3, tone=4000.0, tail=None, seed=7):
    """Reverb with room for the tail, ending at silence."""
    tail = decay_s if tail is None else tail
    y = reverb(_pad(x, tail), decay_s, mixv, tone=tone, seed=seed)
    return fade(y, 0, min(0.1, tail * 0.5))


def _lp(x, fc, order=2):
    return fft_shape(x, lambda f: 1 / np.sqrt(1 + (f / fc) ** (2 * order)))


def _hp(x, fc, order=2):
    return fft_shape(x, lambda f: 1 / np.sqrt(1 + (fc / np.maximum(f, 1e-3)) ** (2 * order)))


def _tilt_noise(dur, rng, slope=1.0, lo=30.0):
    """1/f^slope (power) noise: 1 pink, 2 brown, DC removed. Circular (FFT shaped)."""
    return fft_shape(noise(dur, rng), lambda f: (lo / np.maximum(f, lo)) ** (slope / 2) * np.clip((f - 12) / 12, 0, 1))


def _formant(x, peaks, floor=0.03):
    """Static formant shaping: peaks = [(fc, bw, amp), ...]."""
    return fft_shape(x, lambda f: sum(a / (1 + ((f - fc) / bw) ** 2) for fc, bw, a in peaks) + floor)


def _quant(f):
    return float(_PENTA[np.argmin(np.abs(np.log(_PENTA / f)))])


def _sub(dur=0.3, f0=150.0, f1=40.0, tau=None):
    """The felt layer: a sine dropping f0 -> f1."""
    return (sine(glide(f0, f1, dur, curve=0.5), dur) * decay(dur, tau or dur * 0.3)).astype(np.float32)


def _crack(rng, dur=0.05, lo=1000.0, hi=6000.0, tau=None):
    """The heard layer: a band-limited noise burst."""
    return _unit(band_noise(dur, rng, lo, hi) * decay(dur, tau or dur / 4))


def _air(rng, dur, base=2000.0, n=6, spread=1.0, tau=None):
    """Detuned high sines with their own decays: the shimmer tail."""
    out = np.zeros(n_of(dur), dtype=np.float32)
    for _ in range(n):
        f = base * 2 ** rng.uniform(0, spread)
        out += sine(f, dur, phase=rng.uniform(0, TAU)) * decay(dur, (tau or dur * 0.35) * rng.uniform(0.6, 1.3)) * rng.uniform(0.4, 1)
    out[: n_of(0.003)] *= np.linspace(0, 1, n_of(0.003))
    return _unit(out)


GLASS = ((1.0, 1.0, 1.0), (2.32, 0.55, 0.55), (4.25, 0.3, 0.35), (6.63, 0.12, 0.2))
CRYSTAL = ((1.0, 1.0, 1.0), (2.0, 0.5, 0.85), (3.01, 0.3, 0.65), (4.16, 0.25, 0.5), (5.43, 0.15, 0.4), (6.8, 0.07, 0.3))
COIN = ((1.0, 1.0, 1.0), (1.5, 0.5, 0.7), (2.7, 0.45, 0.5), (4.1, 0.3, 0.35), (5.9, 0.12, 0.25))


def _ping(freq, dur, partials=GLASS, g=1.0):
    """A struck bell; partials that would land above 8 kHz are dropped (nothing harsh up there)."""
    kept = [p for p in partials if freq * p[0] < 8000] or [partials[0]]
    return bell(freq, dur, partials=kept) * g


def _sparkles(rng, dur, count, f_lo, f_hi, bias=0.0, rise=0.0, ping=0.12, soft=False, partials=None):
    """Random tiny pentatonic bells. bias > 0 clusters them early; rise 0..1 makes the pitch follow time."""
    out = _z(dur)
    span = max(1e-3, dur - ping)
    for _ in range(count):
        u = rng.uniform() ** (1 + bias)
        pos = n_of(u * span)
        f = _quant(f_lo * (f_hi / f_lo) ** (u * rise + rng.uniform() * (1 - rise)))
        if partials:
            p = _ping(f, ping, partials)
        else:
            p = chime(f, ping)
            if soft:
                a = n_of(0.012)
                p[:a] *= np.linspace(0, 1, a)
        g = rng.uniform(0.35, 1.0)
        k = min(len(p), len(out) - pos)
        out[pos:pos + k] += p[:k] * g
    return _unit(out)


def _bands(dur, rng, f_lo, f_hi, count):
    """count static noise bands log-spaced over [f_lo, f_hi] (a matrix) for cheap filter sweeps."""
    fs = np.geomspace(f_lo, f_hi, count)
    half = (f_hi / f_lo) ** (1 / (count - 1) / 2)
    M = np.stack([band_noise(dur, rng, f / half, f * half) for f in fs]).astype(np.float32)
    return fs, M


def _sweep_noise(dur, rng, path_hz, width=0.5, count=14, f_lo=100.0, f_hi=7000.0):
    """Noise whose band centre follows path_hz (an array over the sound), width in octaves."""
    fs, M = _bands(dur, rng, f_lo, f_hi, count)
    n = n_of(dur)
    lp = np.log2(np.asarray(path_hz, np.float64))
    if len(lp) != n:
        lp = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(lp)), lp)
    E = np.exp(-0.5 * ((np.log2(fs)[:, None] - lp[None, :]) / width) ** 2).astype(np.float32)
    return _unit((M * E).sum(axis=0))


def _whoosh(dur, rng, f0=250.0, f1=2200.0, f2=None, peak=0.4, width=0.45, curve=2.0, fall=1.6):
    u = _u(dur)
    f2 = f2 or f0 * 0.7
    up = u < peak
    path = np.where(up, f0 * (f1 / f0) ** (u / peak), f1 * (f2 / f1) ** ((u - peak) / (1 - peak)))
    amp = np.where(up, (u / peak) ** curve, ((1 - u) / (1 - peak)) ** fall)
    return (_sweep_noise(dur, rng, path, width) * amp).astype(np.float32)


def _fm_voice(f_arr, dur, ratio, index_env, formants, floor=0.03):
    x = fm(f_arr, np.asarray(f_arr) * ratio, np.asarray(index_env, np.float64), dur)
    return _unit(_formant(x, formants, floor))


def _env(dur, a, hold_to, r, floor=0.0):
    """Attack over a, full until hold_to, release over r (ends at 0) -- array over dur."""
    tt = t(dur)
    e = np.where(tt < hold_to, np.clip(tt / max(a, 1e-4), 0, 1), np.clip((dur - tt) / max(r, 1e-4), 0, 1) ** 1.3)
    return np.maximum(e, floor).astype(np.float32)


# ---- loops: circular rendering
def _q(f, P):
    """Quantise a frequency to whole cycles per period P so a steady tone loops without a seam."""
    return round(f * P) / P


def _lfo_rand(dur, rng, harm=4, cycles=1, lo=0.0, hi=1.0):
    """A smooth random envelope made of `harm` sines with whole cycles over dur (circular), scaled to [lo, hi]."""
    u = np.linspace(0, 1, n_of(dur), endpoint=False)
    y = np.zeros(len(u))
    for k in range(1, harm + 1):
        y += rng.uniform(0.3, 1) / k * np.sin(TAU * (k * cycles * u + rng.uniform()))
    y = (y - y.min()) / (np.ptp(y) + 1e-9)
    return (lo + (hi - lo) * y).astype(np.float32)


def _put(buf, x, pos, g=1.0):
    """Add x into buf at sample pos, wrapping around the end (circular)."""
    n = len(buf)
    pos = int(pos) % n
    x = np.asarray(x, np.float32) * g
    k = min(len(x), n - pos)
    buf[pos:pos + k] += x[:k]
    r = x[k:]
    while len(r):
        m = min(len(r), n)
        buf[:m] += r[:m]
        r = r[m:]


def _circ_verb(y, decay_s, mixv, tone=4000.0, seed=7):
    """Reverb whose tail wraps into the head of the loop (runs on three tiled copies, keeps the last)."""
    n = len(y)
    w = reverb(np.tile(y, 3), decay_s, mixv, tone=tone, seed=seed)
    return w[2 * n:].astype(np.float32)


def _loop_out(y, even=True):
    """Period + its first ninth: after the builder's 10 percent crossfade the file is exactly the period.
    The material is circular, so it is first rotated to put the file boundary where the level is steadiest
    (the 50 ms either side match)."""
    y = np.asarray(y, np.float32)
    n = len(y)
    if even and n > SR // 2:
        W = n_of(0.05)
        c = np.concatenate([[0.0], np.cumsum(np.concatenate([y, y]).astype(np.float64) ** 2)])
        cand = np.arange(W, n + W, n_of(0.001))
        a = (c[cand] - c[cand - W]) / W
        b = (c[cand + W] - c[cand]) / W
        med = np.median(a)
        score = np.abs(np.log((a + 1e-12) / (b + 1e-12))) + 0.3 * np.abs(np.log((a + 1e-12) / (med + 1e-12)))
        y = np.roll(y, -int(cand[np.argmin(score)] % n))
    return np.concatenate([y, y[: n // 9]])


def _shepard(P, f_base, octaves=6, direction=-1):
    """Endless glissando: `octaves` sine voices an octave apart each glide one octave over P under a raised-cosine
    log-frequency window. Whole cycles per voice and exact phase, so the loop point is seamless."""
    n = n_of(P)
    ln2 = math.log(2)
    if direction > 0:
        m = max(1, round(f_base * P / ln2))
        f_base = m * ln2 / P
    else:
        m = max(1, round(f_base * P / (2 * ln2)))
        f_base = 2 * m * ln2 / P
    u = np.arange(n, dtype=np.float64) / n
    lo, hi = (0, octaves) if direction > 0 else (-1, octaves - 1)
    out = np.zeros(n, dtype=np.float64)
    for k in range(octaves):
        pos = k + direction * u
        phase = TAU * f_base * 2 ** k * P / (direction * ln2) * (2 ** (direction * u) - 1)
        w = np.sin(math.pi * (pos - lo) / (hi - lo)) ** 2
        out += np.sin(phase) * w
    return _unit(out)


# =============================================================== shared cues
@sound("CelChargeUp", length=1.0)
def cel_chargeup(v, rng):
    """The inhale: a reversed hit, a rising sine cluster and rising noise, loudest at the very end, then nothing."""
    D = 1.0
    hit = mix(_crack(rng, 0.06, 800, 6000), (_air(rng, 0.8, 1800, 7, 1.2, 0.3), 0.0, 0.5), dur=0.9)
    suck = reverse(reverb(hit, 0.8, 0.75, tone=4500))
    suck = _pad(suck, D - 0.9)
    f = glide(1, 6, D, curve=1.6)
    cluster = _z(D)
    for i in range(4):
        cluster += softsaw(f * 92 * rng.uniform(0.985, 1.015) * (1.5 if i == 3 else 1), D, 6) * rng.uniform(0.6, 1)
    cluster = _lp(cluster, 2500) * _ramp(D, 0.04, 1, 2.2)
    wind = _sweep_noise(D, rng, glide(220, 5200, D, 1.3), 0.6) * _ramp(D, 0.05, 1, 2.6)
    rumble = _unit(_lp(_tilt_noise(D, rng, 2), 90)) * _ramp(D, 0.1, 1, 1.5)
    out = mix((suck, 0, 0.9), (cluster, 0, 0.45), (wind, 0, 0.6), (rumble, 0, 0.5), dur=D)
    return fade(out, 0.0, 0.003)


@sound("CelDetonate", length=1.2)
def cel_detonate(v, rng):
    """The reference hit: sub thump, crack, boom body, shimmer tail."""
    sub = _sub(0.35, 150, 40, 0.1)
    crack = _crack(rng, 0.06, 900, 6500, 0.012)
    body = _unit(_lp(noise(0.3, rng), 500)) * decay(0.3, 0.07)
    air = _air(rng, 0.9, 2400, 7, 1.0, 0.25)
    spark = _sparkles(rng, 0.9, 14, note("C7"), note("C8"), bias=1.5, ping=0.15)
    dry = mix(sub, (crack, 0, 0.9), (body, 0, 0.7), (air, 0.01, 0.35), (spark, 0.03, 0.22), dur=1.0)
    return _verb(dry, 0.7, 0.35, tone=5000, tail=0.2)


@sound("CelShockwave", length=0.7)
def cel_shockwave(v, rng):
    """A ring passing: noise band sweeping 300 -> 3000 Hz with a doppler pitch drop."""
    D = 0.55
    u = _u(D)
    ring = _sweep_noise(D, rng, glide(300, 3000, D), 0.4) * np.where(u < 0.1, u / 0.1, ((1 - u) / 0.9) ** 1.4)
    tone = (sine(glide(1100, 380, D, 0.8), D) + 0.4 * sine(glide(2200, 760, D, 0.8), D)) * np.exp(-((u - 0.18) / 0.16) ** 2)
    sub = _sub(0.2, 120, 50, 0.05)
    dry = mix((ring, 0, 1.0), (tone, 0, 0.5), (sub, 0, 0.5), dur=D)
    return _verb(dry, 0.3, 0.25, tail=0.15)


@sound("CelWhooshS", length=0.4)
def cel_whoosh_s(v, rng):
    return _whoosh(0.43, rng, 400, 3500, 600, peak=0.35, width=0.5)


@sound("CelWhooshL", length=1.0)
def cel_whoosh_l(v, rng):
    D = 0.9
    w = _whoosh(D, rng, 150, 1800, 200, peak=0.4, width=0.55)
    u = _u(D)
    body = _unit(_lp(noise(D, rng), 220)) * np.where(u < 0.4, (u / 0.4) ** 2, ((1 - u) / 0.6) ** 1.6)
    return _verb(mix(w, (body, 0, 0.6), dur=D), 0.3, 0.2, tail=0.1)


@sound("CelImpact", length=0.5)
def cel_impact(v, rng):
    """The manga impact frame: shorter and drier than the detonation."""
    sub = _sub(0.2, 150, 45, 0.05)
    crack = _crack(rng, 0.04, 1000, 7000, 0.008)
    body = _unit(_lp(noise(0.14, rng), 700)) * decay(0.14, 0.03)
    air = _air(rng, 0.3, 2600, 5, 0.8, 0.07)
    dry = mix(sub, (crack, 0, 1.0), (body, 0, 0.8), (air, 0.005, 0.3), dur=0.4)
    return _verb(dry, 0.2, 0.15, tone=5000, tail=0.1)


@sound("CelShimmer", length=1.5)
def cel_shimmer(v, rng):
    spark = _sparkles(rng, 1.3, 26, note("C7"), note("E8"), bias=1.0, ping=0.2)
    air = _air(rng, 1.3, 2500, 8, 1.3, 0.35)
    dry = mix(spark, (air, 0, 0.45), dur=1.3)
    return _verb(dry, 0.6, 0.35, tone=6000, tail=0.2)


@sound("CelRiser", length=2.0)
def cel_riser(v, rng):
    D = 2.0
    wind = _sweep_noise(D, rng, glide(150, 6000, D, 1.2), 0.6) * _ramp(D, 0.04, 1, 2.0)
    f = glide(1, 8, D, curve=1.3)
    cluster = _z(D)
    for i in range(4):
        cluster += softsaw(f * 110 * rng.uniform(0.98, 1.02), D, 5)
    rate = glide(4, 18, D)
    trem = 0.7 + 0.3 * np.sin(TAU * np.cumsum(rate) / SR)
    cluster = _lp(cluster, 3000) * _ramp(D, 0.05, 1, 1.6) * trem
    out = mix((wind, 0, 0.7), (cluster, 0, 0.5), dur=D)
    return fade(out, 0, 0.08)


@sound("CelLand", length=0.5)
def cel_land(v, rng):
    """Body landing: low thud and dust."""
    thud = _sub(0.22, 95, 42, 0.06)
    body = _unit(_lp(noise(0.1, rng), 300)) * decay(0.1, 0.025)
    flutter = _unit(np.abs(_lp(noise(0.4, rng), 60))) * 0.6 + 0.4
    dust = band_noise(0.4, rng, 400, 2500) * decay(0.4, 0.12) * flutter
    dust = _unit(dust)
    dry = mix(thud, (body, 0, 0.8), (dust, 0.005, 0.45), dur=0.42)
    return _verb(dry, 0.25, 0.2, tail=0.08)


@sound("CelTitle", length=0.6)
def cel_title(v, rng):
    """The title sting: two bright notes a fifth apart and a sparkle."""
    a = _ping(note("G5"), 0.45, CRYSTAL)
    b = _ping(note("D6"), 0.4, CRYSTAL)
    spark = _sparkles(rng, 0.35, 7, note("C7"), note("C8"), ping=0.1)
    dry = mix(a, (b, 0.11, 0.9), (spark, 0.12, 0.35), dur=0.5)
    return _verb(dry, 0.25, 0.25, tone=6000, tail=0.1)


@sound("CelBed", loop=True, length=8.0)
def cel_bed(v, rng):
    """An airy pad: slow detuned saws (G major) through a lowpass, soft. Circular: every voice is whole cycles."""
    P = 8.0
    n = n_of(P)
    pad = np.zeros(n, dtype=np.float32)
    for nm, g in (("G2", 1.0), ("D3", 0.8), ("G3", 0.7), ("B3", 0.5), ("D4", 0.45)):
        f0 = note(nm)
        for d in (-0.375, 0.0, 0.375):
            pad += softsaw(_q(f0 + d, P), P, 10) * g * rng.uniform(0.8, 1)
    dark = _lp(pad, 500, 2)
    bright = _lp(pad, 1500, 2) - dark
    lfo = _lfo_rand(P, rng, 3, 1, 0.2, 1.0)
    air = _unit(band_noise(P, rng, 1500, 5000)) * _lfo_rand(P, rng, 3, 1, 0.3, 1.0)
    y = _unit(dark) * 0.8 + _unit(bright) * 0.5 * lfo + air * 0.12
    return _loop_out(y)


# =============================================================== Starfall Halo
@sound("StarChime", length=1.5)
def star_chime(v, rng):
    """Crystal halo ring-out."""
    a = _ping(note("E6"), 1.3, CRYSTAL)
    b = _ping(note("E5"), 1.3, CRYSTAL, 0.4)
    c = _ping(note("B6"), 1.0, GLASS, 0.3)
    dry = mix(a, b, (c, 0.02, 1), dur=1.3)
    return _verb(dry, 0.8, 0.4, tone=6000, tail=0.2)


@sound("StarTwinkle", variants=3, length=0.4)
def star_twinkle(v, rng):
    """Tiny glissando bells; each variant is another little figure."""
    figs = (("C7", "E7", "G7"), ("G7", "E7", "A7"), ("E7", "G7", "C8"))
    out = _z(0.36)
    for i, nm in enumerate(figs[v]):
        f0 = note(nm)
        d = 0.22
        f = glide(f0 * 0.89, f0, d, curve=0.5)
        p = (sine(f, d) + 0.3 * sine(f * 2, d)) * decay(d, 0.07)
        p[: n_of(0.002)] *= np.linspace(0, 1, n_of(0.002))
        pos = n_of(i * (0.055 + 0.01 * v))
        k = min(len(p), len(out) - pos)
        out[pos:pos + k] += p[:k] * (1 - 0.15 * i)
    return _verb(_unit(out), 0.2, 0.2, tone=7000, tail=0.04)


@sound("HaloLand", length=0.8)
def halo_land(v, rng):
    """Glass ring landing: a bright ring and a short rattle."""
    ring = _ping(note("A6"), 0.65, GLASS)
    ring2 = _ping(note("E7"), 0.5, GLASS, 0.4)
    rattle = _z(0.2)
    for i, tt in enumerate((0.0, 0.028, 0.065, 0.115)):
        c = _crack(rng, 0.012, 2000, 6500, 0.003)
        pos = n_of(tt)
        rattle[pos:pos + len(c)] += c * (1 - 0.2 * i)
    tap = _sub(0.06, 320, 150, 0.015)
    dry = mix(ring, ring2, (rattle, 0, 0.6), (tap, 0, 0.5), dur=0.7)
    return _verb(dry, 0.3, 0.25, tone=6000, tail=0.1)


# =============================================================== Thunder Stampede
@sound("ThunderCrack", length=1.4)
def thunder_crack(v, rng):
    """A real crack, then the rumble."""
    D = 1.3
    snap = _unit(_hp(noise(0.012, rng), 800)) * decay(0.012, 0.004)
    crack = _crack(rng, 0.09, 1200, 7000, 0.02)
    crack2 = _crack(rng, 0.06, 900, 5000, 0.015)
    tear = _unit(band_noise(0.45, rng, 200, 1400)) * decay(0.45, 0.1)
    swell = _unit(np.abs(_lp(noise(D, rng), 7))) * 0.7 + 0.3
    rumble = _unit(_lp(_tilt_noise(D, rng, 2), 220)) * decay(D, 0.4) * swell
    rumble = _unit(rumble) * np.minimum(1, t(D) / 0.04)
    dry = mix((snap, 0, 1.0), (crack, 0.002, 1.0), (crack2, 0.06, 0.6), (tear, 0.01, 0.6), (rumble, 0.03, 0.9), dur=D)
    dry = np.tanh(dry * 1.3)
    return _verb(dry, 0.6, 0.3, tone=3000, tail=0.1)


@sound("ArcCrackle", loop=True, length=2.0)
def arc_crackle(v, rng):
    """Electric sizzle: dense micro-sparks, a gated buzz and short zaps. Circular."""
    P = 2.0
    n = n_of(P)
    imp = np.zeros(n, dtype=np.float32)
    k = int(380 * P)
    idx = rng.integers(0, n, k)
    imp[idx] = rng.uniform(-1, 1, k) * rng.uniform(0.2, 1, k) ** 2
    sizzle = _unit(fft_shape(imp, lambda f: np.clip((f - 1200) / 800, 0, 1) * np.clip((7000 - f) / 1500, 0, 1)))
    buzz = softsaw(_q(118, P), P, 14) * _lfo_rand(P, rng, 14, 1, 0.1, 1.0) ** 2
    buzz = _unit(_hp(buzz, 150))
    gate = _lfo_rand(P, rng, 11, 1)
    gate = np.clip((gate - 0.62) / 0.38, 0, 1) ** 2
    zap = _unit(band_noise(P, rng, 2500, 6000)) * gate
    hiss = _unit(band_noise(P, rng, 3000, 7000))
    y = sizzle * 0.8 + buzz * 0.35 + zap * 0.5 + hiss * 0.08
    return _loop_out(y)


@sound("BullCharge", length=1.2)
def bull_charge(v, rng):
    """Rumble and a bellow (low FM voice)."""
    D = 1.05
    bd = 0.8
    f = vibrato(1.0, bd, rate=6.0, depth=0.02, delay=0.1) * glide(95, 68, bd, 1.4)
    idx = np.interp(_u(bd), [0, 0.1, 1], [4.0, 3.0, 1.2])
    voice = _fm_voice(f, bd, 1.0, idx, ((250, 120, 1.0), (700, 220, 0.5), (1500, 350, 0.25)))
    voice *= _env(bd, 0.06, 0.55, 0.3)
    gal = np.zeros(n_of(D))
    for tt in (0.0, 0.11, 0.22, 0.42, 0.53, 0.64, 0.82):
        gal += np.exp(-((t(D) - tt) / 0.045) ** 2)
    rumble = _unit(_lp(_tilt_noise(D, rng, 2), 160)) * (0.45 + 0.55 * np.clip(gal, 0, 1)) * _env(D, 0.03, 0.8, 0.25)
    rumble = _unit(rumble)
    hoof = _unit(_lp(noise(D, rng), 400)) * np.clip(gal, 0, 1) ** 3
    dry = mix((rumble, 0, 0.8), (hoof, 0, 0.35), (voice, 0.15, 0.9), dur=D)
    return _verb(dry, 0.5, 0.3, tone=2500, tail=0.15)


# =============================================================== Golden Tornado
@sound("WindFunnel", loop=True, length=3.0)
def wind_funnel(v, rng):
    """Rising wind: a Shepard-style sweep of noise bands (one octave per period, so it rises forever) over a low
    wind bed. Circular."""
    P = 3.0
    n = n_of(P)
    fs, M = _bands(P, rng, 150, 6000, 22)
    pos = np.log2(fs / 150)
    u = np.arange(n) / n
    glob = np.sin(math.pi * np.clip(pos / pos[-1], 0, 1)) ** 0.7
    E = (0.5 - 0.5 * np.cos(TAU * (pos[:, None] - u[None, :]))) ** 2 * glob[:, None]
    sweep = _unit((M * E.astype(np.float32)).sum(axis=0))
    bed = _unit(_lp(_tilt_noise(P, rng, 1.5), 300)) * _lfo_rand(P, rng, 4, 1, 0.5, 1.0)
    whistle = _shepard(P, 300, 4, +1) * 0.1
    y = sweep * 0.8 + bed * 0.5 + whistle
    return _loop_out(y)


@sound("CoinSpiral", length=1.6)
def coin_spiral(v, rng):
    """Coin tinkles climbing two octaves."""
    D = 1.4
    out = _z(D)
    N = 26
    for i in range(N):
        tt = 1.22 * (i / (N - 1)) ** 0.85
        f = scale_note(C6, round(10 * i / (N - 1))) * rng.uniform(0.995, 1.005)
        p = _ping(f, 0.22, COIN, rng.uniform(0.5, 1))
        pos = n_of(tt)
        k = min(len(p), len(out) - pos)
        out[pos:pos + k] += p[:k]
    return _verb(_unit(out), 0.4, 0.3, tone=6000, tail=0.2)


@sound("CoinRain", loop=True, length=2.0)
def coin_rain(v, rng):
    """Dense coin tinkles. Circular."""
    P = 2.0
    y = _z(P)
    for _ in range(int(36 * P)):
        f = _quant(C6 * 2 ** rng.uniform(0, 2))
        _put(y, _ping(f, 0.16, COIN), rng.integers(0, len(y)), rng.uniform(0.3, 1))
    y = _unit(y) + _unit(band_noise(P, rng, 3500, 7000)) * 0.08
    return _loop_out(_circ_verb(y, 0.4, 0.25, 6000))


@sound("TornadoSlam", length=0.9)
def tornado_slam(v, rng):
    """The X-pose slam: big and dusty."""
    sub = _sub(0.32, 160, 42, 0.09)
    crack = _crack(rng, 0.07, 600, 5000, 0.015)
    body = _unit(_lp(noise(0.3, rng), 400)) * decay(0.3, 0.08)
    dust = _unit(band_noise(0.5, rng, 500, 3000)) * decay(0.5, 0.13)
    dry = mix(sub, (crack, 0, 0.9), (body, 0, 0.9), (dust, 0.01, 0.4), dur=0.75)
    dry = np.tanh(dry * 1.2)
    return _verb(dry, 0.45, 0.3, tone=3500, tail=0.15)


# =============================================================== Galaxy Lasso
@sound("RopeWhirl", loop=True, length=1.2)
def rope_whirl(v, rng):
    """Three whooshes per period (2.5 Hz). Circular; the boundary sits on a whoosh peak."""
    P = 1.2
    n = n_of(P)
    psi = ((np.arange(n) / n) * 3 + 0.5) % 1.0
    s = np.sin(math.pi * psi)
    path = 350 * (2600 / 350) ** (s ** 1.2)
    amp = s ** 1.6 * (0.75 + 0.25 * np.where(psi < 0.5, 1.0, 0.6))
    sweep = _sweep_noise(P, rng, path, 0.45) * amp
    air = _unit(band_noise(P, rng, 800, 3000)) * 0.12
    y = _unit(sweep) * 0.9 + air
    return _loop_out(y)


@sound("CosmicHum", loop=True, length=4.0)
def cosmic_hum(v, rng):
    """Deep spacey hum with a slow shimmer. Circular."""
    P = 4.0
    base = _q(55.0, P)
    hum = _z(P)
    for k, g in ((0.5, 0.5), (1, 1.0), (2, 0.55), (3, 0.3), (4, 0.2), (6, 0.1)):
        hum += sine(_q(base * k, P), P, phase=rng.uniform(0, TAU)) * g * _lfo_rand(P, rng, 2, 1, 0.6, 1.0)
    hum = _unit(hum)
    shim = _z(P)
    for f0 in (1760, 2217, 2637, 3520):
        for d in (-0.25, 0.25):
            shim += sine(_q(f0 + d, P), P, phase=rng.uniform(0, TAU)) * _lfo_rand(P, rng, 3, 1, 0.0, 1.0)
    shim = _unit(shim)
    air = _unit(band_noise(P, rng, 1800, 5000)) * _lfo_rand(P, rng, 3, 1, 0.3, 1.0)
    y = hum * 0.85 + shim * 0.12 + air * 0.1
    return _loop_out(y)


@sound("ConstellationPull", length=1.2)
def constellation_pull(v, rng):
    """A reversed chime cluster that arrives on a single note."""
    cl = _z(0.95)
    for i, d in enumerate((5, 6, 7, 8, 9)):
        p = chime(scale_note(C5, d), 0.7)
        pos = n_of(i * 0.06)
        k = min(len(p), len(cl) - pos)
        cl[pos:pos + k] += p[:k]
    rev = reverse(reverb(_unit(cl), 0.6, 0.55, tone=6000))
    floor = _unit(band_noise(0.95, rng, 600, 3500)) * _ramp(0.95, 0.03, 0.08, 1)
    arrive = fade(_ping(note("C7"), 0.25, CRYSTAL) * decay(0.25, 0.09), 0, 0.04) * 0.9
    return mix(rev, floor, (arrive, 0.95, 1), dur=1.2)


# =============================================================== Blossom Burst
@sound("TreeGrow", length=1.8)
def tree_grow(v, rng):
    """Wood creaks (low resonant chirps) and a leaf rustle that grows with the tree."""
    D = 1.65
    out = _z(D)
    tt = 0.0
    i = 0
    while tt < 1.25:
        d = rng.uniform(0.08, 0.16)
        f0 = rng.uniform(120, 200) * (1 + 0.5 * tt / 1.3)
        f = glide(f0, f0 * rng.uniform(1.4, 2.1), d, curve=rng.uniform(0.7, 1.6))
        c = softsaw(f, d, 8) * fm(f, f, 1.5, d) * 0.5 + softsaw(f, d, 8) * 0.5
        e = np.clip(t(d) / 0.012, 0, 1) * decay(d, d * 0.35)
        c = _lp(c * e, 1800)
        pos = n_of(tt)
        k = min(len(c), len(out) - pos)
        out[pos:pos + k] += c[:k] * rng.uniform(0.5, 1)
        tt += d + rng.uniform(0.02, 0.1)
        i += 1
    creak = _unit(out)
    flutter = _unit(np.abs(_lp(noise(D, rng), 25))) ** 1.5
    leaves = _unit(band_noise(D, rng, 2500, 6500) * flutter) * _env(D, 0.6, 1.3, 0.3, 0.0)
    dry = mix(creak, (leaves, 0, 0.6), dur=D)
    return _verb(dry, 0.4, 0.25, tone=4000, tail=0.15)


@sound("PetalShimmer", loop=True, length=2.0)
def petal_shimmer(v, rng):
    """Soft high sparkle. Circular."""
    P = 2.0
    y = _z(P)
    for _ in range(int(22 * P)):
        f = _quant(note("C7") * 2 ** rng.uniform(0, 1.3))
        p = chime(f, rng.uniform(0.15, 0.3))
        a = n_of(0.015)
        p[:a] *= np.linspace(0, 1, a)
        _put(y, p, rng.integers(0, len(y)), rng.uniform(0.2, 0.8))
    y = _unit(y)
    air = _unit(band_noise(P, rng, 3000, 6500)) * _lfo_rand(P, rng, 3, 1, 0.4, 1.0)
    y = y * 0.85 + air * 0.15
    return _loop_out(_circ_verb(y, 0.6, 0.35, 6000))


@sound("LotusBloom", length=1.2)
def lotus_bloom(v, rng):
    """A soft bloom: a pad swell opening onto a chime."""
    D = 1.15
    pad = _z(D)
    for nm in ("G4", "B4", "D5", "G5"):
        f0 = note(nm)
        for d in (-0.004, 0.004):
            pad += softsaw(vibrato(f0 * (1 + d), D, 4.5, 0.004, 0.2), D, 8)
    pad = _unit(_lp(pad, 1800)) * _env(D, 0.42, 0.5, 0.45, 0.0) * _ramp(D, 0.04, 1, 1)
    pad[: n_of(0.03)] *= np.linspace(0.3, 1, n_of(0.03))
    ch = mix(_ping(note("G6"), 0.6, CRYSTAL), (_ping(note("D7"), 0.5, CRYSTAL), 0.04, 0.5))
    spark = _sparkles(rng, 0.5, 8, note("G7"), note("G8"), ping=0.15, soft=True)
    dry = mix((pad, 0, 0.8), (ch, 0.42, 0.7), (spark, 0.5, 0.3), dur=D)
    return _verb(dry, 0.5, 0.35, tone=5000, tail=0.15)


# =============================================================== Event Horizon
@sound("SuckDrone", loop=True, length=4.0)
def suck_drone(v, rng):
    """A drone that falls in pitch forever (Shepard glissando down) over a sub. Circular."""
    P = 4.0
    shep = _shepard(P, 55, 6, -1)
    sub = sine(_q(40, P), P) * _lfo_rand(P, rng, 2, 1, 0.7, 1.0)
    air = _unit(_lp(_tilt_noise(P, rng, 1.5), 900)) * _lfo_rand(P, rng, 4, 1, 0.4, 1.0)
    growl = _unit(fm(_q(41, P), _q(41, P), 2.0, P) * _lfo_rand(P, rng, 5, 1, 0.0, 1.0))
    y = shep * 0.75 + sub * 0.5 + air * 0.25 + growl * 0.15
    return _loop_out(y)


@sound("Supernova", length=2.2)
def supernova(v, rng):
    """The biggest hit: long sub, huge crack, long bright tail."""
    D = 1.85
    sub = _sub(0.9, 120, 28, 0.35)
    snap = _unit(_hp(noise(0.015, rng), 600)) * decay(0.015, 0.005)
    crack = _crack(rng, 0.1, 900, 7000, 0.025)
    boom = _unit(_lp(noise(0.45, rng), 600)) * decay(0.45, 0.1)
    air = _air(rng, 1.6, 1800, 10, 1.4, 0.5)
    spark = _sparkles(rng, 1.6, 30, note("C7"), note("E8"), bias=1.2, ping=0.25)
    dry = mix(sub, (snap, 0, 1.0), (crack, 0.002, 1.0), (boom, 0, 0.9), (air, 0.02, 0.45), (spark, 0.05, 0.3), dur=D)
    dry = np.tanh(dry * 1.3)
    return _verb(dry, 1.2, 0.4, tone=5000, tail=0.35)


# =============================================================== Spirit Stampede
@sound("PortalOpen", length=1.2)
def portal_open(v, rng):
    """A whoosh opening onto a harmonic swell."""
    D = 1.0
    w = _whoosh(0.7, rng, 250, 3000, 500, peak=0.55, width=0.5)
    swell = _z(D)
    for nm, g in (("D4", 1.0), ("A4", 0.8), ("D5", 0.6), ("F#5", 0.45), ("A5", 0.35)):
        f0 = note(nm)
        swell += (sine(f0 * 0.998, D) + sine(f0 * 1.002, D) + 0.3 * sine(f0 * 2, D)) * g
    swell = _unit(swell) * _env(D, 0.6, 0.72, 0.28)
    spark = _sparkles(rng, 0.45, 9, note("D7"), note("D8"), ping=0.15, soft=True)
    dry = mix((w, 0, 0.8), (swell, 0, 0.7), (spark, 0.55, 0.3), dur=D)
    return _verb(dry, 0.6, 0.35, tone=4500, tail=0.2)


@sound("GhostHooves", loop=True, length=1.6)
def ghost_hooves(v, rng):
    """Galloping hoofbeats, triplet pattern, soft and reverby, over a ghostly air. Circular."""
    P = 1.6
    y = _z(P)
    cyc = 0.4
    for c in range(4):
        for j, off in enumerate((0.0, 0.085, 0.175)):
            d = 0.09
            hoof = sine(glide(110, 55, d, 0.5), d) * decay(d, 0.02) + _unit(_lp(noise(d, rng), 500)) * decay(d, 0.008) * 0.6
            g = (0.7, 0.8, 1.0)[j] * rng.uniform(0.85, 1)
            _put(y, hoof, n_of(0.12 + c * cyc + off), g)
    y = _unit(y)
    air = _unit(band_noise(P, rng, 300, 1600)) * _lfo_rand(P, rng, 4, 1, 0.4, 1.0)
    y = y * 0.85 + air * 0.12
    return _loop_out(_circ_verb(y, 0.9, 0.45, 2500))


@sound("SpiritBellow", length=1.4)
def spirit_bellow(v, rng):
    """A ghostly howl: FM voice with vibrato in a long reverb."""
    bd = 1.0
    f = vibrato(1.0, bd, rate=5.5, depth=0.04, delay=0.2) * glide(180, 118, bd, 1.3)
    idx = np.interp(_u(bd), [0, 0.3, 1], [2.0, 1.4, 0.7])
    voice = _fm_voice(f, bd, 2.0, idx, ((400, 150, 1.0), (900, 250, 0.6), (2200, 400, 0.3)))
    breath = _unit(band_noise(bd, rng, 300, 2000)) * 0.25
    e = _env(bd, 0.15, 0.6, 0.35)
    dry = (voice + breath) * e
    return _verb(_unit(dry), 1.0, 0.5, tone=3000, tail=0.4)


# =============================================================== Prism Supernova
@sound("GlassShatter", length=1.0)
def glass_shatter(v, rng):
    """Many short high resonant pings and a crack."""
    D = 0.85
    crack = _crack(rng, 0.03, 1000, 6500, 0.007)
    pings = _z(D)
    for _ in range(44):
        f = 2000 * 2 ** rng.uniform(0, 1.8)
        d = rng.uniform(0.02, 0.09)
        p = sine(f, d) * decay(d, d * 0.3)
        pos = n_of(rng.uniform() ** 2 * 0.55)
        k = min(len(p), len(pings) - pos)
        pings[pos:pos + k] += p[:k] * rng.uniform(0.3, 1)
    for _ in range(6):
        f = rng.uniform(800, 2000)
        d = rng.uniform(0.06, 0.14)
        p = _ping(f, d, GLASS)
        pos = n_of(rng.uniform(0.05, 0.6))
        k = min(len(p), len(pings) - pos)
        pings[pos:pos + k] += p[:k] * 0.6
    dry = mix((crack, 0, 1.0), (_unit(pings), 0, 0.8), dur=D)
    return _verb(dry, 0.35, 0.3, tone=6000, tail=0.15)


@sound("LighthouseSweep", variants=3, length=0.8)
def lighthouse_sweep(v, rng):
    """A passing filtered swell; each variant a major third higher."""
    D = 0.7
    r = 2 ** (4 * v / 12)
    u = _u(D)
    bellc = np.exp(-((u - 0.45) / 0.22) ** 2)
    path = 600 * r * (2400 / 600) ** np.sin(math.pi * np.clip(u / 0.9, 0, 1))
    sweep = _sweep_noise(D, rng, path, 0.4) * bellc
    f0 = note("C5") * r
    tone = (sine(glide(f0 * 1.04, f0 * 0.95, D), D) + 0.4 * sine(glide(f0 * 2.08, f0 * 1.9, D), D)) * bellc
    dry = mix((sweep, 0, 0.8), (tone, 0, 0.5), dur=D)
    return _verb(dry, 0.3, 0.25, tone=5000, tail=0.1)


@sound("GemCrown", length=1.6)
def gem_crown(v, rng):
    """Seven-note ascending bell arpeggio."""
    D = 1.4
    out = _z(D)
    for i in range(7):
        p = _ping(scale_note(C6, i), 1.0 if i == 6 else 0.8, CRYSTAL, 0.75 + 0.04 * i)
        pos = n_of(i * 0.125)
        k = min(len(p), len(out) - pos)
        out[pos:pos + k] += p[:k]
    spark = _sparkles(rng, 0.5, 8, note("C8"), note("G8"), ping=0.15)
    dry = mix(_unit(out), (spark, 0.8, 0.3), dur=D)
    return _verb(dry, 0.6, 0.35, tone=6000, tail=0.2)


# =============================================================== Stormbreaker
@sound("StormRoll", loop=True, length=4.0)
def storm_roll(v, rng):
    """Rolling thunder: brown noise swells. Circular."""
    P = 4.0
    low = _unit(_lp(_tilt_noise(P, rng, 2), 220)) * _lfo_rand(P, rng, 6, 1, 0.3, 1.0) ** 1.5
    mid = _unit(band_noise(P, rng, 150, 900)) * _lfo_rand(P, rng, 8, 1, 0.0, 1.0) ** 2.5
    crackle = _unit(band_noise(P, rng, 600, 2500)) * _lfo_rand(P, rng, 12, 1, 0.0, 1.0) ** 4
    y = _unit(low) * 0.9 + mid * 0.3 + crackle * 0.12
    return _loop_out(y)


@sound("IceCrack", length=0.8)
def ice_crack(v, rng):
    """A sharp crack and an icy high ring."""
    D = 0.65
    snap = _unit(_hp(noise(0.006, rng), 1500)) * decay(0.006, 0.002)
    crack = _crack(rng, 0.02, 2000, 7000, 0.005)
    micro = _z(0.15)
    for tt in (0.025, 0.055, 0.092):
        c = _crack(rng, 0.01, 1500, 6000, 0.003)
        pos = n_of(tt + rng.uniform(-0.005, 0.005))
        micro[pos:pos + len(c)] += c * rng.uniform(0.3, 0.6)
    ring = _z(D)
    for f0 in (3200, 3900, 4700, 5500):
        ring += sine(f0 * rng.uniform(0.99, 1.01), D, phase=rng.uniform(0, TAU)) * decay(D, 0.16 * rng.uniform(0.7, 1.2))
    ring = _unit(ring)
    hiss = _unit(band_noise(D, rng, 3500, 6000)) * decay(D, 0.08)
    dry = mix((snap, 0, 1.0), (crack, 0, 1.0), (micro, 0, 0.8), (ring, 0.003, 0.45), (hiss, 0, 0.35), dur=D)
    return _verb(dry, 0.4, 0.3, tone=6000, tail=0.15)


@sound("ThunderPunch", length=1.2)
def thunder_punch(v, rng):
    """Fist impact, then thunder."""
    D = 1.05
    sub = _sub(0.25, 140, 50, 0.07)
    punch = _unit(band_noise(0.12, rng, 120, 500)) * decay(0.12, 0.03)
    crack = _crack(rng, 0.03, 800, 4000, 0.008)
    swell = _unit(np.abs(_lp(noise(D, rng), 6))) * 0.6 + 0.4
    thunder = _unit(_lp(_tilt_noise(D, rng, 2), 300)) * decay(D, 0.35) * swell
    thunder = _unit(thunder) * np.clip((t(D) - 0.04) / 0.08, 0, 1)
    dry = mix(sub, (punch, 0, 0.9), (crack, 0, 0.8), (thunder, 0, 0.8), dur=D)
    dry = np.tanh(dry * 1.2)
    return _verb(dry, 0.5, 0.3, tone=3000, tail=0.15)


# =============================================================== Phoenix Rebirth
@sound("FireWhoosh", length=0.8)
def fire_whoosh(v, rng):
    """Noise through a sweeping lowpass, with crackle."""
    D = 0.7
    u = _u(D)
    fc = np.where(u < 0.4, 300 * (4500 / 300) ** (u / 0.4), 4500 * (900 / 4500) ** ((u - 0.4) / 0.6))
    amp = np.where(u < 0.4, (u / 0.4) ** 1.6, ((1 - u) / 0.6) ** 1.5)
    w = _unit(sweep_lowpass(_tilt_noise(D, rng, 0.6), fc, q=1.2, blocks=48)) * amp
    pops = _z(D)
    for _ in range(14):
        d = rng.uniform(0.004, 0.015)
        c = _crack(rng, d, 1200, 5000, d / 3)
        pos = n_of(rng.uniform(0.08, 0.62))
        pops[pos:pos + len(c)] += c * rng.uniform(0.3, 1)
    low = _unit(_lp(noise(D, rng), 150)) * amp
    dry = mix((w, 0, 0.9), (pops, 0, 0.5), (low, 0, 0.5), dur=D)
    dry[: n_of(0.01)] += _crack(rng, 0.01, 600, 3000, 0.003) * 0.25
    return _verb(dry, 0.25, 0.2, tone=4000, tail=0.1)


@sound("CharCrackle", loop=True, length=2.0)
def char_crackle(v, rng):
    """Fire crackle: random short pops over a flickering roar. Circular."""
    P = 2.0
    y = _z(P)
    for _ in range(int(32 * P)):
        d = rng.uniform(0.003, 0.02)
        lo = rng.choice([300, 900, 1500])
        c = _crack(rng, d, lo, lo * 4, d / 3)
        _put(y, c, rng.integers(0, len(y)), rng.uniform(0.2, 1) ** 1.5)
    pops = _unit(y)
    roar = _unit(_lp(_tilt_noise(P, rng, 1.2), 1200)) * _lfo_rand(P, rng, 16, 1, 0.45, 1.0)
    y = pops * 0.7 + _unit(roar) * 0.5
    return _loop_out(y)


@sound("WingFlap", variants=3, length=0.5)
def wing_flap(v, rng):
    """One wing beat: an air whoosh with a soft slap at the bottom of the stroke."""
    D = 0.5 + 0.03 * v
    peak = (0.38, 0.5, 0.3)[v]
    sc = 2 ** (-0.18 * v)
    w = _whoosh(D, rng, 220 * sc, 1500 * sc, 250 * sc, peak=peak, width=0.55, curve=1.6, fall=1.8)
    slap = _unit(_lp(noise(0.05, rng), 900 * sc)) * decay(0.05, 0.012)
    thump = _sub(0.08, 180 * sc, 90 * sc, 0.02)
    dry = mix((w, 0, 1.0), (slap, D * peak - 0.01, 0.6), (thump, D * peak - 0.01, 0.5), dur=D)
    return dry


@sound("SunDive", length=1.6)
def sun_dive(v, rng):
    """A choir-like swell: detuned G major voices with formants, rising to a peak."""
    D = 1.45
    ch = _z(D)
    for nm, g in (("G3", 1.0), ("B3", 0.7), ("D4", 0.8), ("G4", 0.7), ("B4", 0.5), ("D5", 0.45), ("G5", 0.3)):
        f0 = note(nm)
        for d in (-0.005, 0.0, 0.005):
            f = vibrato(f0 * (1 + d), D, rate=rng.uniform(4.8, 5.6), depth=0.007, delay=0.5)
            ch += softsaw(f, D, 14) * g * rng.uniform(0.8, 1)
    ch = _formant(ch, ((600, 180, 1.0), (1100, 250, 0.7), (2600, 400, 0.35)), 0.08)
    ch = _unit(_lp(ch, 5000))
    e = np.interp(_u(D), [0, 0.86, 0.92, 1.0], [0.04, 1.0, 0.9, 0.0]) ** 1.5
    shim = _air(rng, D, 2500, 6, 1.2, 0.4) * np.interp(_u(D), [0, 0.6, 0.86, 1.0], [0, 0.0, 1.0, 0.0])
    dry = ch * e + shim * 0.2
    return _verb(dry, 0.5, 0.35, tone=4500, tail=0.15)


@sound("EmberSparkle", length=1.4)
def ember_sparkle(v, rng):
    """Rising sparkles."""
    D = 1.2
    spark = _sparkles(rng, D, 36, C6, note("C8"), bias=0.3, rise=0.8, ping=0.18)
    air = _sweep_noise(D, rng, glide(1500, 6000, D), 0.6) * np.interp(_u(D), [0, 0.7, 1], [0.3, 1.0, 0.0])
    dry = mix(spark, (air, 0, 0.18), dur=D)
    return _verb(dry, 0.5, 0.35, tone=6500, tail=0.2)


# =============================================================== Astral Ascension
@sound("StepChime", variants=8, length=0.5)
def step_chime(v, rng):
    """One bell note per variant: degree v of the major pentatonic from C5."""
    f = scale_note(C5, v)
    p = mix(_ping(f, 0.42, CRYSTAL), (_ping(f * 2, 0.3, GLASS, 0.2), 0, 1))
    return _verb(p, 0.3, 0.25, tone=6000, tail=0.08)


@sound("StarMapResolve", length=1.8)
def star_map_resolve(v, rng):
    """A suspended chord that resolves, with shimmer."""
    D = 1.55
    rs = 0.7
    out = _z(D)

    def voice(f0, t0, t1, g):
        d = t1 - t0
        x = (sine(f0, d) + 0.25 * sine(f0 * 2, d) + 0.1 * sine(f0 * 3, d)) * g
        a = n_of(0.08)
        x[:a] *= np.linspace(0, 1, a)
        r = n_of(0.06)
        x[-r:] *= np.linspace(1, 0, r)
        pos = n_of(t0)
        k = min(len(x), len(out) - pos)
        out[pos:pos + k] += x[:k]

    for nm, g in (("C5", 0.9), ("G5", 0.7), ("C6", 0.6)):
        voice(note(nm), 0.0, rs + 0.06, g)
    voice(note("F5"), 0.0, rs + 0.06, 0.8)
    for nm, g in (("C5", 0.9), ("E5", 0.8), ("G5", 0.7), ("C6", 0.6)):
        x = (sine(note(nm), D - rs) + 0.25 * sine(note(nm) * 2, D - rs)) * g
        a = n_of(0.03)
        x[:a] *= np.linspace(0, 1, a)
        x *= decay(D - rs, 0.35)
        pos = n_of(rs)
        out[pos:pos + len(x)] += x
    out[: n_of(0.004)] *= np.linspace(0, 1, n_of(0.004))
    out[: n_of(0.3)] += _unit(band_noise(0.3, rng, 1500, 4000)) * 0.03
    ch = _ping(note("E6"), 0.7, CRYSTAL)
    spark = _sparkles(rng, 0.7, 14, note("C7"), note("C8"), ping=0.18, soft=True)
    dry = mix(_unit(out), (ch, rs, 0.6), (spark, rs + 0.05, 0.35), dur=D)
    return _verb(dry, 0.9, 0.4, tone=5500, tail=0.25)


@sound("FeatherLand", length=0.7)
def feather_land(v, rng):
    """A very soft landing puff and a tiny chime."""
    D = 0.6
    puff = _unit(band_noise(0.3, rng, 150, 900)) * np.clip(t(0.3) / 0.018, 0, 1) * decay(0.3, 0.07)
    tick = _unit(_lp(noise(0.02, rng), 1200)) * decay(0.02, 0.004)
    ch = chime(note("E7"), 0.5)
    dry = mix((puff, 0, 0.8), (tick, 0, 0.35), (ch, 0.04, 0.35), dur=D)
    return _verb(dry, 0.3, 0.3, tone=5000, tail=0.1)


# =============================================================== Chrono Rift
@sound("ClockTick", loop=True, length=1.0)
def clock_tick(v, rng):
    """Tick, tock: two ticks per second over a faint mechanism whirr. Circular."""
    P = 1.0
    y = _z(P)

    def tick(fres, flo, fhi, g):
        d = 0.08
        c = _crack(rng, 0.004, flo, fhi, 0.0012)
        res = (sine(fres, d) * decay(d, 0.014) + 0.5 * sine(fres * 1.7, d) * decay(d, 0.008))
        x = _z(d)
        x[: len(c)] += c
        x += res * 0.8
        return _unit(x) * g

    _put(y, tick(1900, 2500, 6000, 1.0), n_of(0.2))
    _put(y, tick(1300, 1500, 4500, 0.8), n_of(0.7))
    whirr = _unit(_lp(_tilt_noise(P, rng, 1), 350)) * 0.05
    y = y + whirr
    return _loop_out(_circ_verb(y, 0.35, 0.2, 4000))


@sound("ReverseWhoosh", length=0.8)
def reverse_whoosh(v, rng):
    """A whoosh played backwards: quiet to loud, stops dead."""
    D = 0.8
    w = _whoosh(0.72, rng, 300, 2800, 400, peak=0.28, width=0.5)
    w = reverb(_pad(w, 0.08), 0.45, 0.5, tone=4500)
    r = reverse(w)
    floor = _unit(band_noise(D, rng, 500, 3000)) * _ramp(D, 0.04, 0.0, 1)
    out = mix(r, floor, dur=D)
    return fade(out, 0, 0.003)


@sound("Rewind", length=1.4)
def rewind(v, rng):
    """Tape rewind: fast rising chatter and a pitch sweep, then the stop clunk."""
    D = 1.4
    run = 1.22
    rate = glide(9, 48, run, 0.8)
    ph = TAU * np.cumsum(rate) / SR
    pulse = (0.5 + 0.5 * np.sin(ph)) ** 6
    chatter = _unit(band_noise(run, rng, 700, 3500)) * (0.25 + 0.75 * pulse)
    f = vibrato(1.0, run, 7.0, 0.03) * glide(260, 1900, run, 0.9)
    tone = softsaw(f, run, 6) * 0.6 + fm(f * 1.01, f * 2.0, 0.8, run) * 0.4
    tone = _unit(_lp(tone, 4000)) * (0.6 + 0.4 * pulse)
    e = _ramp(run, 0.35, 1.0, 0.7)
    body = (chatter * 0.6 + tone * 0.6) * e
    body[-n_of(0.01):] *= np.linspace(1, 0.3, n_of(0.01))
    clunk = mix(_sub(0.08, 220, 90, 0.02), (_unit(_lp(noise(0.06, rng), 1500)) * decay(0.06, 0.01), 0, 0.8))
    flutter = _unit(band_noise(0.12, rng, 1500, 4000)) * decay(0.12, 0.03)
    dry = mix(body, (clunk, run, 0.9), (flutter, run, 0.3), dur=D - 0.08)
    return _verb(dry, 0.25, 0.2, tone=4000, tail=0.08)


@sound("GlassBreak", length=1.0)
def glass_break(v, rng):
    """One big pane: a heavy crack and falling shards."""
    D = 0.85
    crack = _crack(rng, 0.05, 400, 5000, 0.012)
    whump = _sub(0.12, 160, 70, 0.03)
    shards = _z(D)
    for _ in range(26):
        f = 1000 * 2 ** rng.uniform(0, 2.2)
        d = rng.uniform(0.04, 0.15)
        p = _ping(f, d, GLASS)
        pos = n_of(0.08 + rng.beta(1.3, 2.2) * 0.62)
        k = min(len(p), len(shards) - pos)
        shards[pos:pos + k] += p[:k] * rng.uniform(0.3, 1)
    for _ in range(8):
        f = rng.uniform(4500, 7000)
        d = rng.uniform(0.02, 0.06)
        p = sine(f, d) * decay(d, d * 0.3)
        pos = n_of(rng.uniform(0.0, 0.5))
        k = min(len(p), len(shards) - pos)
        shards[pos:pos + k] += p[:k] * rng.uniform(0.3, 0.8)
    dry = mix((crack, 0, 1.0), (whump, 0, 0.7), (_unit(shards), 0, 0.75), dur=D)
    return _verb(dry, 0.4, 0.3, tone=5500, tail=0.15)
