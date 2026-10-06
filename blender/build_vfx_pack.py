# Farm Lasso Celebration VFX pack: builds every effect mesh procedurally.
# Runs in Blender 4.x/5.x (bpy). 1 Blender unit = 1 Roblox stud. Z is up here;
# glTF export flips to Y-up automatically. Every mesh is white, flat, and sits
# at the origin so Roblox code can colour, scale and place it.
#
# Usage in local Blender:  blender --background --python build_vfx_pack.py
# Then File > Export > glTF 2.0 (or the export block at the bottom).

import bpy
import bmesh
import math
import random
from mathutils import Vector

random.seed(7)
TAU = math.tau

# ---------------------------------------------------------------- scene reset
for ob in list(bpy.data.objects):
    if ob.type == "MESH":
        bpy.data.objects.remove(ob, do_unlink=True)
for me in list(bpy.data.meshes):
    if me.users == 0:
        bpy.data.meshes.remove(me)

col = bpy.data.collections.get("VFX_Pack")
if col is None:
    col = bpy.data.collections.new("VFX_Pack")
    bpy.context.scene.collection.children.link(col)

mat = bpy.data.materials.get("VFX_White")
if mat is None:
    mat = bpy.data.materials.new("VFX_White")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (1, 1, 1, 1)
        bsdf.inputs["Roughness"].default_value = 0.35

# ---------------------------------------------------------------- helpers
def merge(parts):
    """parts: list of (verts, faces). Returns one (verts, faces)."""
    verts, faces = [], []
    for v, f in parts:
        off = len(verts)
        verts.extend(v)
        faces.extend([tuple(i + off for i in face) for face in f])
    return verts, faces


