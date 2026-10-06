#!/usr/bin/env python3
"""
paint_textures.py -- procedural VFX particle / beam textures for Roblox.

Re-run with:   python3 -I paint_textures.py

Writes 12 PNGs next to this file (RGB is pure white everywhere, the shape
lives in the alpha channel so Roblox can tint by Color) plus contact_sheet.png
(every texture over dark grey, once white and once tinted blue).
Everything is deterministic (fixed seeds).
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
MARGIN = 0.92            # 4 % margin -> nothing beyond this normalised radius
TINT = (60, 140, 255)    # blue used on the contact sheet to judge the alpha


# --------------------------------------------------------------- helpers
def coords(size):
    """Pixel-centre coordinates in [-1, 1]; X to the right, Y up."""
    t = ((np.arange(size) + 0.5) / size * 2 - 1).astype(np.float32)
    X = np.broadcast_to(t[None, :], (size, size)).copy()
    Y = np.broadcast_to(-t[:, None], (size, size)).copy()
    return X, Y


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def blur(a, sigma):
    """Gaussian blur (sigma in pixels), zero padded so nothing wraps around."""
    if sigma <= 0:
        return a
    p = int(math.ceil(sigma * 3))
    ap = np.pad(a, p)
    h, w = ap.shape
    fy = np.fft.fftfreq(h)
    fx = np.fft.rfftfreq(w)
    k = (np.exp(-2.0 * (np.pi * sigma * fy[:, None]) ** 2)
         * np.exp(-2.0 * (np.pi * sigma * fx[None, :]) ** 2))
    out = np.fft.irfft2(np.fft.rfft2(ap) * k, s=ap.shape)
    return out[p:p + a.shape[0], p:p + a.shape[1]].astype(np.float32)


def screen(*layers):
    out = np.zeros_like(layers[0])
    for l in layers:
        out = 1.0 - (1.0 - out) * (1.0 - np.clip(l, 0, 1))
    return out


def value_noise(size, period, rng):
    """Periodic value noise with quintic interpolation -> tiles perfectly."""
    lat = rng.random((period, period)).astype(np.float32)
    u = (np.arange(size) + 0.5) * period / size
    i0 = np.floor(u).astype(int) % period
    i1 = (i0 + 1) % period
    f = (u - np.floor(u)).astype(np.float32)
    s = f * f * f * (f * (f * 6 - 15) + 10)
    sx, sy = s[None, :], s[:, None]
    n00 = lat[i0[:, None], i0[None, :]]
    n01 = lat[i0[:, None], i1[None, :]]
    n10 = lat[i1[:, None], i0[None, :]]
    n11 = lat[i1[:, None], i1[None, :]]
    return (n00 * (1 - sx) + n01 * sx) * (1 - sy) + (n10 * (1 - sx) + n11 * sx) * sy


def fractal(size, rng, periods=(4, 8, 16, 32, 64), gain=0.5):
    """Tileable fractal (fBm) value noise in roughly [0, 1]."""
    total = np.zeros((size, size), np.float32)
    amp, norm = 1.0, 0.0
    for p in periods:
        total += amp * value_noise(size, p, rng)
        norm += amp
        amp *= gain
    return total / norm


def normalise(a):
    return (a - a.min()) / (a.max() - a.min() + 1e-9)


def sample_wrap(img, x, y):
    """Bilinear sample of img at float pixel coords, wrapping at the border."""
    h, w = img.shape
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx = (x - x0).astype(np.float32)
    fy = (y - y0).astype(np.float32)
    x0 %= w
    y0 %= h
    x1 = (x0 + 1) % w
    y1 = (y0 + 1) % h
    return ((img[y0, x0] * (1 - fx) + img[y0, x1] * fx) * (1 - fy)
            + (img[y1, x0] * (1 - fx) + img[y1, x1] * fx) * fy)


def edge_window(size, m):
    """1 inside, fading to 0 over the last m pixels before each edge."""
    i = np.arange(size) + 0.5
    d = np.minimum(i, size - i)
    w = smoothstep(0, m, d)
    return (w[:, None] * w[None, :]).astype(np.float32)


def downsample(a, size):
    return np.asarray(Image.fromarray(a.astype(np.float32)).resize((size, size), Image.BOX), np.float32)


class Canvas:
    """Supersampled anti-aliased line canvas; coordinates are final-image pixels."""

    def __init__(self, size, ss=4):
        self.size, self.ss = size, ss
        self.im = Image.new("L", (size * ss, size * ss), 0)
        self.d = ImageDraw.Draw(self.im)

    def _p(self, p):
        return (p[0] * self.ss, p[1] * self.ss)

    def _w(self, w):
        return max(1, int(round(w * self.ss)))

    def disc(self, c, r):
        x, y = self._p(c)
        r *= self.ss
        self.d.ellipse([x - r, y - r, x + r, y + r], fill=255)

    def line(self, a, b, w):
        self.d.line([self._p(a), self._p(b)], fill=255, width=self._w(w))
        self.disc(a, w / 2)
        self.disc(b, w / 2)

    def polyline(self, pts, w):
        for a, b in zip(pts[:-1], pts[1:]):
            self.line(a, b, w)

    def circle(self, c, r, w):
        x, y = self._p(c)
        r *= self.ss
        self.d.ellipse([x - r, y - r, x + r, y + r], outline=255, width=self._w(w))

    def arc(self, c, r, a0, a1, w):
        x, y = self._p(c)
        r *= self.ss
        self.d.arc([x - r, y - r, x + r, y + r], a0, a1, fill=255, width=self._w(w))

    def polygon(self, pts):
        self.d.polygon([self._p(p) for p in pts], fill=255)

    def render(self):
        im = self.im.resize((self.size, self.size), Image.LANCZOS)
        return np.asarray(im, dtype=np.float32) / 255.0


def poly_sdf(X, Y, pts):
    """Signed distance (positive inside) from every pixel to a closed polygon."""
    P = np.asarray(pts, np.float32)
    Q = np.roll(P, -1, axis=0)
    d2 = np.full(X.shape, np.inf, np.float32)
    inside = np.zeros(X.shape, bool)
    for (ax, ay), (bx, by) in zip(P, Q):
        ex, ey = bx - ax, by - ay
        ll = ex * ex + ey * ey + 1e-12
        t = np.clip(((X - ax) * ex + (Y - ay) * ey) / ll, 0, 1)
        dx, dy = X - (ax + t * ex), Y - (ay + t * ey)
        d2 = np.minimum(d2, dx * dx + dy * dy)
        if ay != by:
            cross = ((ay > Y) != (by > Y)) & (X < ex * (Y - ay) / (by - ay) + ax)
            inside ^= cross
    d = np.sqrt(d2)
    return np.where(inside, d, -d)


def save(name, alpha):
    a = np.clip(alpha, 0, 1).astype(np.float32)
    a8 = np.round(a * 255).astype(np.uint8)
    white = np.full(a.shape, 255, np.uint8)
    Image.fromarray(np.dstack([white, white, white, a8]), "RGBA").save(os.path.join(OUT, name))
    return a


# -------------------------------------------------------------- textures
def tex_glow_soft(size=512):
    X, Y = coords(size)
    r = np.hypot(X, Y)
    g = np.exp(-(r / 0.40) ** 2)
    win = np.clip(1 - (r / 0.90) ** 2, 0, 1) ** 1.5      # reaches exactly 0 at 90 %
    return g * win


def tex_ring_hard(size=512):
    X, Y = coords(size)
    r = np.hypot(X, Y)
    px = 2.0 / size
    R = 0.78
    inner = smoothstep(R - 0.10, R - 0.5 * px, r) ** 0.8  # short soft falloff inward
    outer = 1 - smoothstep(R, R + 1.5 * px, r)            # crisp outer lip
    main = inner * outer
    second = 0.25 * np.exp(-((r - 0.60) / 0.012) ** 2)    # faint secondary ring
    return np.maximum(main, second)


def tex_flame(size=512, seed=3):
    rng = np.random.default_rng(seed)
    X, Y = coords(size)
    y0, y1 = -0.88, 0.90
    v = np.clip((Y - y0) / (y1 - y0), 0, 1)               # 0 at base .. 1 at tip
    n = (fractal(size, rng, periods=(4, 8, 16, 32), gain=0.55) - 0.5) * 2.0

    def centre(vv):
        return 0.14 * vv ** 1.8 - 0.05 * np.sin(vv * np.pi)   # gentle lean to the right

    def halfwidth(vv):
        return 0.36 * (1 - vv ** 1.25) ** 0.75                 # wide base -> point

    def tongue(xc, w, amp, torn):
        w = np.maximum(w, 1e-4) * (1 + torn * n)              # noise tears the edge
        t = np.abs(X - xc) / w
        prof = np.exp(-0.5 * t ** 3) * np.clip(1 - t / 1.7, 0, 1) ** 0.5  # hot plateau, feathered sides
        return amp * prof

    layers = [tongue(centre(v), halfwidth(v), 1.0, 0.35 * (0.3 + 0.7 * v)) * (v < 1)]
    for (v0, side, ln, amp) in [(0.26, -1, 0.42, 0.95),       # licks peeling off the body
                                (0.46, 1, 0.38, 0.90),
                                (0.10, 1, 0.30, 0.85)]:
        s = (v - v0) / ln
        inside = (s >= 0) & (s <= 1)
        sc = np.clip(s, 0, 1)
        wb = halfwidth(v0)
        xl = centre(v0) + side * (wb * 0.15 + 0.42 * np.sin(sc * np.pi / 2))  # peel out, then curl up
        wl = 0.6 * wb * (1 - sc) ** 0.8
        layers.append(tongue(xl, wl, amp, 0.3) * inside * smoothstep(0, 0.3, s))
    a = np.max(np.stack(layers), axis=0)
    a *= smoothstep(y0 - 0.02, y0 + 0.20, Y)                # soft base
    a *= 1 - 0.2 * smoothstep(0.8, 1.0, v)                   # tip a touch fainter
    return a


def tex_streak(size=512):
    X, Y = coords(size)
    L = 0.90
    u = np.clip(1 - (X / L) ** 2, 0, 1)
    h = 0.08 * u ** 1.6 + 1e-4                              # half-height, 8 % total at centre
    t = np.abs(Y) / h
    core = np.exp(-2.5 * t * t) * np.clip(1 - t / 2.2, 0, 1) * u ** 0.3
    halo = 0.45 * np.exp(-(X / 0.50) ** 2 - (Y / 0.15) ** 2) * u
    return screen(core, halo)


def tex_star4(size=512):
    X, Y = coords(size)
    r = np.hypot(X, Y)

    def spikes(A, B, L, w0, amp):
        out = np.zeros_like(A)
        for (across, along) in ((A, B), (B, A)):
            s = np.clip(np.abs(along) / L, 0, 1)
            w = w0 * (1 - s) ** 2.2 + 0.0015
            t = np.abs(across) / w
            out = np.maximum(out, np.exp(-2.0 * t * t) * (1 - s) ** 0.35)
        return amp * out

    c = s = math.sqrt(0.5)
    Xr, Yr = X * c - Y * s, X * s + Y * c
    main = spikes(X, Y, 0.90, 0.075, 1.0)
    diag = spikes(Xr, Yr, 0.45, 0.055, 0.60)
    glow = 0.85 * np.exp(-(r / 0.17) ** 2)
    return screen(main, diag, glow)


def tex_petal(size=512):
    X, Y = coords(size)
    t = np.linspace(0, 2 * np.pi, 241)[:-1]
    px = np.sin(t) * np.sin(t / 2) * (0.45 / 0.75)          # teardrop, 45 % wide
    py = np.cos(t) * 0.85                                    # 85 % tall, tip up
    sd = poly_sdf(X, Y, list(zip(px, py)))
    body = 0.84 * smoothstep(0, 0.09, sd) ** 0.85            # feathered edge
    v = (Y + 0.85) / 1.70
    vein_w = 0.025 + 0.045 * (1 - v)
    vein = (0.16 * np.exp(-(X / vein_w) ** 2) * smoothstep(0, 0.06, sd)
            * (1 - smoothstep(0.85, 1.0, v)))
    return np.clip(body + vein, 0, 1)


def midpoint_bolt(p0, p1, rng, levels, disp, xlim, ylim):
    pts = [np.array(p0, float), np.array(p1, float)]
    for _ in range(levels):
        new = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            seg = b - a
            ln = np.linalg.norm(seg) + 1e-9
            nrm = np.array([-seg[1], seg[0]]) / ln
            mid = (a + b) / 2 + nrm * rng.normal(0, disp * ln)
            mid[0] = np.clip(mid[0], *xlim)
            mid[1] = np.clip(mid[1], *ylim)
            new += [mid, b]
        pts = new
        disp *= 0.8
    return pts


def tex_lightning(size=1024, n=4, pad=4, seed=7):
    rng = np.random.default_rng(seed)
    cell = size // n
    F = cell - 2 * pad
    m = 0.04 * F
    xlim = (m + 2, F - m - 2)
    ylim = (m, F - m)
    win = edge_window(F, m)
    sheet = np.zeros((size, size), np.float32)
    for k in range(n * n):
        cv = Canvas(F, 4)
        main = midpoint_bolt((F / 2, m), (F / 2, F - m), rng, 6, 0.13, xlim, ylim)
        cv.polyline(main, 2.6)
        nf = int(rng.integers(1, 3))
        lo, hi = int(len(main) * 0.2), int(len(main) * 0.7)
        for i in rng.choice(np.arange(lo, hi), nf, replace=False):
            a = main[i]
            d = main[min(i + 2, len(main) - 1)] - main[max(i - 2, 0)]
            ang = math.atan2(d[1], d[0]) + rng.choice([-1, 1]) * rng.uniform(0.45, 0.95)
            ln = rng.uniform(0.22, 0.40) * F
            end = a + ln * np.array([math.cos(ang), math.sin(ang)])
            end[0] = np.clip(end[0], *xlim)
            end[1] = np.clip(end[1], *ylim)
            fork = midpoint_bolt(a, end, rng, 5, 0.20, xlim, ylim)
            cv.polyline(fork, 1.7)
            if rng.random() < 0.5:                           # a twig off the fork
                j = int(rng.integers(len(fork) // 3, 2 * len(fork) // 3))
                b = fork[j]
                d2 = fork[min(j + 2, len(fork) - 1)] - fork[max(j - 2, 0)]
                ang2 = math.atan2(d2[1], d2[0]) + rng.choice([-1, 1]) * rng.uniform(0.5, 1.0)
                end2 = b + rng.uniform(0.08, 0.15) * F * np.array([math.cos(ang2), math.sin(ang2)])
                end2[0] = np.clip(end2[0], *xlim)
                end2[1] = np.clip(end2[1], *ylim)
                cv.polyline(midpoint_bolt(b, end2, rng, 3, 0.2, xlim, ylim), 1.2)
        core = cv.render()
        glow = screen(0.8 * blur(core, 2.5), 0.5 * blur(core, 8))
        frame = screen(core, glow) * win
        r, c = divmod(k, n)
        sheet[r * cell + pad:r * cell + pad + F, c * cell + pad:c * cell + pad + F] = frame
    return sheet


def tex_smoke(size=1024, n=8, pad=4, seed=13):
    """Smoke puff flipbook: a soft disc whose radius is domain-warped by two
    drifting fractal noises; the warp and the inner threshold grow with age so
    the puff starts small and dense and ends large, hollow and wispy."""
    rng = np.random.default_rng(seed)
    cell = size // n
    F = cell - 2 * pad
    RS = F * 2                                               # render at 2x, box down

    def contrast(a):
        lo, hi = np.percentile(a, 2), np.percentile(a, 98)
        return np.clip((a - lo) / (hi - lo), 0, 1)

    noise = contrast(fractal(512, rng, periods=(3, 6, 12, 24, 48), gain=0.55))
    detail = contrast(fractal(512, rng, periods=(8, 16, 32, 64), gain=0.55))
    X, Y = coords(RS)
    win_edge = edge_window(RS, 0.04 * RS)
    sheet = np.zeros((size, size), np.float32)
    frames = n * n
    for k in range(frames):
        t = k / (frames - 1)
        Rp = 0.34 + 0.44 * t ** 0.75                         # puff radius 0.34 -> 0.78
        qr = np.hypot(X, Y) / Rp
        n1 = sample_wrap(noise, X * 90 + 40 * t + 17, -Y * 90 - 160 * t)      # wisps rise
        n2 = sample_wrap(detail, X * 90 + 200 - 30 * t, -Y * 90 - 120 * t + 90)
        carve = 0.3 + 0.9 * t                                # outline carving grows with age
        qd = qr + carve * (n1 - 0.5) + 0.4 * (n2 - 0.5)
        th = 0.3 + 0.3 * t                                   # inner threshold climbs -> hollows out
        shape = 1 - smoothstep(th, th + 0.5, qd)
        body = shape * (0.4 + 0.6 * n2) ** (1.2 + 0.5 * t)
        peak = 0.15 + 0.85 * (1 - t) ** 1.5                  # frame 64 tops out near 15 %
        a = body / (np.percentile(body, 99.5) + 1e-6) * peak
        a = np.clip(a, 0, 1) * (1 - smoothstep(0.6, 1.0, qr)) * win_edge
        frame = downsample(a, F)
        r, c = divmod(k, n)
        sheet[r * cell + pad:r * cell + pad + F, c * cell + pad:c * cell + pad + F] = frame
    return sheet


def tex_arc_sweep(size=512):
    X, Y = coords(size)
    cx, cy, R = 0.86, -0.86, 1.72                            # quarter circle BL -> TR
    dx, dy = X - cx, Y - cy
    ang = np.degrees(np.arctan2(dy, dx))                     # 90 at TR end .. 180 at BL end
    s = np.clip((ang - 90) / 90, 0, 1)
    d = np.abs(np.hypot(dx, dy) - R)
    T = 0.16 * np.sin(np.pi * s) ** 0.8 + 1e-4               # half-thickness, pointed ends
    t = d / T
    prof = np.exp(-2.2 * t * t) * np.clip(1 - t / 1.8, 0, 1) ** 0.6
    prof *= np.sin(np.pi * s) ** 0.3                         # ends fade
    prof *= (ang >= 90) & (ang <= 180)
    return prof


def tex_crack(size=512, seed=11):
    rng = np.random.default_rng(seed)
    cv = Canvas(size, 4)
    C = size / 2
    R = size / 2

    def walk(start, base, reach, w0, w1, step, can_branch):
        pos = np.array(start, float)
        pts, widths = [pos.copy()], [w0]
        r0 = np.linalg.norm(pos - C)
        a = base
        while True:
            a = base + 0.6 * (a - base) + rng.normal(0, 0.45)
            pos = pos + step * rng.uniform(0.7, 1.3) * np.array([math.cos(a), math.sin(a)])
            rr = np.linalg.norm(pos - C)
            f = float(np.clip((rr - r0) / max(reach - r0, 1), 0, 1))
            pts.append(pos.copy())
            widths.append(w0 + (w1 - w0) * f)
            if can_branch and 0.3 < f < 0.75 and rng.random() < 0.35:
                side = rng.choice([-1, 1])
                walk(pos, a + side * rng.uniform(0.5, 1.1), rr + (reach - rr) * rng.uniform(0.4, 0.8),
                     widths[-1] * 0.7, 2.0, step * 0.8, False)
            if rr >= reach or rr >= 0.82 * R:
                break
        for p, q, wa, wb in zip(pts[:-1], pts[1:], widths[:-1], widths[1:]):
            cv.line(p, q, (wa + wb) / 2)

    n = int(rng.integers(5, 8))
    for i in range(n):
        walk((C, C), 2 * math.pi * i / n + rng.uniform(-0.25, 0.25),
             R * rng.uniform(0.68, 0.80), 6.0, 2.0, size * 0.03, True)
    core = cv.render()
    glow = screen(0.40 * blur(core, 4), 0.20 * blur(core, 10))
    return screen(core, glow)


def tex_sigil(size=1024, seed=5):
    rng = np.random.default_rng(seed)
    cv = Canvas(size, 4)
    C = (size / 2, size / 2)
    R = size / 2
    lw = 4.0

    def pol(r, deg):
        a = math.radians(deg)
        return (C[0] + r * math.cos(a), C[1] - r * math.sin(a))

    cv.circle(C, 0.95 * R, lw)
    cv.circle(C, 0.80 * R, lw)
    cv.circle(C, 0.20 * R, lw)
    for k in range(24):                                      # tick marks
        cv.line(pol(0.845 * R, k * 15), pol(0.905 * R, k * 15), 3.0)
    for off in (90, 270):                                    # hexagram
        tri = [pol(0.745 * R, off + 120 * j) for j in range(3)]
        cv.polyline(tri + [tri[0]], lw)
    grid = [(u, v) for u in (-1, 0, 1) for v in (-1, 0, 1)]
    for k in range(12):                                      # runes between the ticks
        deg = 7.5 + 30 * k
        a = math.radians(deg)
        cen = np.array(pol(0.88 * R, deg))
        rad = np.array([math.cos(a), -math.sin(a)])
        tan = np.array([-math.sin(a), -math.cos(a)])
        g = 0.040 * R

        def L(u, v):
            return tuple(cen + u * g * tan + v * g * rad)

        for _ in range(int(rng.integers(3, 6))):
            kind = rng.choice(["stroke", "stroke", "dot", "arc"])
            if kind == "stroke":
                i, j = rng.choice(9, 2, replace=False)
                cv.line(L(*grid[i]), L(*grid[j]), 3.5)
            elif kind == "dot":
                cv.disc(L(*grid[int(rng.integers(9))]), 4.0)
            else:
                a0 = rng.uniform(0, 360)
                cv.arc(L(0, 0), rng.uniform(0.45, 1.0) * g, a0, a0 + rng.uniform(90, 270), 3.5)
    return cv.render()


def tex_nebula(size=512, seed=21):
    rng = np.random.default_rng(seed)
    base = fractal(size, rng, periods=(2, 4, 8, 16, 32, 64), gain=0.55)
    ridge = 1 - np.abs(fractal(size, rng, periods=(4, 8, 16, 32), gain=0.5) * 2 - 1)
    nz = normalise(base) * 0.75 + normalise(ridge) ** 2 * 0.25
    lo, hi = np.percentile(nz, 12), np.percentile(nz, 99)
    return np.clip((nz - lo) / (hi - lo), 0, 1) ** 1.4 * 0.85


# --------------------------------------------------------------- checks
def check_margin(name, a):
    m = int(round(a.shape[0] * 0.04)) - 1
    band = max(a[:m].max(), a[-m:].max(), a[:, :m].max(), a[:, -m:].max())
    print(f"  {name:20s} max alpha in 4% margin = {band:.3f}   peak = {a.max():.3f}")


def check_tile(a):
    """Compare the seam step (col/row 0 vs last) with ordinary neighbour steps."""
    seam = max(np.abs(a[:, 0] - a[:, -1]).max(), np.abs(a[0, :] - a[-1, :]).max())
    interior = max(np.abs(np.diff(a, axis=1)).max(), np.abs(np.diff(a, axis=0)).max())
    tiled = np.tile(a, (2, 2))
    print(f"  nebula_tile          seam step = {seam:.4f}  interior max step = {interior:.4f}  "
          f"-> {'tiles OK' if seam <= interior * 1.05 else 'SEAM!'}")
    return tiled


def check_frames(name, sheet, n, pad):
    """Per-frame peak alpha, and the alpha found in the padding between frames."""
    cell = sheet.shape[0] // n
    peaks, padmax = [], 0.0
    for k in range(n * n):
        r, c = divmod(k, n)
        cellpx = sheet[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell]
        inner = cellpx[pad:-pad, pad:-pad]
        ring = cellpx.copy()
        ring[pad:-pad, pad:-pad] = 0
        peaks.append(inner.max())
        padmax = max(padmax, ring.max())
    print(f"  {name:20s} frame peaks: min {min(peaks):.2f}  max {max(peaks):.2f}  "
          f"first {peaks[0]:.2f}  last {peaks[-1]:.2f}  empty frames: {sum(p < 0.05 for p in peaks)}  "
          f"alpha in cell padding: {padmax:.3f}")


def contact_sheet(entries):
    bg = np.array((38, 38, 38), np.float32)
    P, gap, pad, lab, cols = 256, 8, 20, 26, 3
    rows = math.ceil(len(entries) / cols)
    cw, ch = 2 * P + gap, P + lab
    W, H = pad + cols * (cw + pad), pad + rows * (ch + pad)
    sheet = Image.new("RGB", (W, H), tuple(int(v) for v in bg))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.load_default(size=16)
    except TypeError:
        font = ImageFont.load_default()
    for i, (name, a) in enumerate(entries):
        r, c = divmod(i, cols)
        x0, y0 = pad + c * (cw + pad), pad + r * (ch + pad)
        s = np.clip(downsample(a, P), 0, 1)[..., None]
        for j, col in enumerate(((255, 255, 255), TINT)):
            rgb = bg * (1 - s) + np.array(col, np.float32) * s
            sheet.paste(Image.fromarray(np.round(rgb).astype(np.uint8)), (x0 + j * (P + gap), y0 + lab))
        draw.text((x0, y0 + 4), f"{i + 1}. {name}   {a.shape[1]} px", fill=(225, 225, 225), font=font)
    sheet.save(os.path.join(OUT, "contact_sheet.png"))


def main():
    jobs = [
        ("glow_soft.png", tex_glow_soft),
        ("ring_hard.png", tex_ring_hard),
        ("flame_sheet.png", tex_flame),
        ("streak.png", tex_streak),
        ("star4.png", tex_star4),
        ("petal.png", tex_petal),
        ("lightning_4x4.png", tex_lightning),
        ("smoke_8x8.png", tex_smoke),
        ("arc_sweep.png", tex_arc_sweep),
        ("crack.png", tex_crack),
        ("sigil_1024.png", tex_sigil),
        ("nebula_tile.png", tex_nebula),
    ]
    entries = []
    print("painting:")
    for name, fn in jobs:
        a = save(name, fn())
        entries.append((name, a))
        if name == "nebula_tile.png":
            check_tile(a)
        elif "x" not in name.split("_")[-1]:
            check_margin(name, a)
        if name == "lightning_4x4.png":
            check_frames(name, a, 4, 4)
        if name == "smoke_8x8.png":
            check_frames(name, a, 8, 4)
    contact_sheet(entries)
    print("wrote", len(jobs), "textures + contact_sheet.png to", OUT)


if __name__ == "__main__":
    main()
