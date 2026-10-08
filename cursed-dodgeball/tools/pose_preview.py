"""Render the Cursed Dodgeball procedural poses as an R15 block figure.

Usage: python3 -I tools/pose_preview.py poses.jsonl out_dir
Reads the JSON lines written by tools/pose_dump.luau and writes, per scene, PNG frames and an MP4
(two panels: a tracking side view for judging the gait, and the over-the-shoulder game camera).

The rig and the rotation convention match the Roblox animator: each joint applies
CFrame.Angles(x, y, z) = Rx @ Ry @ Rz in its own frame; character space is X right, Y up, Z back.
"""
import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

W, H = 520, 400

# ---------------------------------------------------------------- rotation helpers (Roblox convention)
def rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def angles(v):
    return rx(v[0]) @ ry(v[1]) @ rz(v[2])


class Frame:
    """Rigid transform: world = R @ local + t."""

    def __init__(self, R=None, t=None):
        self.R = np.eye(3) if R is None else R
        self.t = np.zeros(3) if t is None else np.array(t, dtype=float)

    def __mul__(self, o):
        return Frame(self.R @ o.R, self.R @ o.t + self.t)

    def point(self, p):
        return self.R @ np.array(p, dtype=float) + self.t


def T(x, y, z):
    return Frame(t=(x, y, z))


def Rf(R):
    return Frame(R=R)


# ---------------------------------------------------------------- R15 block rig (studs, root part space)
# name: (parent, pivot offset in parent's pivot frame, box centre offset from own pivot, box size, colour)
BODY = (60, 120, 220)
ARM = (250, 205, 60)
LEG = (70, 190, 110)
HEAD = (225, 225, 230)
RIG = [
    ("Root", None, (0, -0.8, 0), (0, 0.2, 0), (2, 0.4, 1), BODY),
    ("Waist", "Root", (0, 0.4, 0), (0, 0.8, 0), (2, 1.6, 1), BODY),
    ("Neck", "Waist", (0, 1.6, 0), (0, 0.6, 0), (1.2, 1.2, 1.2), HEAD),
    ("RShoulder", "Waist", (1.5, 1.3, 0), (0, -0.425, 0), (1, 1.15, 1), ARM),
    ("RElbow", "RShoulder", (0, -0.85, 0), (0, -0.4, 0), (1, 1.0, 1), ARM),
    ("RWrist", "RElbow", (0, -0.85, 0), (0, -0.15, 0), (1, 0.3, 1), ARM),
    ("LShoulder", "Waist", (-1.5, 1.3, 0), (0, -0.425, 0), (1, 1.15, 1), ARM),
    ("LElbow", "LShoulder", (0, -0.85, 0), (0, -0.4, 0), (1, 1.0, 1), ARM),
    ("LWrist", "LElbow", (0, -0.85, 0), (0, -0.15, 0), (1, 0.3, 1), ARM),
    ("RHip", "Root", (0.5, -0.2, 0), (0, -0.55, 0), (1, 1.2, 1), LEG),
    ("RKnee", "RHip", (0, -1.05, 0), (0, -0.5, 0), (1, 1.1, 1), LEG),
    ("RAnkle", "RKnee", (0, -0.95, 0), (0, -0.12, -0.1), (1, 0.3, 1.2), LEG),
    ("LHip", "Root", (-0.5, -0.2, 0), (0, -0.55, 0), (1, 1.2, 1), LEG),
    ("LKnee", "LHip", (0, -1.05, 0), (0, -0.5, 0), (1, 1.1, 1), LEG),
    ("LAnkle", "LKnee", (0, -0.95, 0), (0, -0.12, -0.1), (1, 0.3, 1.2), LEG),
]
SPIN_PIVOT = 0.9  # roll pivot above the hips, matches Animator.lua

CUBE = np.array([[x, y, z] for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)])
FACES = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
LIGHT = np.array([0.4, 0.8, 0.45]) / np.linalg.norm([0.4, 0.8, 0.45])