def make(name, verts, faces, smooth=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.validate(verbose=False)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    me.materials.append(mat)
    return ob


def ribbon(centers, perps, halfw, ht, up):
    """Closed solid strip along centers. perps: in-plane width dirs, up: thickness dir."""
    verts, faces = [], []
    n = len(centers)
    for i in range(n):
        c = Vector(centers[i])
        p = Vector(perps[i]).normalized() * max(halfw[i], 0.01)
        u = Vector(up).normalized() * ht
        verts += [c + p + u, c - p + u, c - p - u, c + p - u]
    for i in range(n - 1):
        a, b = 4 * i, 4 * (i + 1)
        faces.append((a, b, b + 1, a + 1))          # top
        faces.append((a + 3, a + 2, b + 2, b + 3))  # bottom
        faces.append((a + 1, b + 1, b + 2, a + 2))  # side
        faces.append((a, a + 3, b + 3, b))          # side
    faces.append((0, 1, 2, 3))
    e = 4 * (n - 1)
    faces.append((e, e + 3, e + 2, e + 1))
    return verts, faces


def perps_from_centers(centers, up):
    """Perpendicular (in the plane normal to up) to the local tangent."""
    out = []
    n = len(centers)
    upv = Vector(up).normalized()
    for i in range(n):
        a = Vector(centers[max(i - 1, 0)])
        b = Vector(centers[min(i + 1, n - 1)])
        t = (b - a)
        if t.length < 1e-6:
            t = Vector((1, 0, 0))
        out.append(upv.cross(t).normalized())
    return out


def torus(R, rh, rv, segs=64, minor=10):
    verts, faces = [], []
    for i in range(segs):
        a = TAU * i / segs
        ca, sa = math.cos(a), math.sin(a)
        for j in range(minor):
            b = TAU * j / minor
            rr = R + rh * math.cos(b)
            verts.append((rr * ca, rr * sa, rv * math.sin(b)))
    for i in range(segs):
        for j in range(minor):
            a0 = i * minor + j
            a1 = i * minor + (j + 1) % minor
            b0 = ((i + 1) % segs) * minor + j
            b1 = ((i + 1) % segs) * minor + (j + 1) % minor
            faces.append((a0, b0, b1, a1))
    return verts, faces


def band(ri, ro, ht, segs=64):
    """Flat annulus with thickness (closed)."""
    verts, faces = [], []
    for i in range(segs):
        a = TAU * i / segs
        c, s = math.cos(a), math.sin(a)
        verts += [(ri * c, ri * s, ht), (ro * c, ro * s, ht),
                  (ro * c, ro * s, -ht), (ri * c, ri * s, -ht)]
    for i in range(segs):
        a, b = 4 * i, 4 * ((i + 1) % segs)
        faces.append((a, b, b + 1, a + 1))          # top
        faces.append((a + 3, a + 2, b + 2, b + 3))  # bottom
        faces.append((a + 1, b + 1, b + 2, a + 2))  # outer
        faces.append((a, a + 3, b + 3, b))          # inner
    return verts, faces


def box(center, half, rot_z=0.0):
    cx, cy, cz = center
    hx, hy, hz = half
    c, s = math.cos(rot_z), math.sin(rot_z)
    verts = []
    for dz in (-hz, hz):
        for dx, dy in ((-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)):
            x = dx * c - dy * s
            y = dx * s + dy * c
            verts.append((cx + x, cy + y, cz + dz))
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return verts, faces


def crystal(rings, top_z, bot_z, n=6, twist=0.0):
    """rings: list of (z, radius) from bottom to top. Apexes at top_z / bot_z."""
    verts = [(0, 0, top_z)]
    for k, (z, r) in enumerate(rings):
        for i in range(n):
            a = TAU * i / n + twist * k
            verts.append((r * math.cos(a), r * math.sin(a), z))
    verts.append((0, 0, bot_z))
    faces = []
    top, bot = 0, len(verts) - 1
    last = len(rings) - 1
    for i in range(n):
        j = (i + 1) % n
        faces.append((top, 1 + last * n + i, 1 + last * n + j))
        faces.append((bot, 1 + j, 1 + i))
    for k in range(last):
        for i in range(n):
            j = (i + 1) % n
            a0, a1 = 1 + k * n + i, 1 + k * n + j
            b0, b1 = 1 + (k + 1) * n + i, 1 + (k + 1) * n + j
            faces.append((a0, a1, b1, b0))
    return verts, faces


def tube(r0, r1, z0, z1, segs=48):
    verts, faces = [], []
    for i in range(segs):
        a = TAU * i / segs
        verts.append((r0 * math.cos(a), r0 * math.sin(a), z0))
        verts.append((r1 * math.cos(a), r1 * math.sin(a), z1))
    for i in range(segs):
        a, b = 2 * i, 2 * ((i + 1) % segs)
        faces.append((a, b, b + 1, a + 1))
    return verts, faces


def star(points, r_out, r_in, hz):
    verts = [(0, 0, hz), (0, 0, -hz)]
    for i in range(points * 2):
        a = TAU * i / (points * 2) + TAU / 4
        r = r_out if i % 2 == 0 else r_in
        verts.append((r * math.cos(a), r * math.sin(a), 0))
    faces = []
    m = points * 2
    for i in range(m):
        j = (i + 1) % m
        faces.append((0, 2 + i, 2 + j))
        faces.append((1, 2 + j, 2 + i))
    return verts, faces


def sphere(r, zscale, segs=20, rings=12):
    verts = [(0, 0, r * zscale)]
    for j in range(1, rings):
        phi = math.pi * j / rings
        for i in range(segs):
            th = TAU * i / segs
            verts.append((r * math.sin(phi) * math.cos(th), r * math.sin(phi) * math.sin(th), r * math.cos(phi) * zscale))
    verts.append((0, 0, -r * zscale))
    faces = []
    bot = len(verts) - 1
    for i in range(segs):
        j = (i + 1) % segs
        faces.append((0, 1 + i, 1 + j))
        base = 1 + (rings - 2) * segs
        faces.append((bot, base + j, base + i))
    for k in range(rings - 2):
        for i in range(segs):
            j = (i + 1) % segs
            a0, a1 = 1 + k * segs + i, 1 + k * segs + j
            b0, b1 = 1 + (k + 1) * segs + i, 1 + (k + 1) * segs + j
            faces.append((a0, b0, b1, a1))
    return verts, faces


UP = (0, 0, 1)
built = {}

# ---------------------------------------------------------------- 1 galaxy arm
pts, hw = [], []
N = 60
for i in range(N):
    t = i / (N - 1)
    ang = t * TAU * 0.95
    rad = 0.9 + 7.1 * t
    pts.append((rad * math.cos(ang), rad * math.sin(ang), 0))
    hw.append(0.25 + 1.55 * math.sin(t * math.pi) ** 0.8)
v, f = ribbon(pts, perps_from_centers(pts, UP), hw, 0.05, UP)
built["VFX_GalaxyArm"] = make("VFX_GalaxyArm", v, f)

# ---------------------------------------------------------------- 2 galaxy core
v, f = sphere(1.6, 0.32)
built["VFX_GalaxyCore"] = make("VFX_GalaxyCore", v, f, smooth=True)

# ---------------------------------------------------------------- 3 accretion ring
v, f = merge([torus(1.0, 0.16, 0.06, 72, 10), torus(0.72, 0.05, 0.025, 64, 8)])
built["VFX_AccretionRing"] = make("VFX_AccretionRing", v, f, smooth=True)

# ---------------------------------------------------------------- 4 shock ring
v, f = torus(1.0, 0.06, 0.06, 72, 8)
built["VFX_ShockRing"] = make("VFX_ShockRing", v, f, smooth=True)

# ---------------------------------------------------------------- 5 halo ring
v, f = torus(1.0, 0.11, 0.11, 72, 10)
built["VFX_HaloRing"] = make("VFX_HaloRing", v, f, smooth=True)

# ---------------------------------------------------------------- 6 rune ring
parts = [band(0.86, 1.0, 0.03, 72)]
for i in range(12):
    a = TAU * i / 12
    parts.append(box((0.93 * math.cos(a), 0.93 * math.sin(a), 0.06), (0.05, 0.025, 0.04), a))
for i in range(24):
    a = TAU * i / 24 + TAU / 48
    parts.append(box((0.80 * math.cos(a), 0.80 * math.sin(a), 0.0), (0.02, 0.02, 0.02), a))
v, f = merge(parts)
built["VFX_RuneRing"] = make("VFX_RuneRing", v, f)

# ---------------------------------------------------------------- 7 sigil (magic circle)
parts = [band(0.95, 1.0, 0.02, 96), band(0.58, 0.62, 0.02, 72), band(0.30, 0.33, 0.02, 48)]
for tri in range(2):
    for k in range(3):
        a0 = TAU * k / 3 + (math.pi / 3 if tri else 0) + TAU / 4
        a1 = TAU * (k + 1) / 3 + (math.pi / 3 if tri else 0) + TAU / 4
        p0 = (0.60 * math.cos(a0), 0.60 * math.sin(a0), 0)
        p1 = (0.60 * math.cos(a1), 0.60 * math.sin(a1), 0)
        c = [p0, p1]
        parts.append(ribbon(c, perps_from_centers(c, UP), [0.02, 0.02], 0.02, UP))
for i in range(8):
    a = TAU * i / 8
    parts.append(box((0.975 * math.cos(a), 0.975 * math.sin(a), 0), (0.045, 0.045, 0.03), a + TAU / 8))
v, f = merge(parts)
built["VFX_Sigil"] = make("VFX_Sigil", v, f)

# ---------------------------------------------------------------- 8 shards
v, f = crystal([(0, 0.34)], 2.0, -0.8, 6)
built["VFX_ShardA"] = make("VFX_ShardA", v, f)
v, f = crystal([(-0.4, 0.5), (0.4, 0.5)], 1.5, -1.0, 6, twist=0.2)
built["VFX_ShardB"] = make("VFX_ShardB", v, f)
v, f = crystal([(0, 0.14)], 1.7, -1.7, 5)
built["VFX_ShardC"] = make("VFX_ShardC", v, f)
v, f = crystal([(0, 0.42)], 1.0, -1.0, 4)
built["VFX_OrbitCrystal"] = make("VFX_OrbitCrystal", v, f)

# ---------------------------------------------------------------- 9 slash
pts, hw = [], []
N = 40
for i in range(N):
    t = i / (N - 1)
    ang = math.radians(-65 + 130 * t)
    pts.append((4.0 * math.sin(ang), 4.0 * math.cos(ang) - 4.0, 0))
    hw.append(0.02 + 0.95 * math.sin(t * math.pi) ** 1.3)
v, f = ribbon(pts, perps_from_centers(pts, UP), hw, 0.04, UP)
built["VFX_Slash"] = make("VFX_Slash", v, f)

# ---------------------------------------------------------------- 10 bolts
def bolt(length, jitter, segs, fork=False):
    pts, hw = [], []
    for i in range(segs):
        t = i / (segs - 1)
        amp = jitter * math.sin(t * math.pi) ** 0.5
        x = random.uniform(-amp, amp) if 0 < i < segs - 1 else 0
        y = random.uniform(-amp, amp) * 0.4 if 0 < i < segs - 1 else 0
        pts.append((x, y, -length * t))
        hw.append(0.05 + 0.30 * (1 - t))
    parts = [ribbon(pts, perps_from_centers(pts, (0, 1, 0)), hw, 0.05, (0, 1, 0))]
    if fork:
        k = segs // 2
        fp = [pts[k]]
        fh = [hw[k] * 0.8]
        for j in range(1, 6):
            t = j / 5
            fp.append((pts[k][0] + 1.6 * t + random.uniform(-0.2, 0.2), pts[k][1], pts[k][2] - 2.2 * t))
            fh.append(0.04 + 0.18 * (1 - t))
        parts.append(ribbon(fp, perps_from_centers(fp, (0, 1, 0)), fh, 0.05, (0, 1, 0)))
    return merge(parts)

v, f = bolt(10.0, 1.1, 14)
built["VFX_BoltA"] = make("VFX_BoltA", v, f)
v, f = bolt(10.0, 1.3, 16, fork=True)
built["VFX_BoltB"] = make("VFX_BoltB", v, f)

# ---------------------------------------------------------------- 11 star shard + god ray
v, f = star(4, 1.0, 0.22, 0.16)
built["VFX_StarShard"] = make("VFX_StarShard", v, f)
pts = [(0, 0, 0), (0, 0, 0.5), (0, 0, 1.0)]
v, f = ribbon(pts, [(1, 0, 0)] * 3, [0.14, 0.08, 0.015], 0.02, (0, 1, 0))
built["VFX_GodRay"] = make("VFX_GodRay", v, f)

# ---------------------------------------------------------------- 12 beam column (open, double-sided in Roblox)
v, f = tube(0.8, 1.0, 0.0, 1.0, 48)
built["VFX_BeamColumn"] = make("VFX_BeamColumn", v, f, smooth=True)

# ---------------------------------------------------------------- 13 floor swirl
pts, hw = [], []
N = 90
for i in range(N):
    t = i / (N - 1)
    ang = t * TAU * 2.0
    rad = 0.25 + 0.75 * t
    pts.append((rad * math.cos(ang), rad * math.sin(ang), 0))
    hw.append(0.03 + 0.07 * math.sin(t * math.pi) ** 0.6)
v, f = ribbon(pts, perps_from_centers(pts, UP), hw, 0.02, UP)
built["VFX_Swirl"] = make("VFX_Swirl", v, f)

# ---------------------------------------------------------------- 14 wing (right; code mirrors for left)
parts = []
feathers = [(8, 7.0), (22, 6.6), (36, 6.0), (50, 5.2), (64, 4.3), (78, 3.3)]
for deg, length in feathers:
    a = math.radians(deg)
    d = Vector((math.cos(a), 0, math.sin(a)))
    pts = []
    hw = []
    M = 10
    for i in range(M):
        t = i / (M - 1)
        curve = Vector((0, 0, -0.9 * t * t))
        pts.append(tuple(d * (length * t) + curve))
        hw.append(0.05 + 0.42 * math.sin(t * math.pi) ** 0.9)
    parts.append(ribbon(pts, perps_from_centers(pts, (0, 1, 0)), hw, 0.03, (0, 1, 0)))
arc = []
for i in range(12):
    t = i / 11
    a = math.radians(5 + 80 * t)
    arc.append((1.2 * math.cos(a), 0, 1.2 * math.sin(a)))
parts.append(ribbon(arc, perps_from_centers(arc, (0, 1, 0)), [0.12] * 12, 0.08, (0, 1, 0)))
v, f = merge(parts)
built["VFX_Wing"] = make("VFX_Wing", v, f)

# ---------------------------------------------------------------- 15 crown of spikes (orbit halo with teeth)
parts = [torus(1.0, 0.05, 0.05, 72, 8)]
for i in range(16):
    a = TAU * i / 16
    base = (math.cos(a), math.sin(a), 0)
    tip = (1.35 * math.cos(a), 1.35 * math.sin(a), 0.18)
    c = [base, tip]
    parts.append(ribbon(c, perps_from_centers(c, UP), [0.07, 0.01], 0.03, UP))
v, f = merge(parts)
built["VFX_SpikeHalo"] = make("VFX_SpikeHalo", v, f)

# ---------------------------------------------------------------- report
report = {}
for name, ob in built.items():
    d = ob.dimensions
    report[name] = [round(d.x, 2), round(d.y, 2), round(d.z, 2), len(ob.data.polygons)]

result = {"count": len(built), "meshes": report}

if __name__ == "__main__" and bpy.app.background and "--export" in __import__("sys").argv:
    bpy.ops.export_scene.gltf(filepath="VFX_Pack.glb", export_format="GLB", use_selection=False)
