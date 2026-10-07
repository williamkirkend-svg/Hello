#!/usr/bin/env python3
"""
recipes_game.py -- the game-side cues of the Farm Lasso sound pack (docs/sound-pitch.md section 3.1):
music and ambience, the 24 animal calls (+ AnimalGeneric), the lasso loop, menus and footsteps.
The celebration cues live in recipes_celebration.py.

Every recipe follows the synth.py contract: @sound(...) on   def fn(v, rng) -> float32 array   (mono 1-D, or (2, n)
for stereo). Nothing here is normalised (the builder does that) and the builder also trims silent heads, fades the
tail and crossfades the last 10 percent of a loop into its head.

Loops are rendered as one exact circular period P (events wrap around the end, filters are FFT-circular, LFOs make a
whole number of cycles) followed by the first P/9 of the same material again (`loop_ready`). The builder's crossfade
then blends identical material, so after it removes that tenth the file is exactly one seamless period.

Style (pitch section 3): playful, punchy, satisfying. Three layers per hit (sub thump, transient, air tail), a pitch
bend on every pop, G major pentatonic, rising pitch means progress, nothing harsh above 8 kHz.
"""
import math

import numpy as np

import synth
from synth import (SR, TAU, sound, t, n_of, sine, tri, softsaw, square, noise, env, adsr, decay, glide, smooth,
                   vibrato, biquad, lowpass, highpass, bandpass, sweep_lowpass, fft_shape, band_noise, reverb, pluck,
                   kick, click, note, semis, scale_note, bell, chime, mix, fade, stereo, pan, place)

G4 = note("G4")  # the key: G major pentatonic from G4 (degree 0)


# =============================================================================================== helpers
def deg(d, root=G4):
    """Pentatonic degree -> Hz (0 = G4, 5 = G5, 8 = D6, 10 = G6, 13 = D7)."""
    return scale_note(root, d)


def penv(points, dur):
    """Pitch envelope: exponential interpolation of [(time, hz), ...] over dur."""
    xs = np.array([p[0] for p in points], dtype=np.float64)
    ys = np.log(np.array([p[1] for p in points], dtype=np.float64))
    return np.exp(np.interp(t(dur).astype(np.float64), xs, ys))


def soft_lp(x, fc=7800.0, order=4):
    """Gentle FFT lowpass (keeps everything under the 8 kHz brief without a ringing brick wall)."""
    return fft_shape(np.asarray(x, dtype=np.float32), lambda f: 1 / np.sqrt(1 + (f / fc) ** (2 * order)))


def tilt_noise(dur, rng, lo, hi, slope_db_oct=0.0):
    """Band noise lo..hi with a spectral tilt (dB per octave; -3 = pink-ish, -6 = brown-ish). FFT: circular."""
    x = noise(dur, rng)

    def g(f):
        f = np.maximum(f, 1.0)
        band = np.clip((f - lo * 0.8) / (lo * 0.2 + 1e-9), 0, 1) * np.clip((hi * 1.2 - f) / (hi * 0.2 + 1e-9), 0, 1)
        return band * (f / max(lo, 20.0)) ** (slope_db_oct / 6.02)
    return fft_shape(x, g)


def slow_noise(dur, rng, fc):
    """A smooth random control signal (unit std, zero mean), FFT-circular so loops can use it."""
    r = fft_shape(noise(dur, rng), lambda f: 1 / (1 + (f / fc) ** 2))
    return (r / (np.std(r) + 1e-9)).astype(np.float32)