def solve(rec):
    """Return list of (box world corners, colour) for one frame record."""
    pose = rec["pose"]
    px, py, pz = rec["pos"]
    root = T(px, py, pz) * Rf(ry(rec["yaw"]))
    frames = {}
    boxes = []
    for name, parent, pivot, centre, size, colour in RIG:
        ang = pose[name]
        if parent is None:
            rp = pose["RootPos"]
            spin = pose["RootSpin"]
            j = root * T(*pivot) * T(*rp) * T(0, SPIN_PIVOT, 0) * Rf(angles(spin)) * T(0, -SPIN_PIVOT, 0) * Rf(angles(ang))
        else:
            j = frames[parent] * T(*pivot) * Rf(angles(ang))
        frames[name] = j
        box = j * T(*centre)
        corners = np.array([box.point(c * np.array(size)) for c in CUBE])
        boxes.append((corners, colour))
    return boxes


# ---------------------------------------------------------------- camera and drawing
class Cam:
    def __init__(self, eye, target, fov=70):
        self.eye = np.array(eye, dtype=float)
        f = np.array(target, dtype=float) - self.eye
        f /= np.linalg.norm(f)
        r = np.cross(f, [0, 1, 0])
        if np.linalg.norm(r) < 1e-6:
            r = np.array([1.0, 0, 0])
        r /= np.linalg.norm(r)
        u = np.cross(r, f)
        self.f, self.r, self.u = f, r, u
        self.k = (H / 2) / math.tan(math.radians(fov) / 2)

    def project(self, p):
        d = np.array(p) - self.eye
        z = d @ self.f
        if z < 0.1:
            return None, z
        return (W / 2 + self.k * (d @ self.r) / z, H / 2 - self.k * (d @ self.u) / z), z


def shade(colour, normal):
    lam = 0.45 + 0.55 * max(0.0, float(normal @ LIGHT))
    return tuple(int(min(255, c * lam)) for c in colour)


def draw_scene(img, cam, boxes, centre, wall=None):
    d = ImageDraw.Draw(img)
    # sky
    d.rectangle([0, 0, W, H], fill=(150, 195, 235))
    # ground: checker tiles around the character
    cx, cz = round(centre[0] / 4) * 4, round(centre[2] / 4) * 4
    tiles = []
    for i in range(-14, 15):
        for k in range(-14, 15):
            x0, z0 = cx + i * 4, cz + k * 4
            quad = [(x0, 0, z0), (x0 + 4, 0, z0), (x0 + 4, 0, z0 + 4), (x0, 0, z0 + 4)]
            pts = [cam.project(q) for q in quad]
            if any(p[0] is None for p in pts):
                continue
            depth = sum(p[1] for p in pts) / 4
            col = (92, 92, 104) if (int(x0 / 4) + int(z0 / 4)) % 2 == 0 else (104, 104, 116)
            tiles.append((depth, [p[0] for p in pts], col))
    for _, pts, col in sorted(tiles, key=lambda e: -e[0]):
        d.polygon(pts, fill=col)
    polys = []
    if wall is not None:
        # a wall to the character's right, running along the scene's travel line
        x = wall
        for i in range(-10, 30):
            z0 = -i * 4
            quad = [(x, 0, z0), (x, 0, z0 - 4), (x, 9, z0 - 4), (x, 9, z0)]
            pts = [cam.project(q) for q in quad]
            if any(p[0] is None for p in pts):
                continue
            depth = sum(p[1] for p in pts) / 4
            col = (120, 125, 145) if i % 2 == 0 else (110, 115, 135)
            polys.append((depth, [p[0] for p in pts], col))
    # shadow blob
    sh = [cam.project((centre[0] + 1.3 * math.cos(a), 0.02, centre[2] + 0.9 * math.sin(a))) for a in np.linspace(0, 2 * math.pi, 16)]
    if all(p[0] is not None for p in sh):
        d.polygon([p[0] for p in sh], fill=(70, 70, 80))
    for corners, colour in boxes:
        centre_box = corners.mean(axis=0)
        for f in FACES:
            q = corners[list(f)]
            n = np.cross(q[1] - q[0], q[2] - q[0])
            nl = np.linalg.norm(n)
            if nl < 1e-9:
                continue
            n /= nl
            fc = q.mean(axis=0)
            if (fc - centre_box) @ n < 0:
                n = -n
            if (fc - cam.eye) @ n > 0:
                continue  # back face
            pts = [cam.project(p) for p in q]
            if any(p[0] is None for p in pts):
                continue
            depth = max(p[1] for p in pts)
            polys.append((depth, [p[0] for p in pts], shade(colour, n)))
    for _, pts, col in sorted(polys, key=lambda e: -e[0]):
        d.polygon(pts, fill=col, outline=(30, 30, 40))