def sweep_biquad(x, kind, fc_curve, q=2.0, blocks=48):
    """Any biquad whose centre follows fc_curve, applied in warmed-up blocks (like synth.sweep_lowpass)."""
    x = np.asarray(x, dtype=np.float32)
    n = len(x)
    out = np.zeros(n, dtype=np.float32)
    edges = np.linspace(0, n, blocks + 1).astype(int)
    fc_curve = np.asarray(fc_curve, dtype=np.float64)
    for i in range(blocks):
        a, b = edges[i], edges[i + 1]
        if b <= a:
            continue
        a0 = max(0, a - 1500)
        fc = float(fc_curve[min(len(fc_curve) - 1, int((a + b) // 2 * len(fc_curve) / n))])
        out[a:b] = biquad(x[a0:b], kind, fc, q)[a - a0:]
    return out


def at(buf, x, t0, g=1.0):
    """Add x into buf at t0 seconds (clipped to buf). Returns buf."""
    o = n_of(t0)
    k = min(len(x), len(buf) - o)
    if k > 0:
        buf[o:o + k] += np.asarray(x[:k], dtype=np.float32) * g
    return buf


def circular(x, P):
    """Fold everything past P samples back onto the head (events near the end of a loop wrap around)."""
    x = np.asarray(x, dtype=np.float32)
    n = x.shape[-1]
    if n <= P:
        pad = [(0, 0)] * (x.ndim - 1) + [(0, P - n)]
        return np.pad(x, pad)
    out = x[..., :P].copy()
    rest = x[..., P:]
    while rest.shape[-1]:
        k = min(P, rest.shape[-1])
        out[..., :k] += rest[..., :k]
        rest = rest[..., k:]
    return out


def loop_ready(x):
    """x is exactly one circular period: append its first ninth so the builder's 10 percent crossfade is identity."""
    x = np.asarray(x, dtype=np.float32)
    k = int(round(x.shape[-1] / 9))
    return np.concatenate([x, x[..., :k]], axis=-1)


def circ_reverb(x, decay_s=1.2, mix_=0.2, tone=4000.0, seed=11, predelay=0.012):
    """Convolution reverb whose tail wraps around the end of the buffer (for seamless loops). Mono or (2, n)."""
    x = np.asarray(x, dtype=np.float32)
    if x.ndim == 2:
        return np.stack([circ_reverb(c, decay_s, mix_, tone, seed + i, predelay) for i, c in enumerate(x)])
    n = len(x)
    r = np.random.default_rng(seed)
    n_ir = min(n, n_of(decay_s * 1.2))
    ir = r.standard_normal(n_ir) * np.exp(-np.arange(n_ir) / (decay_s * SR / 4.6))
    ir = fft_shape(ir.astype(np.float32), lambda f: 1 / (1 + (f / tone) ** 2))
    ir = np.concatenate([np.zeros(n_of(predelay)), ir])[:n]
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = np.fft.irfft(np.fft.rfft(x.astype(np.float64)) * np.fft.rfft(ir, n), n)
    wet *= 0.7 * math.sqrt(decay_s)
    return (x * (1 - mix_) + wet * mix_).astype(np.float32)


def vp(v, rng, spread=2.2):
    """Variant pitch factor: variant 0 a little low, 1 a little high (spread in semitones), plus a random hair."""
    return 2 ** (((v - 0.5) * spread + rng.uniform(-0.3, 0.3)) / 12)


def fade_out(x, frac=0.25):
    """Fade the last `frac` of x to zero (tails end at silence instead of being cut by the builder)."""
    x = np.asarray(x, dtype=np.float32).copy()
    k = max(2, int(len(x) * frac))
    x[-k:] *= np.linspace(1, 0, k, dtype=np.float32) ** 1.5
    return x


def ramp_in(x, ms=2.0):
    k = n_of(ms / 1000)
    x = np.asarray(x, dtype=np.float32).copy()
    x[:k] *= np.linspace(0, 1, k, dtype=np.float32)
    return x


# ------------------------------------------------------------------------------ the three layers of a hit
def thump(dur, f0=130.0, f1=45.0, rng=None, click_=0.0):
    return kick(dur, f0, f1, rng, click=click_)


def crack(rng, dur=0.06, lo=800.0, hi=6000.0, tau=None):
    return band_noise(dur, rng, lo, hi) * decay(dur, tau or dur / 4) * 2.5


def air(rng, dur=0.6, lo=2000.0, hi=7000.0, tau=None, start_ms=4.0):
    return fade_out(ramp_in(band_noise(dur, rng, lo, hi) * decay(dur, tau or dur / 3) * 2.0, start_ms), 0.3)


SOFT_BELL = ((1.0, 1.0, 1.0), (2.76, 0.4, 0.5), (5.4, 0.12, 0.3))


def ding(f, dur=0.4, g=1.0):
    return fade_out(bell(f, dur, partials=SOFT_BELL) * g, 0.3)


def tone_note(f, dur, rng, chime_g=1.0, pluck_g=0.5, bright=0.8, pick=0.15):
    """Playful melodic note: a chime plus a plucked string on top, with a tiny pick click."""
    x = chime(f, dur) * chime_g
    if pluck_g:
        x = x + pluck(f, dur, rng, bright, 0.995) * pluck_g
    if pick:
        x = mix(x, (click(rng, 0.006, 3000), 0, pick), dur=dur)
    return fade_out(x, 0.2)


def brass_note(f, dur, rng, a=0.012, r=0.12, lp=2800.0, vib=0.006):
    """Bright soft-saw 'toy brass' for fanfares."""
    fr = vibrato(f, dur, rate=5.5, depth=vib, delay=0.08)
    x = softsaw(fr, dur, 10) * adsr(dur, a, 0.05, 0.85, r)
    return lowpass(x, lp, 0.8)


def sparkle(rng, dur, lo_deg, hi_deg, count=10, root=G4, g=1.0, rise=True, spread=0.75, bell_dur=0.35):
    """A rain of tiny pentatonic bells over dur. rise=True climbs from lo_deg to hi_deg."""
    out = np.zeros(n_of(dur), dtype=np.float32)
    for i in range(count):
        tt = (i / max(1, count - 1)) * dur * spread + rng.uniform(0, 0.02)
        if rise:
            d = lo_deg + int(round((hi_deg - lo_deg) * i / max(1, count - 1))) + int(rng.integers(-1, 2))
        else:
            d = int(rng.integers(lo_deg, hi_deg + 1))
        d = int(np.clip(d, lo_deg, hi_deg))
        bd = min(bell_dur, dur - tt - 0.005)
        if bd > 0.02:
            at(out, ding(deg(d, root), bd), tt, rng.uniform(0.5, 1.0) * g)
    return fade_out(out, 0.15)


def tick(rng, f, dur=0.12, tau=0.03, click_f=4500.0, click_g=0.5, bend=0.9):
    """A short bright tick with a little upward pitch bend."""
    fr = glide(f * bend, f, dur, curve=0.3)
    x = sine(fr, dur) * decay(dur, tau) + 0.4 * sine(fr * 2, dur) * decay(dur, tau * 0.5)
    x = ramp_in(x, 1.5)
    return mix(x, (click(rng, 0.008, click_f), 0, click_g), dur=dur)


def pop(rng, f0=800.0, f1=180.0, dur=0.16, tau=0.04, click_g=0.6):
    """The cinch / bloop pop: a sine that drops in pitch fast, with a click on the front."""
    x = sine(glide(f0, f1, dur, curve=0.6), dur) * decay(dur, tau)
    x = ramp_in(x, 1.0)
    return mix(x, (click(rng, 0.01, 2500), 0, click_g), dur=dur)


def whoosh(rng, dur, lo=300.0, hi=6000.0, fc_points=((0, 900), (0.15, 4500), (1.0, 1200)), amp_points=None, q=1.0):
    """Noise through a swept bandpass with an amplitude envelope; fc_points / amp_points are in fractions of dur."""
    x = band_noise(dur, rng, lo, hi)
    fc = penv([(p[0] * dur, p[1]) for p in fc_points], dur)
    x = sweep_biquad(x, "bandpass", fc, q, blocks=40)
    amp_points = amp_points or ((0, 0), (0.08, 1), (0.35, 0.7), (1.0, 0))
    return x * env([(p[0] * dur, p[1]) for p in amp_points], dur) * 3.0


# ------------------------------------------------------------------------------ voices (animal calls)
def voice(f0, dur, rng, formants, breath=0.0, rough=0.0, rough_rate=40.0, harmonics=None, amp=None, trem=None):
    """A cartoon voice: band-limited pulse source (soft saw) with roughness (slow random AM), breath noise and
    a bank of formant bandpasses. formants: [(hz or hz-array, q, gain), ...]. trem: (rate, depth) tremolo."""
    n = n_of(dur)
    f0 = np.full(n, float(f0)) if np.isscalar(f0) else np.asarray(f0, dtype=np.float64)
    H = harmonics or int(np.clip(7000.0 / float(np.max(f0)), 3, 24))
    src = softsaw(f0, dur, H)
    if rough:
        src = src * (1 + rough * np.clip(slow_noise(dur, rng, rough_rate), -1.5, 1.5))
    if trem:
        src = src * (1 - trem[1] * 0.5 * (1 - np.cos(TAU * trem[0] * t(dur))))
    if breath:
        src = src + breath * band_noise(dur, rng, 600, 6000)
    out = np.zeros(n, dtype=np.float32)
    for fc, q, g in formants:
        if np.isscalar(fc):
            out += bandpass(src, fc, q) * g
        else:
            out += sweep_biquad(src, "bandpass", fc, q) * g
    if amp is not None:
        out = out * amp
    return out.astype(np.float32)


# =============================================================================================== music
BPM = 120.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
CHORDS = ["G", "G", "C", "D", "G", "Em", "C", "D"]
CHORD_BASS = {"G": ("G2", "D2"), "C": ("C3", "G2"), "D": ("D3", "A2"), "Em": ("E2", "B2")}
CHORD_STAB = {"G": ("G3", "B3", "D4"), "C": ("C4", "E4", "G4"), "D": ("D4", "F#4", "A4"), "Em": ("E3", "G3", "B3")}
# melody in pentatonic degrees from G4 per 8th note (None = rest); first pass A, second pass B (varied, higher)
MELODY_A = [
    [5, 5, 6, 5, 3, None, 2, 3],
    [5, 6, 7, 6, 5, None, 3, None],
    [4, 4, 5, 4, 2, None, 1, 2],
    [3, 4, 5, 4, 3, 2, None, None],
    [5, 5, 6, 5, 7, None, 6, 5],
    [4, None, 4, 5, 6, 5, 4, 3],
    [4, 5, 4, 2, 1, None, 2, 4],
    [3, None, 5, None, 7, 6, 5, 4],
]
MELODY_B = MELODY_A[:4] + [
    [5, 7, 8, 7, 5, None, 6, 7],
    [8, None, 7, 6, 5, 6, 7, 8],
    [9, 8, 7, 5, 4, None, 5, 7],
    [8, None, 7, None, 6, None, 3, 4],
]


@sound("MusicCountry", loop=True, stereo=True, length=32.0, file="music_countryside")
def music_country(v, rng):
    P = n_of(16 * BAR)  # 32 s
    tail = n_of(3.0)
    lead = np.zeros(P + tail, dtype=np.float32)
    bass = np.zeros(P + tail, dtype=np.float32)
    stabs = np.zeros(P + tail, dtype=np.float32)
    kickt = np.zeros(P + tail, dtype=np.float32)
    tamb = np.zeros(P + tail, dtype=np.float32)
    shaker = np.zeros(P + tail, dtype=np.float32)

    # lead: banjo-style plucks, 8ths, with a few hammer-on ornaments in the second pass
    for bar_i, bar in enumerate(MELODY_A + MELODY_B):
        for k, d in enumerate(bar):
            if d is None:
                continue
            t0 = bar_i * BAR + k * BEAT / 2 + rng.uniform(-0.003, 0.003)
            f = deg(d)
            g = 0.9 if k % 2 == 0 else 0.7
            x = pluck(f, 0.7, rng, bright=0.85, damp=0.992) * g
            at(lead, x, t0)
            at(lead, click(rng, 0.005, 3200), t0, 0.12)
            nxt = bar[k + 1] if k + 1 < len(bar) else None
            if bar_i >= 8 and nxt is None and rng.random() < 0.45:
                at(lead, pluck(deg(d + 1), 0.5, rng, bright=0.85, damp=0.992), t0 + BEAT / 4, 0.5)
    # bass: alternating root / fifth on beats 1 and 3, a sine under the pluck for warmth
    for bar_i in range(16):
        root, alt = CHORD_BASS[CHORDS[bar_i % 8]]
        for beat_i, nm in ((0, root), (2, alt)):
            t0 = bar_i * BAR + beat_i * BEAT
            f = note(nm)
            x = pluck(f, 0.95, rng, bright=0.25, damp=0.997) * 0.9
            x = x + sine(f, 0.95) * decay(0.95, 0.25) * 0.35
            at(bass, ramp_in(x, 3), t0)
        # chord stabs ("chick") on 2 and 4, strummed
        for beat_i in (1, 3):
            t0 = bar_i * BAR + beat_i * BEAT
            for j, nm in enumerate(CHORD_STAB[CHORDS[bar_i % 8]]):
                at(stabs, pluck(note(nm), 0.35, rng, bright=0.6, damp=0.99), t0 + j * 0.012, 0.55)
        # kick on 1 and 3, tambourine on 2 and 4, shaker 16ths
        for beat_i in range(4):
            t0 = bar_i * BAR + beat_i * BEAT
            if beat_i % 2 == 0:
                at(kickt, kick(0.22, 130, 48, rng, click=0.15), t0)
            else:
                jingle = band_noise(0.13, rng, 3000, 7500) * decay(0.13, 0.04)
                jingle *= 1 + 0.6 * np.sin(TAU * rng.uniform(50, 70) * t(0.13))
                body = band_noise(0.03, rng, 1000, 2500) * decay(0.03, 0.01)
                at(tamb, mix(jingle, (body, 0, 0.8), dur=0.13) * 2.5, t0)
            for s16 in range(4):
                acc = (0.45, 0.3, 0.9, 0.35)[s16] * rng.uniform(0.85, 1.1)
                sh = band_noise(0.06, rng, 2500, 7000) * env([(0, 0), (0.008, 1), (0.06, 0)], 0.06)
                at(shaker, sh * 2.5, t0 + s16 * BEAT / 4 + rng.uniform(-0.003, 0.003), acc)

    tracks = [(lead, 0.3, 0.55), (bass, 0.0, 0.7), (stabs, -0.25, 0.22), (kickt, 0.0, 0.5), (tamb, 0.45, 0.2),
              (shaker, -0.5, 0.16)]
    out = np.zeros((2, P), dtype=np.float32)
    for buf, p, g in tracks:
        out += pan(circular(buf, P), p) * g
    out = circ_reverb(out, decay_s=1.1, mix_=0.14, tone=3500.0, seed=5)
    return loop_ready(out)


# =============================================================================================== ambience
@sound("AmbBirds", loop=True, stereo=True, length=24.0, file="amb_birds")
def amb_birds(v, rng):
    P = n_of(24.0)
    L = np.zeros(P + n_of(2.0), dtype=np.float32)
    R = np.zeros(P + n_of(2.0), dtype=np.float32)

    def sparrow():
        out = np.zeros(n_of(0.6), dtype=np.float32)
        n = int(rng.integers(3, 6))
        f = rng.uniform(3000, 3600)
        for i in range(n):
            d = 0.045
            x = sine(glide(f * 0.9, f * 1.18, d, curve=0.6), d) * adsr(d, 0.004, 0.01, 0.8, 0.015)
            at(out, x, i * rng.uniform(0.065, 0.09))
        return out

    def thrush():
        d1, d2 = 0.22, 0.2
        f = rng.uniform(1900, 2300)
        a = sine(vibrato(glide(f * 1.08, f * 0.9, d1), d1, 6, 0.01), d1) * adsr(d1, 0.02, 0.05, 0.8, 0.06)
        b = sine(glide(f * 1.25, f * 1.02, d2), d2) * adsr(d2, 0.02, 0.05, 0.8, 0.06)
        return mix(a, (b, d1 + rng.uniform(0.05, 0.1)))

    def warbler():
        d = rng.uniform(0.3, 0.42)
        f = rng.uniform(2400, 2900)
        fr = f * (1 + 0.06 * np.sin(TAU * rng.uniform(18, 26) * t(d))) * np.linspace(1.0, 0.94, n_of(d))
        return sine(fr, d) * adsr(d, 0.03, 0.05, 0.9, 0.08)

    kinds = [sparrow, thrush, warbler]
    n_ev = 14
    times = np.sort(rng.uniform(0, 24.0, n_ev))
    for i, tt in enumerate(times):
        x = kinds[i % 3]() if i < 3 else kinds[int(rng.integers(0, 3))]()
        x = soft_lp(x, 7000)
        g = rng.uniform(0.35, 1.0)
        p = rng.uniform(-0.85, 0.85)
        a = (p + 1) / 2 * math.pi / 2
        at(L, x, tt, g * math.cos(a))
        at(R, x, tt, g * math.sin(a))
    out = np.stack([circular(L, P), circular(R, P)])
    out = np.roll(out, -n_of(max(0.0, float(times[0]) - 0.5)), axis=-1)  # a call near the top of the loop
    out = circ_reverb(out, decay_s=1.5, mix_=0.28, tone=4500.0, seed=21)
    return loop_ready(out)


@sound("AmbWind", loop=True, stereo=True, length=16.0, file="amb_wind")
def amb_wind(v, rng):
    P_s = 16.0
    tt = t(P_s)
    chans = []
    for ch, phase in ((0, 0.0), (1, 0.9)):
        base = tilt_noise(P_s, rng, 60, 1800, -4.0)
        bright = tilt_noise(P_s, rng, 400, 3500, -3.0)
        l1 = 0.5 - 0.5 * np.cos(TAU * 3 * tt / P_s + phase)        # 5.33 s swells
        l2 = 0.5 - 0.5 * np.cos(TAU * 2 * tt / P_s + phase * 1.7)  # 8 s undertow
        m = (0.6 * l1 + 0.4 * l2) ** 1.5
        amp = 0.3 + 0.7 * m
        x = base * amp + bright * (0.15 + 0.6 * m ** 2) * 0.6
        # a soft resonant whistle that rides the swell
        x += bandpass(bright, 420.0 + 40 * ch, 3.0) * m ** 2 * 0.8
        chans.append(x.astype(np.float32))
    return loop_ready(np.stack(chans))


@sound("AmbFountain", loop=True, length=12.0, file="amb_fountain")
def amb_fountain(v, rng):
    P_s = 12.0
    P = n_of(P_s)
    hiss = tilt_noise(P_s, rng, 900, 6500, -2.0) * (1 + 0.15 * slow_noise(P_s, rng, 0.7)) * 0.5
    buf = np.zeros(P + n_of(0.5), dtype=np.float32)
    # bubbles: little sines rising in pitch as they close
    for _ in range(int(18 * P_s)):
        d = rng.uniform(0.025, 0.07)
        f = math.exp(rng.uniform(math.log(500), math.log(2200)))
        x = sine(glide(f, f * 1.4, d, curve=0.8), d) * decay(d, d / 3)
        at(buf, ramp_in(x, 1.5), rng.uniform(0, P_s), rng.uniform(0.3, 1.0) * (900 / f) ** 0.4 * 0.5)
    # grains: short filtered splashes
    for _ in range(int(30 * P_s)):
        d = rng.uniform(0.02, 0.06)
        fc = math.exp(rng.uniform(math.log(800), math.log(3500)))
        x = band_noise(d, rng, fc * 0.6, fc * 1.5) * np.hanning(n_of(d))
        at(buf, x, rng.uniform(0, P_s), rng.uniform(0.3, 1.0) * 1.2)
    # the odd bigger splash
    for _ in range(8):
        d = rng.uniform(0.15, 0.25)
        x = band_noise(d, rng, 500, 4000) * env([(0, 0), (0.02, 1), (d, 0)], d)
        at(buf, x, rng.uniform(0, P_s), 0.9)
    out = circular(buf, P) + hiss
    return loop_ready(soft_lp(out, 7500))


# =============================================================================================== animals
def _animal(name, fn, variants=2):
    def wrapped(v, rng):
        return soft_lp(fn(v, rng), 7600)
    snake_file = "animal_" + synth.snake(name)
    sound("Animal" + name, variants=variants, file=snake_file)(wrapped)


def chick(v, rng):
    pf = vp(v, rng)

    def peep(f, d):
        fr = glide(f * 0.85, f * 1.05, d, curve=0.5)
        return (sine(fr, d) + 0.25 * sine(fr * 2, d)) * adsr(d, 0.008, 0.03, 0.7, 0.05)
    return mix((peep(2900 * pf, 0.11), 0), (peep(3300 * pf, 0.14), rng.uniform(0.15, 0.19)))


def puddle_duck(v, rng):
    pf = vp(v, rng)

    def quack(f, d):
        f0 = glide(f * 1.15, f * 0.8, d, curve=1.5)
        amp = adsr(d, 0.01, 0.05, 0.8, 0.06)
        return voice(f0, d, rng, [(900 * pf, 5, 1), (1900 * pf, 6, .7), (3100, 7, .3)], rough=0.5, rough_rate=60,
                     amp=amp)
    return mix((quack(300 * pf, 0.2), 0), (quack(280 * pf, 0.22), 0.3 + rng.uniform(-0.03, 0.04)))


def pig(v, rng):
    pf = vp(v, rng)
    d = 0.32
    f0 = penv([(0, 160), (0.08, 215), (0.25, 150), (d, 115)], d) * pf
    oink = voice(f0, d, rng, [(450 * pf, 6, 1), (1100 * pf, 5, .6), (2300, 6, .25)], rough=0.5, rough_rate=30,
                 breath=0.15, amp=adsr(d, 0.015, 0.06, 0.85, 0.1))
    dg = 0.3
    g0 = penv([(0, 105), (0.1, 95), (dg, 80)], dg) * pf
    grunt = voice(g0, dg, rng, [(400 * pf, 4, 1), (900, 5, .5)], rough=0.9, rough_rate=28, breath=0.25,
                  amp=adsr(dg, 0.02, 0.05, 0.8, 0.12), trem=(26, 0.5))
    return mix(oink, (grunt, d - 0.05 + rng.uniform(0, 0.03), 0.9))


def bunny(v, rng):
    pf = vp(v, rng, 2.0)
    d = 0.15
    fr = penv([(0, 2000), (0.05, 2500), (d, 2200)], d) * pf
    fr = fr * (1 + 0.03 * np.sin(TAU * 9 * t(d)))
    squeak = (sine(fr, d) + 0.2 * sine(fr * 2, d)) * adsr(d, 0.01, 0.03, 0.8, 0.05)
    out = np.zeros(n_of(0.46), dtype=np.float32)
    at(out, squeak, 0)
    for i, t0 in enumerate((0.21, 0.31)):
        ds = 0.055
        sn = band_noise(ds, rng, 2800, 6500) * env([(0, 0), (0.008, 1), (0.03, 0.5), (ds, 0)], ds)
        at(out, sn * 1.6, t0 + rng.uniform(-0.01, 0.01), 1.0 if i == 0 else 0.8)
    return out


def woolly_sheep(v, rng):
    pf = vp(v, rng)
    d = 0.8
    f0 = vibrato(230 * pf, d, rate=7.5, depth=0.045) * penv([(0, 1), (0.6, 1), (d, 0.9)], d)
    F1 = penv([(0, 300), (0.06, 650), (d, 600)], d) * pf
    return voice(f0, d, rng, [(F1, 5, 1), (1250 * pf, 6, .7), (2500, 7, .3)], rough=0.35, rough_rate=25, breath=0.1,
                 amp=adsr(d, 0.04, 0.1, 0.85, 0.2))


def billy_goat(v, rng):
    pf = vp(v, rng)
    d = 0.6
    f0 = vibrato(330 * pf, d, rate=12, depth=0.04) * penv([(0, 0.95), (0.08, 1.05), (d, 0.9)], d)
    return voice(f0, d, rng, [(800 * pf, 5, 1), (1500 * pf, 5, .8), (2900, 6, .4)], rough=0.5, rough_rate=50,
                 breath=0.12, amp=adsr(d, 0.02, 0.05, 0.9, 0.15), trem=(12, 0.6))


def dairy_cow(v, rng):
    pf = vp(v, rng)
    d = 1.2
    f0 = vibrato(1.0, d, rate=4, depth=0.015, delay=0.3) * penv([(0, 115), (0.15, 135), (0.7, 130), (d, 95)], d) * pf
    F1 = penv([(0, 250), (0.25, 380), (0.8, 420), (d, 300)], d) * pf
    F2 = penv([(0, 700), (0.3, 900), (d, 650)], d) * pf
    return voice(f0, d, rng, [(F1, 4, 1), (F2, 5, .5), (2000, 6, .12)], rough=0.25, rough_rate=20, breath=0.05,
                 harmonics=10, amp=adsr(d, 0.08, 0.2, 0.85, 0.35))


def llama(v, rng):
    pf = vp(v, rng)
    d = 0.8
    f0 = vibrato(240 * pf, d, rate=6.5, depth=0.02) * penv([(0, 0.97), (0.3, 1.03), (d, 0.95)], d)
    return voice(f0, d, rng, [(380 * pf, 6, 1), (1100 * pf, 7, .35), (2100, 8, .5)], rough=0.2, rough_rate=30,
                 breath=0.1, harmonics=8, amp=adsr(d, 0.05, 0.1, 0.9, 0.2), trem=(6.5, 0.35))


def _snort(rng, d=0.3, lp=900.0, flutter=28.0):
    x = lowpass(noise(d, rng), lp) * (1 + 0.9 * np.sin(TAU * flutter * t(d))) * adsr(d, 0.01, 0.05, 0.8, 0.12)
    return x * 2.5


def chestnut_horse(v, rng):
    pf = vp(v, rng)
    d = 0.75
    f0 = vibrato(1.0, d, rate=13, depth=0.06) * penv([(0, 950), (0.1, 1000), (0.45, 600), (d, 380)], d) * pf
    neigh = voice(f0, d, rng, [(1000 * pf, 4, 1), (2400 * pf, 5, .7), (3600, 6, .3)], rough=0.3, rough_rate=40,
                  breath=0.15, amp=adsr(d, 0.03, 0.1, 0.9, 0.2))
    return mix(neigh, (_snort(rng, 0.3, 900, 28 * pf), d + rng.uniform(0.0, 0.05), 0.6))


def highland_bull(v, rng):
    pf = vp(v, rng)
    d = 1.1
    f0 = penv([(0, 75), (0.2, 95), (0.8, 88), (d, 62)], d) * pf
    x = voice(f0, d, rng, [(220 * pf, 4, 1), (520 * pf, 5, .6), (1000, 6, .3)], rough=0.5, rough_rate=25, breath=0.08,
              harmonics=24, amp=adsr(d, 0.06, 0.15, 0.9, 0.3))
    return x + sine(f0, d) * adsr(d, 0.06, 0.15, 0.9, 0.3) * 0.08


def golden_rooster(v, rng):
    pf = vp(v, rng)
    syll = [((620, 700), 0.14, 0.04), ((740, 820), 0.1, 0.03), ((880, 980), 0.22, 0.02), ((1050, 700), 0.5, 0)]
    out = np.zeros(n_of(1.35), dtype=np.float32)
    t0 = 0.0
    for i, ((fa, fb), d, gap) in enumerate(syll):
        f0 = glide(fa * pf, fb * pf, d, curve=1.2 if i < 3 else 0.7)
        if i == 3:
            f0 = vibrato(1.0, d, rate=10, depth=0.03, delay=0.1) * f0
        x = voice(f0, d, rng, [(1300 * pf, 5, 1), (2600 * pf, 6, .6), (3800, 7, .25)], rough=0.35, rough_rate=60,
                  breath=0.15, amp=adsr(d, 0.015, 0.05, 0.9, 0.2 if i == 3 else 0.04))
        at(out, x, t0)
        t0 += d + gap + rng.uniform(0, 0.015)
    at(out, sparkle(rng, 0.4, 10, 13, count=5, g=0.12, bell_dur=0.3), 0.75)
    return out


def unicorn_pony(v, rng):
    pf = vp(v, rng)
    d = 0.4
    f0 = vibrato(1.0, d, rate=14, depth=0.05) * penv([(0, 1100), (0.08, 1200), (0.3, 800), (d, 600)], d) * pf
    neigh = voice(f0, d, rng, [(1200 * pf, 4, 1), (2900 * pf, 5, .6), (4200, 6, .25)], rough=0.25, rough_rate=45,
                  breath=0.12, amp=adsr(d, 0.02, 0.08, 0.9, 0.12))
    out = np.zeros(n_of(1.05), dtype=np.float32)
    at(out, neigh, 0)
    gl = 0.35
    at(out, sine(glide(deg(8), deg(13), gl, curve=0.8), gl) * decay(gl, 0.15), 0.3, 0.25)
    for i, dg in enumerate((8, 9, 10, 11, 12, 13)):
        at(out, ding(deg(dg), 0.4), 0.32 + i * 0.055, 0.3 + 0.08 * i)
    return out


def hen(v, rng):
    pf = vp(v, rng)
    out = np.zeros(n_of(0.55), dtype=np.float32)
    t0 = 0.0
    for i in range(3):
        d = 0.07 if i < 2 else 0.1
        f0 = glide(480 * pf, (330 if i < 2 else 290) * pf, d)
        x = voice(f0, d, rng, [(1400 * pf, 4, 1), (2500, 5, .5), (700 * pf, 5, .6)], rough=0.3, rough_rate=60,
                  breath=0.1, amp=adsr(d, 0.004, 0.02, 0.6, 0.03))
        at(out, mix(x, (click(rng, 0.006, 2500), 0, 0.3)), t0)
        t0 += 0.17 + rng.uniform(-0.02, 0.03)
    return out


def barn_cat(v, rng):
    pf = vp(v, rng)
    d = 0.7
    f0 = vibrato(1.0, d, rate=5, depth=0.015, delay=0.25) * penv([(0, 480), (0.15, 700), (0.4, 640), (d, 420)], d) * pf
    F1 = penv([(0, 500), (0.15, 900), (0.45, 850), (d, 500)], d) * pf
    F2 = penv([(0, 2200), (0.2, 2000), (0.45, 1400), (d, 900)], d) * pf
    return voice(f0, d, rng, [(F1, 5, 1), (F2, 6, .8), (3200, 7, .25)], rough=0.2, rough_rate=30, breath=0.12,
                 amp=adsr(d, 0.06, 0.1, 0.9, 0.2))


def goose(v, rng):
    pf = vp(v, rng)

    def honk(f, d):
        f0 = glide(f, f * 0.93, d)
        return voice(f0, d, rng, [(750 * pf, 5, 1), (1500 * pf, 5, .8), (2600, 6, .4)], rough=0.55, rough_rate=45,
                     breath=0.1, harmonics=20, amp=adsr(d, 0.015, 0.04, 0.9, 0.07))
    return mix(honk(320 * pf, 0.25), (honk(345 * pf, 0.28), 0.33 + rng.uniform(-0.02, 0.03)))


def sheepdog(v, rng):
    pf = vp(v, rng)

    def bark(f, d=0.11):
        f0 = penv([(0, 380), (0.03, 320), (d, 220)], d) * f / 380
        x = voice(f0, d, rng, [(650 * pf, 4, 1), (1300 * pf, 5, .7), (2500, 6, .35)], rough=0.5, rough_rate=60,
                  breath=0.2, harmonics=20, amp=adsr(d, 0.005, 0.03, 0.6, 0.05))
        return mix(x, (band_noise(0.02, rng, 800, 3000) * decay(0.02, 0.007), 0, 0.5))
    return mix(bark(380 * pf), (bark(400 * pf, 0.12), 0.2 + rng.uniform(-0.02, 0.03)))


def turkey(v, rng):
    pf = vp(v, rng)
    d = 0.75
    rate = rng.uniform(17, 21)
    f0 = 360 * pf * penv([(0, 1), (d, 0.8)], d) * (1 + 0.13 * np.sin(TAU * rate * t(d)))
    return voice(f0, d, rng, [(900 * pf, 4, 1), (1700 * pf, 5, .7), (2900, 6, .3)], rough=0.3, rough_rate=70,
                 breath=0.1, amp=adsr(d, 0.03, 0.1, 0.9, 0.2), trem=(rate, 0.55))


def donkey(v, rng):
    pf = vp(v, rng)
    d1 = 0.42
    f0 = penv([(0, 560), (0.15, 760), (d1, 820)], d1) * pf
    hee = voice(f0, d1, rng, [(2200 * pf, 5, 1), (1200 * pf, 6, .5), (3400, 7, .4)], breath=0.5, rough=0.2,
                rough_rate=40, amp=adsr(d1, 0.04, 0.1, 0.9, 0.1))
    d2 = 0.5
    g0 = penv([(0, 280), (0.1, 240), (d2, 140)], d2) * pf
    haw = voice(g0, d2, rng, [(700 * pf, 4, 1), (1200 * pf, 5, .7), (2400, 6, .3)], rough=0.5, rough_rate=30,
                breath=0.1, amp=adsr(d2, 0.02, 0.1, 0.85, 0.2))
    return mix(hee, (haw, d1 + rng.uniform(0, 0.03), 1.3))


def barn_owl(v, rng):
    pf = vp(v, rng)

    def hoo(f, d=0.28):
        fr = glide(f * 1.05, f * 0.95, d) * pf
        x = (sine(fr, d) + 0.15 * sine(fr * 2, d)) * adsr(d, 0.07, 0.1, 0.9, 0.1)
        br = bandpass(noise(d, rng), f * pf, 1.5) * adsr(d, 0.05, 0.1, 0.9, 0.1) * 2.0
        return x + br * 0.6
    return mix(hoo(420), (hoo(380, 0.32), 0.38 + rng.uniform(-0.02, 0.03)))


def peacock(v, rng):
    pf = vp(v, rng)
    d1 = 0.38
    f0 = vibrato(1.0, d1, rate=7, depth=0.02, delay=0.1) * penv([(0, 850), (0.12, 1150), (d1, 1100)], d1) * pf
    fm_ = [(1400 * pf, 4, 1), (2800 * pf, 5, .7), (4200, 6, .3)]
    a = voice(f0, d1, rng, fm_, rough=0.3, rough_rate=50, breath=0.15, amp=adsr(d1, 0.03, 0.05, 0.9, 0.1))
    d2 = 0.48
    g0 = vibrato(1.0, d2, rate=7, depth=0.025, delay=0.1) * penv([(0, 1350), (0.1, 1250), (d2, 750)], d2) * pf
    b = voice(g0, d2, rng, fm_, rough=0.3, rough_rate=50, breath=0.15, amp=adsr(d2, 0.02, 0.1, 0.9, 0.15))
    return mix(a, (b, d1 + rng.uniform(0.02, 0.06)))


def reindeer(v, rng):
    pf = vp(v, rng)
    d = 0.32
    f0 = penv([(0, 130), (0.1, 110), (d, 85)], d) * pf
    grunt = voice(f0, d, rng, [(400 * pf, 4, 1), (900 * pf, 5, .6), (1800, 6, .25)], rough=0.6, rough_rate=30,
                  breath=0.1, amp=adsr(d, 0.02, 0.08, 0.8, 0.1))
    out = np.zeros(n_of(0.95), dtype=np.float32)
    at(out, grunt, 0)
    for _ in range(6):
        f = rng.uniform(3200, 5200) * pf
        at(out, ding(f, 0.25, 0.3), rng.uniform(0.25, 0.68))
    return out


def red_fox(v, rng):
    pf = vp(v, rng)

    def yip(f, d=0.13):
        f0 = penv([(0, 700), (0.04, 900), (d, 520)], d) * f / 700
        return voice(f0, d, rng, [(1200 * pf, 4, 1), (2500 * pf, 5, .7), (3800, 6, .3)], rough=0.3, rough_rate=60,
                     breath=0.15, amp=adsr(d, 0.005, 0.03, 0.7, 0.05))
    return mix(yip(700 * pf), (yip(740 * pf), 0.19 + rng.uniform(-0.02, 0.03)))


def bison(v, rng):
    pf = vp(v, rng)
    d = 1.25
    f0 = penv([(0, 52), (0.3, 62), (1.0, 55), (d, 42)], d) * pf
    amp = adsr(d, 0.1, 0.2, 0.9, 0.35)
    x = voice(f0, d, rng, [(140 * pf, 3, 1), (380 * pf, 4, .6), (800, 5, .3)], rough=0.7, rough_rate=28,
              harmonics=30, amp=amp, trem=(14, 0.3))
    return x + sine(f0, d) * amp * 0.12


def ostrich(v, rng):
    pf = vp(v, rng)
    d = 1.1
    f0 = penv([(0, 68), (0.2, 74), (0.9, 66), (d, 55)], d) * pf
    amp = env([(0, 0), (0.05, 1), (0.15, 0.25), (0.2, 1), (0.3, 0.25), (0.36, 1), (0.9, 0.8), (d, 0)], d)
    src = softsaw(f0, d, 10)
    hollow = bandpass(src, 95 * pf, 12) * 3.0 + bandpass(src, 190 * pf, 8) * 0.6
    body = sine(f0, d) * 0.5 + sine(f0 * 2, d) * 0.15
    breath = lowpass(noise(d, rng), 400) * 0.5
    return (hollow + body + breath) * amp


def generic(v, rng):
    pairs = [(1800, 2400), (2100, 2600), (1600, 2200)]
    fa, fb = pairs[v % 3]
    k = rng.uniform(0.95, 1.05)
    out = np.zeros(n_of(0.32), dtype=np.float32)
    for i, f in enumerate((fa * k, fb * k)):
        d = 0.09
        x = (sine(glide(f * 0.9, f * 1.05, d, curve=0.5), d) + 0.2 * sine(glide(f * 1.8, f * 2.1, d), d))
        at(out, x * adsr(d, 0.006, 0.02, 0.75, 0.04), i * 0.13)
    return out


for _name, _fn in (("Chick", chick), ("PuddleDuck", puddle_duck), ("Pig", pig), ("Bunny", bunny),
                   ("WoollySheep", woolly_sheep), ("BillyGoat", billy_goat), ("DairyCow", dairy_cow), ("Llama", llama),
                   ("ChestnutHorse", chestnut_horse), ("HighlandBull", highland_bull), ("GoldenRooster", golden_rooster),
                   ("UnicornPony", unicorn_pony), ("Hen", hen), ("BarnCat", barn_cat), ("Goose", goose),
                   ("Sheepdog", sheepdog), ("Turkey", turkey), ("Donkey", donkey), ("BarnOwl", barn_owl),
                   ("Peacock", peacock), ("Reindeer", reindeer), ("RedFox", red_fox), ("Bison", bison),
                   ("Ostrich", ostrich)):
    _animal(_name, _fn)
_animal("Generic", generic, variants=3)


# =============================================================================================== the lasso loop
@sound("LassoCharge", loop=True, length=2.0, file="lasso_charge_loop")
def lasso_charge(v, rng):
    P_s = 2.0
    tt = t(P_s)
    l = 0.5 - 0.5 * np.cos(TAU * 3 * tt / P_s)  # three swishes per period
    dark = tilt_noise(P_s, rng, 250, 1500, -2)
    mid = tilt_noise(P_s, rng, 700, 3200, -1)
    bright = tilt_noise(P_s, rng, 1500, 6000, 0)
    x = dark * (1 - l) ** 2 + mid * 2 * l * (1 - l) + bright * l ** 2
    x = x * (0.25 + 0.75 * l ** 1.5)
    # a faint rope whir under it
    x = x + sine(170 * (1 + 0.04 * np.sin(TAU * 3 * tt / P_s)), P_s) * (0.03 + 0.05 * l)
    return loop_ready(x.astype(np.float32))


def _meter(name, f):
    sound(name, length=0.15, file="meter_" + name[5:].lower())(lambda v, rng: tick(rng, f, 0.15, 0.035, 4500, 0.5))


_meter("MeterGood", deg(5))      # G5
_meter("MeterPerfect", deg(7))   # B5, a third up
_meter("MeterMega", deg(8))      # D6, a third up again


def _sting(degrees, dur, spacing, sparkle_g=0.0):
    def fn(v, rng):
        out = np.zeros(n_of(dur), dtype=np.float32)
        for i, d in enumerate(degrees):
            at(out, tone_note(deg(d), min(0.5, dur - i * spacing), rng, 1.0, 0.6, 0.85), i * spacing, 0.8 + 0.1 * i)
        at(out, thump(0.2, 150, 55, rng, 0.1), 0, 0.5)
        at(out, air(rng, 0.3, 2500, 7000), 0, 0.25)
        if sparkle_g:
            at(out, sparkle(rng, dur - 0.3, 10, 14, count=8, g=sparkle_g), 0.3)
            at(out, air(rng, dur - 0.25, 3000, 7500, tau=0.3), 0.25, 0.4)
        return out
    return fn


sound("StingGood", length=0.6, file="sting_good")(_sting([5, 7], 0.6, 0.16))
sound("StingPerfect", length=0.8, file="sting_perfect")(_sting([5, 7, 8], 0.8, 0.13))
sound("StingMega", length=1.1, file="sting_mega")(_sting([5, 7, 8], 1.1, 0.11, sparkle_g=0.5))


@sound("Throw", variants=3, length=0.5, file="throw_whoosh")
def throw(v, rng):
    pf = (1.0, 0.85, 1.15)[v] * rng.uniform(0.96, 1.04)
    d = 0.5
    w = whoosh(rng, d, 300, 6500, fc_points=((0, 700 * pf), (0.12, 4200 * pf), (1.0, 900 * pf)),
               amp_points=((0, 0), (0.03, 1), (0.25, 0.75), (1.0, 0)), q=1.1)
    w = w * (1 + 0.25 * np.sin(TAU * 28 * pf * t(d)))
    return mix(w, (thump(0.18, 120, 60, rng), 0, 0.35), (air(rng, 0.35, 2500, 7000), 0.08, 0.3))


@sound("ThrowBig", length=0.9, file="throw_big")
def throw_big(v, rng):
    d = 0.9
    low = whoosh(rng, 0.6, 100, 1200, fc_points=((0, 180), (0.2, 650), (1.0, 150)),
                 amp_points=((0, 0), (0.06, 1), (0.4, 0.7), (1.0, 0)), q=0.9)
    return mix(low, (thump(0.35, 95, 38, rng, 0.1), 0, 0.8), (air(rng, 0.8, 1800, 6500, tau=0.3), 0.05, 0.35), dur=d)


@sound("RopeLand", length=0.3, file="rope_land")
def rope_land(v, rng):
    slap = mix(click(rng, 0.015, 2500), (crack(rng, 0.07, 500, 4500), 0, 0.8))
    rustle = band_noise(0.25, rng, 1000, 4500) * decay(0.25, 0.06) * 0.8
    return mix(slap, (thump(0.2, 160, 60, rng), 0, 0.7), (rustle, 0.01, 0.5), dur=0.3)


@sound("LuckTick", length=0.12, file="luck_tick")
def luck_tick(v, rng):
    return tick(rng, 1400, 0.12, 0.025, 5000, 0.4, bend=0.92)


def _luck_impact(tier, dur):
    def fn(v, rng):
        out = np.zeros(n_of(dur), dtype=np.float32)
        at(out, thump(min(dur, 0.45), 115 + 10 * tier, 42, rng, 0.08), 0, 1.0)
        at(out, sine(glide(220, 70, 0.12, 0.5), 0.12) * decay(0.12, 0.03), 0, 0.35)  # the knock that reads on phones
        if tier >= 1:
            at(out, crack(rng, 0.07, 700, 6000), 0, 1.0)
            at(out, click(rng, 0.01, 3000), 0, 0.6)
        if tier >= 2:
            at(out, ding(deg((7, 8)[tier - 2]), 0.75, 0.55), 0.005)
        if tier >= 3:
            at(out, sparkle(rng, 0.9, 8, 13, count=9, g=0.35, bell_dur=0.4), 0.08)
            at(out, air(rng, 1.0, 3000, 7500, tau=0.3), 0.02, 0.6)
        return soft_lp(out)
    return fn


for _i, _d in enumerate((0.5, 0.7, 0.9, 1.2)):
    sound(f"LuckImpact{_i + 1}", length=_d, file=f"luck_impact_{_i + 1}")(_luck_impact(_i, _d))


FANFARES = [  # (dur, [(degree, start, note_len)], sparkle_from or None)
    (0.8, [(5, 0, 0.3), (7, 0.25, 0.5)], None),
    (1.3, [(5, 0, 0.25), (7, 0.2, 0.25), (8, 0.4, 0.85)], None),
    (1.9, [(5, 0, 0.22), (7, 0.18, 0.22), (8, 0.36, 0.3), (10, 0.6, 1.2)], 0.65),
    (3.0, [(5, 0, 0.18), (6, 0.15, 0.18), (7, 0.3, 0.18), (8, 0.45, 0.3), (10, 0.7, 0.5), (13, 1.1, 1.8)], 1.1),
]


def _fanfare(i):
    dur, notes, sp = FANFARES[i]

    def fn(v, rng):
        out = np.zeros(n_of(dur), dtype=np.float32)
        for d, t0, ln in notes:
            f = deg(d)
            at(out, brass_note(f, ln, rng, r=min(0.4, ln * 0.4)), t0, 0.6)
            at(out, tone_note(f, min(0.6, dur - t0), rng, 0.6, 0.5, 0.85), t0, 0.7)
        last_d, last_t, last_ln = notes[-1]
        at(out, thump(0.3, 140, 50, rng, 0.1), 0, 0.7)
        if i >= 2:
            at(out, thump(0.3, 150, 50, rng, 0.1), last_t, 0.6)
            at(out, crack(rng, 0.06, 800, 6000), last_t, 0.5)
        if i == 3:  # the rainbow ending lands a fifth up on D7 with a sparkle rain
            at(out, brass_note(deg(10), 1.6, rng, r=0.6), last_t, 0.35)
            at(out, ding(deg(13), 1.5, 0.5), last_t)
        if sp is not None:
            at(out, sparkle(rng, dur - sp - 0.1, 10, 15, count=8 + 8 * i, g=0.4, spread=0.85), sp)
            at(out, air(rng, dur - sp, 3000, 7500, tau=0.35), sp, 0.5)
        at(out, air(rng, 0.3, 2500, 7000), 0, 0.3)
        return soft_lp(out)
    return fn


for _i in range(4):
    sound(f"Fanfare{_i + 1}", length=FANFARES[_i][0], file=f"fanfare_{_i + 1}")(_fanfare(_i))


@sound("Hooked", length=0.45, file="hooked")
def hooked(v, rng):
    snap = mix(click(rng, 0.012, 3200), (crack(rng, 0.035, 1500, 6500), 0, 1.0))
    d = 0.38
    fr = penv([(0, 230), (0.05, 160), (d, 105)], d) * (1 + 0.05 * np.sin(TAU * 18 * t(d)) * decay(d, 0.12))
    tug = lowpass(tri(fr, d), 1200) * adsr(d, 0.004, 0.08, 0.5, 0.15)
    return mix(snap, (tug, 0.015, 0.9), (thump(0.25, 110, 55, rng), 0.01, 0.6), dur=0.45)


@sound("TugLoop", loop=True, length=2.0, file="tug_loop")
def tug_loop(v, rng):
    P_s = 2.0
    tt = t(P_s)
    creak = tilt_noise(P_s, rng, 150, 900, -2)
    grain = np.clip(slow_noise(P_s, rng, 45), 0, None) ** 2  # stick-slip grains
    creak = creak * (0.25 + grain * 0.75)
    f = 85 * (1 + 0.025 * np.sin(TAU * 2 * tt / P_s)) * (1 + 0.01 * np.sin(TAU * 11 * tt / P_s))
    hum = (sine(f, P_s) + 0.5 * sine(f * 2, P_s) + 0.25 * sine(f * 3, P_s)) * (0.8 + 0.2 * np.sin(TAU * 4 * tt / P_s))
    strain = tilt_noise(P_s, rng, 1500, 5000, -3) * (0.3 + 0.7 * np.clip(slow_noise(P_s, rng, 3), 0, None))
    return loop_ready((creak * 1.6 + hum * 0.25 + strain * 0.35).astype(np.float32))


@sound("TugTick", variants=3, length=0.1, file="tug_tick")
def tug_tick(v, rng):
    f = deg((5, 6, 7)[v]) * rng.uniform(0.98, 1.02)
    return tick(rng, f, 0.1, 0.028, 3800, 0.45)


@sound("TugDanger", length=0.4, file="tug_danger")
def tug_danger(v, rng):
    d = 0.4
    fr = penv([(0, 330), (0.1, 310), (d, 235)], d)
    x = softsaw(fr, d, 8) * (1 - 0.35 * 0.5 * (1 - np.cos(TAU * 25 * t(d))))
    x = sweep_lowpass(x, penv([(0, 1800), (d, 500)], d), 1.2, blocks=24) * adsr(d, 0.01, 0.1, 0.8, 0.14)
    return mix(x, (thump(0.15, 100, 60, rng), 0, 0.25))


@sound("CatchPop", length=0.25, file="catch_pop")
def catch_pop(v, rng):
    p = pop(rng, 900, 180, 0.15, 0.035, 0.7)
    body = sine(glide(140, 90, 0.12), 0.12) * decay(0.12, 0.035)
    return mix(p, (body, 0, 0.5), (air(rng, 0.15, 3000, 7000, tau=0.03), 0, 0.3), dur=0.25)


@sound("CatchChime", length=0.9, file="catch_chime")
def catch_chime(v, rng):
    out = np.zeros(n_of(0.9), dtype=np.float32)
    for i, d in enumerate((5, 7, 8)):
        at(out, tone_note(deg(d), 0.7, rng, 1.0, 0.55, 0.85), i * 0.13, 0.8 + 0.1 * i)
    at(out, sparkle(rng, 0.55, 10, 13, count=6, g=0.35), 0.3)
    at(out, thump(0.2, 140, 55, rng), 0, 0.4)
    at(out, air(rng, 0.5, 3000, 7500, tau=0.15), 0.26, 0.3)
    return soft_lp(out)


RARE = [  # Common .. Secret: (dur, degrees, spacing)
    (0.5, [5], 0.1),
    (0.7, [5, 7], 0.11),
    (0.95, [5, 7, 8], 0.11),
    (1.25, [5, 7, 8, 10], 0.11),
    (1.6, [5, 6, 7, 8, 10], 0.1),
    (2.1, [5, 7, 8, 10, 12, 13], 0.1),
    (2.6, [5, 6, 7, 8, 9, 10, 12, 13], 0.09),
]


def _rare(i):
    dur, degrees, spacing = RARE[i]

    def fn(v, rng):
        out = np.zeros(n_of(dur), dtype=np.float32)
        at(out, pop(rng, 700 + 60 * i, 200, 0.14, 0.035, 0.5), 0, 0.5 + 0.08 * i)
        start = 0.06
        for k, d in enumerate(degrees):
            t0 = start + k * spacing
            ln = min(0.8 + 0.1 * i, dur - t0)
            at(out, tone_note(deg(d), ln, rng, 1.0, 0.5 if i >= 1 else 0.0, 0.85, pick=0.1 if i >= 1 else 0),
               t0, 0.7 + 0.04 * k)
        if i >= 2:
            at(out, air(rng, min(0.6, dur * 0.5), 2500, 7000, tau=0.12), start, 0.3)
        if i >= 3:
            at(out, thump(0.3, 130 + 10 * i, 48, rng, 0.08), 0, 0.6 + 0.08 * i)
        if i >= 4:
            last_t = start + (len(degrees) - 1) * spacing
            at(out, ding(deg(degrees[-1]), min(1.0, dur - last_t), 0.5), last_t)
            at(out, ding(deg(degrees[-1] + 5), min(0.9, dur - last_t), 0.25), last_t + 0.02)
        if i >= 5:
            sp0 = start + len(degrees) * spacing
            at(out, sparkle(rng, dur - sp0 - 0.1, 10, 15, count=6 + 6 * i, g=0.35, spread=0.85), sp0)
            at(out, air(rng, dur - sp0, 3000, 7500, tau=0.3), sp0, 0.45)
        if i == 6:  # Secret: a second arpeggio an octave down, slightly behind, and a soft pad under it all
            for k, d in enumerate(degrees):
                t0 = start + 0.045 + k * spacing
                at(out, chime(deg(d - 5), min(1.0, dur - t0)), t0, 0.35)
            pad_d = dur - 0.1
            pad = sum(lowpass(softsaw(deg(d), pad_d, 6), 1500) for d in (0, 2, 3)) * env(
                [(0, 0), (0.4, 1), (pad_d * 0.7, 0.8), (pad_d, 0)], pad_d)
            at(out, pad, 0.05, 0.12)
        x = soft_lp(out)
        if i >= 4:
            x = reverb(x, decay_s=0.8 + 0.3 * (i - 4), mix=0.12 + 0.05 * (i - 4), tone=4500.0)
            x = x[:n_of(dur)]
        return x
    return fn


for _i in range(7):
    sound(f"RareReveal{_i + 1}", length=RARE[_i][0], file=f"rare_reveal_{_i + 1}")(_rare(_i))


@sound("Escape", length=0.6, file="rope_slip")
def escape(v, rng):
    slip = whoosh(rng, 0.18, 800, 6500, fc_points=((0, 1200), (1.0, 4500)), amp_points=((0, 0), (0.1, 1), (1.0, 0)),
                  q=1.5)
    slip = slip * (1 + 0.5 * np.sin(TAU * 60 * t(0.18)))
    out = np.zeros(n_of(0.6), dtype=np.float32)
    at(out, slip, 0, 0.8)
    for k, (d, t0) in enumerate(((3, 0.16), (1, 0.34))):
        ln = 0.26
        fr = glide(deg(d), deg(d) * 0.94, ln, curve=1.5)
        x = lowpass(softsaw(fr, ln, 8), 1400) * adsr(ln, 0.01, 0.08, 0.8, 0.1)
        at(out, x, t0, 0.6)
    return out


@sound("BagFull", length=0.5, file="bag_full")
def bag_full(v, rng):
    out = np.zeros(n_of(0.5), dtype=np.float32)
    for f, t0, d in ((880, 0.0, 0.15), (660, 0.21, 0.24)):
        x = lowpass(softsaw(f, d, 6), 2500) * adsr(d, 0.006, 0.03, 0.85, 0.05)
        at(out, x, t0, 0.8)
    return out


@sound("SellShower", length=1.3, file="coin_shower")
def sell_shower(v, rng):
    dur = 1.3
    out = np.zeros(n_of(dur), dtype=np.float32)
    n = 18
    for i in range(n):
        u = i / (n - 1)
        t0 = 1.0 * (u ** 0.8) + rng.uniform(0, 0.015)
        d = 8 + int(round(5 * u)) + int(rng.integers(-1, 2))
        f = deg(int(np.clip(d, 8, 14)))
        coin = bell(f, min(0.35, dur - t0 - 0.01), partials=((1.0, 1.0, 1.0), (2.5, 0.5, 0.5), (4.1, 0.2, 0.3)))
        at(out, fade_out(coin, 0.3), t0, rng.uniform(0.55, 1.0) * (0.6 + 0.4 * u))
        at(out, click(rng, 0.006, 5000), t0, 0.3)
    at(out, air(rng, 0.42, 3500, 7500, tau=0.15), 0.85, 0.35)
    return soft_lp(out)


@sound("SellDing", length=0.7, file="register_ding")
def sell_ding(v, rng):
    out = np.zeros(n_of(0.7), dtype=np.float32)
    at(out, lowpass(noise(0.02, rng), 1800) * decay(0.02, 0.006) * 3, 0, 0.8)   # ka
    at(out, sine(glide(420, 300, 0.05), 0.05) * decay(0.05, 0.015), 0, 0.5)
    at(out, click(rng, 0.01, 3000), 0.045, 0.6)                                 # ching
    at(out, ding(deg(12), 0.62, 1.0), 0.05)
    at(out, ding(deg(9), 0.5, 0.35), 0.055)
    return soft_lp(out)


@sound("Buy", length=0.6, file="purchase_chime")
def buy(v, rng):
    out = np.zeros(n_of(0.6), dtype=np.float32)
    at(out, pop(rng, 600, 200, 0.1, 0.03, 0.4), 0, 0.4)
    at(out, tone_note(deg(8), 0.45, rng, 1.0, 0.5), 0.0, 0.8)
    at(out, tone_note(deg(10), 0.45, rng, 1.0, 0.5), 0.15, 0.9)
    at(out, sparkle(rng, 0.3, 12, 14, count=4, g=0.25), 0.28)
    return soft_lp(out)


@sound("Equip", length=0.25, file="equip_click")
def equip(v, rng):
    knock = sine(glide(380, 260, 0.05), 0.05) * decay(0.05, 0.012)
    sw = whoosh(rng, 0.18, 1000, 6000, fc_points=((0, 1500), (1.0, 4500)), amp_points=((0, 0), (0.3, 1), (1.0, 0)), q=1.3)
    return mix(click(rng, 0.012, 2600), (knock, 0, 0.7), (sw, 0.03, 0.45), dur=0.25)


@sound("NoCoins", length=0.35, file="error_buzz")
def no_coins(v, rng):
    d = 0.33
    x = softsaw(glide(115, 98, d), d, 10) * (1 - 0.5 * 0.5 * (1 - np.cos(TAU * 28 * t(d))))
    x = lowpass(x, 700, 0.9) * adsr(d, 0.01, 0.05, 0.8, 0.1)
    return x


@sound("QuestAccept", length=0.5, file="quest_accept")
def quest_accept(v, rng):
    out = np.zeros(n_of(0.5), dtype=np.float32)
    at(out, band_noise(0.08, rng, 2000, 6000) * env([(0, 0), (0.01, 1), (0.08, 0)], 0.08) * 2, 0, 0.35)
    at(out, tone_note(deg(3), 0.4, rng, 0.9, 0.6), 0.0, 0.8)
    at(out, tone_note(deg(5), 0.42, rng, 1.0, 0.6), 0.12, 0.9)
    return soft_lp(out)


@sound("QuestTick", length=0.12, file="quest_tick")
def quest_tick(v, rng):
    return tick(rng, deg(11), 0.12, 0.028, 3500, 0.3, bend=0.94)


@sound("QuestComplete", length=1.6, file="quest_complete")
def quest_complete(v, rng):
    dur = 1.6
    out = np.zeros(n_of(dur), dtype=np.float32)
    for k, d in enumerate((5, 7, 8, 10)):
        at(out, tone_note(deg(d), 0.6, rng, 1.0, 0.55), k * 0.13, 0.75 + 0.05 * k)
    at(out, thump(0.25, 140, 50, rng, 0.08), 0, 0.5)
    at(out, ding(deg(13), 0.9, 0.6), 0.6)
    at(out, tone_note(deg(10), 0.9, rng, 0.8, 0.3), 0.6, 0.6)
    at(out, sparkle(rng, 0.9, 10, 15, count=10, g=0.35, spread=0.8), 0.62)
    at(out, air(rng, 0.9, 3000, 7500, tau=0.3), 0.6, 0.4)
    return soft_lp(out)


@sound("HerdJoin", length=0.5, file="herd_join")
def herd_join(v, rng):
    d = 0.2
    bloop = (sine(glide(280, 640, d, curve=0.7), d) + 0.2 * sine(glide(560, 1280, d, curve=0.7), d))
    bloop = ramp_in(bloop * adsr(d, 0.004, 0.06, 0.5, 0.1), 1.5)
    out = np.zeros(n_of(0.5), dtype=np.float32)
    at(out, bloop, 0, 1.0)
    at(out, click(rng, 0.008, 2000), 0, 0.3)
    at(out, generic(0, rng), 0.2, 0.35)
    return soft_lp(out)


# =============================================================================================== menus
@sound("UIHover", length=0.06, file="ui_hover")
def ui_hover(v, rng):
    return tick(rng, 2400, 0.06, 0.012, 5000, 0.25, bend=0.95)


@sound("UIClick", variants=2, length=0.1, file="ui_click")
def ui_click(v, rng):
    f, cf = ((1100, 3000), (1450, 2400))[v]
    body = sine(glide(f * 1.1, f, 0.08), 0.08) * decay(0.08, 0.016 + 0.006 * v)
    return mix(click(rng, 0.01, cf), (body, 0, 0.6), dur=0.1)


@sound("PanelOpen", length=0.3, file="panel_open")
def panel_open(v, rng):
    d = 0.3
    w = whoosh(rng, d, 300, 6500, fc_points=((0, 500), (1.0, 5000)), amp_points=((0, 0), (0.25, 1), (0.8, 0.8), (1.0, 0)),
               q=1.2)
    return mix(w, (click(rng, 0.01, 2500), 0.22, 0.5), (sine(glide(500, 380, 0.05), 0.05) * decay(0.05, 0.015), 0.22, 0.4),
               dur=d)


@sound("PanelClose", length=0.3, file="panel_close")
def panel_close(v, rng):
    d = 0.3
    w = whoosh(rng, d, 300, 6500, fc_points=((0, 5000), (1.0, 500)), amp_points=((0, 0), (0.08, 1), (0.6, 0.6), (1.0, 0)),
               q=1.2)
    return mix(click(rng, 0.01, 2200), (sine(glide(420, 300, 0.05), 0.05) * decay(0.05, 0.015), 0, 0.4), (w, 0.01, 0.9),
               dur=d)


@sound("TabSwitch", length=0.12, file="tab_switch")
def tab_switch(v, rng):
    return mix(click(rng, 0.01, 3000), (chime(deg(12), 0.1) * decay(0.1, 0.03), 0.01, 0.5), dur=0.12)


# =============================================================================================== footsteps
def _step_pf(v, rng):
    return (0.92, 1.0, 1.06, 0.97)[v] * rng.uniform(0.97, 1.03)


@sound("StepGrass", variants=4, length=0.15, file="step_grass")
def step_grass(v, rng):
    pf = _step_pf(v, rng)
    out = np.zeros(n_of(0.15), dtype=np.float32)
    for i in range(3):
        d = rng.uniform(0.03, 0.05)
        x = tilt_noise(d, rng, 1200 * pf, 6500, -3) * env([(0, 0), (0.004, 1), (d, 0)], d)
        at(out, x * 3, (0, 0.025, 0.055)[i] + rng.uniform(0, 0.01), (1.0, 0.7, 0.45)[i])
    at(out, sine(110 * pf, 0.04) * decay(0.04, 0.012), 0, 0.25)
    return out


@sound("StepDirt", variants=4, length=0.15, file="step_dirt")
def step_dirt(v, rng):
    pf = _step_pf(v, rng)
    thud = thump(0.12, 130 * pf, 55 * pf, rng)
    grit = band_noise(0.07, rng, 1500, 5000) * np.abs(lowpass(noise(0.07, rng), 1200)) * decay(0.07, 0.025) * 12
    knock = bandpass(noise(0.03, rng), 400 * pf, 2.0) * decay(0.03, 0.01) * 3
    return mix(thud, (grit, 0.002, 0.6), (knock, 0, 0.5), dur=0.15)


@sound("StepStone", variants=4, length=0.15, file="step_stone")
def step_stone(v, rng):
    pf = _step_pf(v, rng)
    ring = bandpass(noise(0.13, rng), 2200 * pf, 25) * decay(0.13, 0.03) * 6
    grit = band_noise(0.04, rng, 2000, 6500) * decay(0.04, 0.012) * 2.5
    return mix(click(rng, 0.012, 3200 * pf), (ring, 0, 0.9), (thump(0.08, 200 * pf, 90 * pf, rng), 0, 0.35),
               (grit, 0, 0.4), dur=0.15)


@sound("StepWood", variants=4, length=0.15, file="step_wood")
def step_wood(v, rng):
    pf = _step_pf(v, rng)
    d = 0.13
    knock = sine(glide(190 * pf, 150 * pf, d), d) * decay(d, 0.03) + 0.5 * sine(430 * pf, d) * decay(d, 0.015)
    trans = lowpass(noise(0.02, rng), 1500) * decay(0.02, 0.006) * 3
    hollow = bandpass(noise(0.1, rng), 420 * pf, 8) * decay(0.1, 0.025) * 4
    return mix(ramp_in(knock, 1), (trans, 0, 0.8), (hollow, 0, 0.6), dur=0.15)