def render(records, out_dir, scene):
    os.makedirs(out_dir, exist_ok=True)
    frames_dir = os.path.join(out_dir, scene)
    os.makedirs(frames_dir, exist_ok=True)
    for idx, rec in enumerate(records):
        boxes = solve(rec)
        p = np.array(rec["pos"])
        yaw = rec["yaw"]
        fwd = np.array([-math.sin(yaw), 0, -math.cos(yaw)])
        right = np.array([math.cos(yaw), 0, -math.sin(yaw)])
        ground_c = np.array([p[0], 0, p[2]])
        # side view: from the character's left, slightly ahead, tracking
        # rises with the character on big jumps so a full double jump stays in frame
        lift = max(0.0, p[1] - 3.2) * 0.85
        side_eye = ground_c - right * 13 + fwd * 2 + np.array([0, 3.2 + lift, 0])
        side = Cam(side_eye, ground_c + np.array([0, 2.6 + lift, 0]), fov=55)
        # game camera: over the right shoulder, behind, 10 studs back
        game_eye = p + np.array([0, 1.6 + 0.6, 0]) + right * 1.75 - fwd * 10 + np.array([0, 1.6, 0])
        game = Cam(game_eye, p + np.array([0, 1.6, 0]) + right * 1.75 + fwd * 8, fov=72)
        canvas = Image.new("RGB", (W * 2, H + 30), (20, 20, 26))
        a = Image.new("RGB", (W, H))
        draw_scene(a, side, boxes, ground_c, rec.get("wall") and p[0] + rec["wall"] if rec.get("wall") else None)
        b = Image.new("RGB", (W, H))
        draw_scene(b, game, boxes, ground_c, rec.get("wall") and p[0] + rec["wall"] if rec.get("wall") else None)
        canvas.paste(a, (0, 0))
        canvas.paste(b, (W, 0))
        d = ImageDraw.Draw(canvas)
        d.text((10, H + 8), f"{scene}  |  {rec['label']}  |  {rec['state']}  speed {rec['speed']:.1f}", fill=(235, 235, 235))
        d.text((W + 10, H + 8), "left: side view   right: over-the-shoulder game camera", fill=(170, 170, 180))
        canvas.save(os.path.join(frames_dir, f"{idx:04d}.png"))
    mp4 = os.path.join(out_dir, f"{scene}.mp4")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", "30", "-i", os.path.join(frames_dir, "%04d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", mp4], check=True)
    return mp4


def sheet(records, out_path):
    """Big static views of each pose: side, front three-quarter, back three-quarter."""
    global W, H
    W, H = 300, 300
    cells = []
    for rec in records:
        boxes = solve(rec)
        p = np.array(rec["pos"])
        look = np.array([p[0], 2.7, p[2]])
        views = [
            Cam(look + np.array([-11.0, 0.6, 0]), look, fov=45),
            Cam(look + np.array([7.0, 2.4, -8.0]), look, fov=45),
            Cam(look + np.array([-6.5, 2.8, 8.5]), look, fov=45),
        ]
        row = Image.new("RGB", (W * 3, H + 22), (20, 20, 26))
        for i, cam in enumerate(views):
            im = Image.new("RGB", (W, H))
            draw_scene(im, cam, boxes, np.array([p[0], 0, p[2]]))
            row.paste(im, (i * W, 0))
        ImageDraw.Draw(row).text((8, H + 5), rec["label"] + "   (side, front 3/4, back 3/4; character faces screen-left in the side view)", fill=(235, 235, 235))
        cells.append(row)
    cols = 2
    rows = (len(cells) + cols - 1) // cols
    out = Image.new("RGB", (cells[0].width * cols, cells[0].height * rows), (0, 0, 0))
    for i, c in enumerate(cells):
        out.paste(c, ((i % cols) * c.width, (i // cols) * c.height))
    out.save(out_path)
    print(out_path)


def main():
    if sys.argv[1] == "--sheet":
        recs = [json.loads(l) for l in open(sys.argv[2])]
        sheet(recs, sys.argv[3])
        return
    src, out_dir = sys.argv[1], sys.argv[2]
    scenes = {}
    for line in open(src):
        rec = json.loads(line)
        scenes.setdefault(rec["scene"], []).append(rec)
    for scene, recs in scenes.items():
        print(render(recs, out_dir, scene))


if __name__ == "__main__":
    main()
