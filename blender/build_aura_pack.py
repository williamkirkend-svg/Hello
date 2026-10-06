# Farm Lasso Aura VFX pack v2: builds every effect mesh procedurally.
# Runs in Blender 4.x/5.x (bpy). 1 Blender unit = 1 Roblox stud. Z is up here;
# glTF export flips to Y-up automatically. Every mesh is white, flat shaded
# (a few smooth), sits at the origin, and is named VFX2_*. Roblox recentres
# each imported mesh on its bounding box, so aura_pack_pivots.json records the
# bbox centre of every mesh (see the `result` dict at the bottom).
#
# Usage in local Blender:  blender --background --python build_aura_pack.py -- --export
# Dry run without Blender (bbox + polygon sanity only):  python3 build_aura_pack.py

import math
import random
import sys

try:
    import bpy
    import bmesh
except ImportError:  # dry run outside Blender
    bpy = None
    bmesh = None
from mathutils import Vector, Matrix

try:
    from mathutils.geometry import tessellate_polygon
except ImportError:  # dry-run stub: fan the outer loop only
    def tessellate_polygon(loops):
        n = len(loops[0])
        return [(0, i, i + 1) for i in range(1, n - 1)]

random.seed(11)
TAU = math.tau
UP = (0, 0, 1)
Y = (0, 1, 0)

# ---------------------------------------------------------------- scene reset
if bpy is not None:
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    for cu in list(bpy.data.curves):
        if cu.users == 0:
            bpy.data.curves.remove(cu)

    col = bpy.data.collections.get("VFX2_Pack")
    if col is None:
        col = bpy.data.collections.new("VFX2_Pack")
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


class _Dry:
    """Stand-in object for dry runs (no bpy)."""
    def __init__(self, name, verts, faces):
        self.name = name
        xs = [v[0] for v in verts]; ys = [v[1] for v in verts]; zs = [v[2] for v in verts]
        self.lo = (min(xs), min(ys), min(zs)); self.hi = (max(xs), max(ys), max(zs))
        self.dimensions = Vector((self.hi[0] - self.lo[0], self.hi[1] - self.lo[1], self.hi[2] - self.lo[2]))
        self.ntris = sum(max(len(f) - 2, 0) for f in faces)


def make(name, verts, faces, smooth=False):
    assert name.startswith("VFX2_"), name
    if bpy is None:
        return _Dry(name, verts, faces)
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
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
    """Closed solid strip along centers. perps: in-plane width dirs; up: thickness dir
    (a single vector or one per point)."""
    verts, faces = [], []
    n = len(centers)
    ups = up if isinstance(up, list) else [up] * n
    for i in range(n):
        c = Vector(centers[i])
        p = Vector(perps[i]).normalized() * max(halfw[i], 0.01)
        u = Vector(ups[i]).normalized() * ht
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


def sphere(r, zscale=1.0, segs=20, rings=12):
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


def cylinder(r, z0, z1, segs=24):
    verts = [(0, 0, z0), (0, 0, z1)]
    for i in range(segs):
        a = TAU * i / segs
        verts += [(r * math.cos(a), r * math.sin(a), z0), (r * math.cos(a), r * math.sin(a), z1)]
    faces = []
    for i in range(segs):
        a, b = 2 + 2 * i, 2 + 2 * ((i + 1) % segs)
        faces.append((a, b, b + 1, a + 1))
        faces.append((0, b, a))
        faces.append((1, a + 1, b + 1))
    return verts, faces


def _segs_cross(p, q, r, s):
    def o(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    return (o(p, q, r) * o(p, q, s) < 0) and (o(r, s, p) * o(r, s, q) < 0)


def slab(loops, ht, z=0.0, check=None):
    """Flat extruded polygon. loops: list of closed 2D (x, y) polylines; the first is
    the outer boundary, the rest are holes. Thickness 2*ht centred on z."""
    if bpy is None and check:  # dry run: warn about self-intersecting loops
        for lp in loops:
            m = len(lp)
            segs = [(lp[i], lp[(i + 1) % m]) for i in range(m)]
            for i in range(m):
                for j in range(i + 2, m):
                    if i == 0 and j == m - 1:
                        continue
                    if _segs_cross(*segs[i], *segs[j]):
                        print("WARN self-intersection in", check, i, j)
    tris = tessellate_polygon([[Vector((x, y, 0.0)) for x, y in lp] for lp in loops])
    flat = [p for lp in loops for p in lp]
    n = len(flat)
    verts = [(x, y, z + ht) for x, y in flat] + [(x, y, z - ht) for x, y in flat]
    faces = [tuple(t) for t in tris] + [tuple(n + i for i in reversed(t)) for t in tris]
    off = 0
    for lp in loops:
        m = len(lp)
        for i in range(m):
            a = off + i
            b = off + (i + 1) % m
            faces.append((a, b, n + b, n + a))
        off += m
    return verts, faces


def loft(loops, zs):
    """loops: 2D loops with equal vertex counts stacked at heights zs; capped."""
    m = len(loops[0])
    verts = []
    for lp, z in zip(loops, zs):
        verts += [(x, y, z) for x, y in lp]
    faces = []
    for k in range(len(loops) - 1):
        for i in range(m):
            j = (i + 1) % m
            faces.append((k * m + i, k * m + j, (k + 1) * m + j, (k + 1) * m + i))
    tris = tessellate_polygon([[Vector((x, y, 0.0)) for x, y in loops[0]]])
    last = (len(loops) - 1) * m
    faces += [tuple(t) for t in tris] + [tuple(last + i for i in t) for t in tris]
    return verts, faces


def rings_tube(rings, cap_start=True, cap_end=True):
    """rings: list of rings (each a list of n 3D points). Side quads + fan caps."""
    n = len(rings[0])
    verts = [tuple(p) for r in rings for p in r]
    faces = []
    for k in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((k * n + i, k * n + j, (k + 1) * n + j, (k + 1) * n + i))
    if cap_start:
        c = Vector((0, 0, 0))
        for p in rings[0]:
            c += Vector(p)
        verts.append(tuple(c / n)); ci = len(verts) - 1
        for i in range(n):
            faces.append((ci, (i + 1) % n, i))
    if cap_end:
        c = Vector((0, 0, 0))
        for p in rings[-1]:
            c += Vector(p)
        verts.append(tuple(c / n)); ci = len(verts) - 1
        base = (len(rings) - 1) * n
        for i in range(n):
            faces.append((ci, base + i, base + (i + 1) % n))
    return verts, faces


def ring_pts(center, radius, n, u=(1, 0, 0), v=(0, 1, 0)):
    c, u, v = Vector(center), Vector(u), Vector(v)
    return [tuple(c + u * (radius * math.cos(TAU * i / n)) + v * (radius * math.sin(TAU * i / n))) for i in range(n)]


def hull(points):
    """Convex hull of 3D points -> (verts, faces)."""
    if bpy is None:
        return [tuple(p) for p in points], []
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    res = bmesh.ops.convex_hull(bm, input=list(bm.verts))
    bmesh.ops.delete(bm, geom=res["geom_unused"] + res["geom_interior"], context="VERTS")
    bm.verts.ensure_lookup_table()
    idx = {v: i for i, v in enumerate(bm.verts)}
    verts = [tuple(v.co) for v in bm.verts]
    faces = [tuple(idx[v] for v in f.verts) for f in bm.faces]
    bm.free()
    return verts, faces


def xform(part, offset=(0, 0, 0), rot=None, scale=1.0):
    verts, faces = part
    if isinstance(scale, (int, float)):
        scale = (scale, scale, scale)
    out = []
    for v in verts:
        p = Vector((v[0] * scale[0], v[1] * scale[1], v[2] * scale[2]))
        if rot is not None:
            p = rot @ p
        p += Vector(offset)
        out.append(tuple(p))
    return out, faces


def rz(deg):
    return Matrix.Rotation(math.radians(deg), 3, "Z")


def rx(deg):
    return Matrix.Rotation(math.radians(deg), 3, "X")


def to_xz(part):
    """Map a part built in the XY plane (y = up) into the vertical XZ plane."""
    verts, faces = part
    return [(x, z, y) for x, y, z in verts], faces


def bbox(verts):
    xs = [v[0] for v in verts]; ys = [v[1] for v in verts]; zs = [v[2] for v in verts]
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def fit(part, size, about_origin=False):
    """Scale a part to an exact bbox size (None keeps an axis); recentre unless about_origin."""
    verts, faces = part
    lo, hi = bbox(verts)
    sc, off = [], []
    for k in range(3):
        d = hi[k] - lo[k]
        s = 1.0 if (size[k] is None or d < 1e-9) else size[k] / d
        sc.append(s)
        off.append(0.0 if about_origin else -(lo[k] + hi[k]) * 0.5 * s)
    return [(v[0] * sc[0] + off[0], v[1] * sc[1] + off[1], v[2] * sc[2] + off[2]) for v in verts], faces


def jitter_xy(part, amount, keep_z=None):
    verts, faces = part
    out = []
    for v in verts:
        if keep_z is not None and abs(v[2] - keep_z) < 1e-6:
            out.append(v); continue
        s = 1.0 + random.uniform(-amount, amount)
        out.append((v[0] * s, v[1] * s, v[2]))
    return out, faces


def circle2d(cx, cy, r, n, a0=0.0):
    return [(cx + r * math.cos(a0 + TAU * i / n), cy + r * math.sin(a0 + TAU * i / n)) for i in range(n)]


def rect2d(cx, cy, hw, hh, ang=0.0):
    c, s = math.cos(ang), math.sin(ang)
    out = []
    for dx, dy in ((-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)):
        out.append((cx + dx * c - dy * s, cy + dx * s + dy * c))
    return out


def rounded_rect2d(hw, hh, r, n=6):
    pts = []
    for cx, cy, a0 in ((hw - r, -hh + r, -TAU / 4), (hw - r, hh - r, 0), (-hw + r, hh - r, TAU / 4), (-hw + r, -hh + r, TAU / 2)):
        for i in range(n + 1):
            a = a0 + (TAU / 4) * i / n
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def teardrop2d(length, w, n=10):
    """Round base at the origin (circle radius w), pointed tip at (0, length)."""
    cy = w
    d = length - cy
    th = math.acos(w / d)
    a_start = TAU / 4 - th
    a_end = -(TAU * 3 / 4 - th)
    pts = [(0.0, length)]
    for i in range(n + 1):
        a = a_start + (a_end - a_start) * i / n
        pts.append((w * math.cos(a), cy + w * math.sin(a)))
    return pts


def feather(root, direction, length, width, bend=(0, 0, 0), up=Y, n=12, tip=0.7, ht=0.03):
    """Flat tapered feather from root along direction, curving by bend*t^2, rounded tip."""
    d = Vector(direction).normalized()
    pts, hw = [], []
    for i in range(n):
        t = i / (n - 1)
        pts.append(tuple(Vector(root) + d * (length * t) + Vector(bend) * (t * t)))
        w = width * min(1.0, t / 0.22) ** 0.6
        if t > tip:
            s = (t - tip) / (1 - tip)
            w = width * math.sqrt(max(0.0, 1 - s * s))
        hw.append(max(w, 0.015))
    return ribbon(pts, perps_from_centers(pts, up), hw, ht, up)


def petal(length, rise, w, n=12, ht=0.02, rise_pow=1.7):
    """Upturned petal along +Y from the origin; tip rises by `rise`."""
    pts, hw = [], []
    for i in range(n):
        t = i / (n - 1)
        pts.append((0.0, length * t, rise * t ** rise_pow))
        hw.append(max(w * math.sin(math.pi * t ** 0.8) ** 0.8, 0.012))
    return ribbon(pts, perps_from_centers(pts, UP), hw, ht, UP)


built = {}
wing_parts = {}

# ================================================================ WINGS
def spar(length, w0, w1):
    pts = [(length * t, 0, 0) for t in (0, 0.33, 0.66, 1.0)]
    return ribbon(pts, [(0, 0, 1)] * 4, [w0, w0 * 0.85, w1 * 1.3, w1], 0.06, Y)

# 1 upper arm: spar 4 long + 4 short feathers hanging back/down
parts = [spar(4.0, 0.2, 0.1), sphere(0.22, 1, 10, 6)]
for k, x in enumerate((0.7, 1.55, 2.4, 3.25)):
    L = (1.6, 1.85, 1.95, 1.8)[k]
    parts.append(feather((x, 0.02 * (k % 2), 0.05), (-0.35, 0, -1), L, 0.3, bend=(-0.2, 0, 0)))
v, f = merge(parts)
wing_parts["VFX2_WingUpper"] = (v, f)
built["VFX2_WingUpper"] = make("VFX2_WingUpper", v, f)

# 2 forearm: spar 4 long + 5 longer feathers
parts = [spar(4.0, 0.17, 0.09), sphere(0.19, 1, 10, 6)]
for k, x in enumerate((0.5, 1.3, 2.1, 2.9, 3.7)):
    L = (2.3, 2.6, 2.9, 3.0, 2.8)[k]
    parts.append(feather((x, 0.02 * (k % 2), 0.05), (-0.25, 0, -1), L, 0.36, bend=(-0.25, 0, 0)))
v, f = merge(parts)
wing_parts["VFX2_WingFore"] = (v, f)
built["VFX2_WingFore"] = make("VFX2_WingFore", v, f)

# 3 hand: 5 primaries fanning 0..35 deg below +X, 6..4 long, rounded tips
parts = [sphere(0.24, 1, 10, 6)]
for k in range(5):
    a = math.radians(35 * k / 4)
    L = 6.0 - 0.5 * k
    d = (math.cos(a), 0, -math.sin(a))
    parts.append(feather((0, 0.05 * k - 0.1, -0.05 * k), d, L, 0.5, bend=(0, 0, -0.45), tip=0.72))
v, f = merge(parts)
wing_parts["VFX2_WingPrimaries"] = (v, f)
built["VFX2_WingPrimaries"] = make("VFX2_WingPrimaries", v, f)

# 3b mirrored LEFT copies of the three wing segments (across the YZ plane, extend -X).
# make() recalculates normals so the mirrored shells are not inside-out.
def mirror_x(part):
    verts, faces = part
    return [(-x, y, z) for x, y, z in verts], faces

for src in ("VFX2_WingUpper", "VFX2_WingFore", "VFX2_WingPrimaries"):
    v, f = mirror_x(wing_parts[src])
    built[src + "L"] = make(src + "L", v, f)

# 4 single curved feather, root at origin, up its length (+Z)
parts = [feather((0, 0, 0), (0, 0, 1), 1.2, 0.17, bend=(0.18, 0, 0), ht=0.02),
         ribbon([(0, 0, 0), (0.05, 0, 0.35), (0.14, 0, 0.75)], [(1, 0, 0)] * 3, [0.03, 0.025, 0.012], 0.03, Y)]
v, f = merge(parts)
built["VFX2_Feather"] = make("VFX2_Feather", v, f)

# 5 whole wing silhouette 7 x 3.3 with 7 feather tips (XZ plane, root at origin)
outline = [(0, 0.5), (0.6, 1.4), (1.5, 2.3), (2.8, 3.0), (4.2, 3.3), (5.6, 3.2), (6.5, 2.9), (7.0, 2.5),
           (6.3, 2.3), (6.4, 1.6), (5.6, 1.8), (5.5, 1.0), (4.7, 1.3), (4.5, 0.5), (3.7, 0.9), (3.4, 0.15),
           (2.7, 0.6), (2.3, 0.0), (1.6, 0.45), (1.2, 0.0), (0.5, 0.3), (0.0, 0.0)]
v, f = to_xz(slab([outline], 0.03, check="WingSilhouette"))
built["VFX2_WingSilhouette"] = make("VFX2_WingSilhouette", v, f)

# ================================================================ FIRE
# 6 fan of 16 teardrop petals in XY, alternating z levels
parts = []
td = teardrop2d(4.5, 0.55, 12)
for i in range(16):
    z = (-0.075, -0.025, 0.025, 0.075)[i % 4]
    parts.append(xform(slab([td], 0.02, z=0.0), rot=rz(360 * i / 16 - 90), offset=(0, 0, z)))
v, f = merge(parts)
built["VFX2_FlamePetalFan"] = make("VFX2_FlamePetalFan", v, f)

# 7 one teardrop petal, root at origin, +Y
v, f = slab([td], 0.025)
built["VFX2_FlamePetal"] = make("VFX2_FlamePetal", v, f)

# 8 sun disc r8: 24 triangular rays cut into the rim, ring of 24 holes at r6
outer = []
for i in range(48):
    a = TAU * i / 48
    r = 8.0 if i % 2 == 0 else 7.05
    outer.append((r * math.cos(a), r * math.sin(a)))
holes = [circle2d(6 * math.cos(TAU * i / 24), 6 * math.sin(TAU * i / 24), 0.28, 10) for i in range(24)]
v, f = slab([outer] + holes, 0.025)
built["VFX2_SunDisc"] = make("VFX2_SunDisc", v, f)

# 9 scorch ring: annulus 2.5-3.2 with cracked jagged inner edge
inner = []
for i in range(40):
    a = TAU * i / 40
    r = 2.5 + random.uniform(-0.22, 0.16) * (1 if i % 2 else 0.4)
    inner.append((r * math.cos(a), r * math.sin(a)))
v, f = slab([circle2d(0, 0, 3.2, 64), inner], 0.03)
built["VFX2_ScorchRing"] = make("VFX2_ScorchRing", v, f)

# ================================================================ BODY
def rock_points(n, radii, lo=0.72):
    pts = []
    for i in range(n):
        u = random.uniform(-1, 1); th = random.uniform(0, TAU); s = math.sqrt(1 - u * u)
        k = random.uniform(lo, 1.0)
        pts.append((radii[0] * s * math.cos(th) * k, radii[1] * s * math.sin(th) * k, radii[2] * u * k))
    return pts

# 10 jagged rock chunk ~1 x 1.2 x 0.8
v, f = fit(hull(rock_points(18, (0.5, 0.6, 0.4))), (1.0, 1.2, 0.8))
built["VFX2_ShardChunk"] = make("VFX2_ShardChunk", v, f)

# 11 thin jagged sliver 0.2 x 2.0 x 0.5
pts = rock_points(12, (0.1, 1.0, 0.25), 0.5) + [(0, 1.0, 0.0), (0, -1.0, 0.05), (0.05, 0.1, 0.25), (-0.05, -0.3, -0.25)]
v, f = fit(hull(pts), (0.2, 2.0, 0.5))
built["VFX2_ShardSliver"] = make("VFX2_ShardSliver", v, f)

# ================================================================ RIFT / TIME
# 12 rift lip: torn vertical edge 9 tall, 1.2 wide, 7 teeth pointing +X, bottom at origin
pts = [(-0.3, 0.0), (-0.3, 9.0), (0.1, 9.0)]
h = 9.0 / 7
for k in range(7):
    top = 9.0 - k * h
    pts.append((0.9 - random.uniform(0, 0.15), top - h * random.uniform(0.35, 0.6)))
    pts.append((random.uniform(0.0, 0.2), top - h))
pts[-1] = (0.15, 0.0)
v, f = to_xz(slab([pts], 0.03, check="RiftLip"))
built["VFX2_RiftLip"] = make("VFX2_RiftLip", v, f)

# 13 rift void: 5 x 9 panel with 3 interlocking gear-outline ridges (raised 0.05 on +Y)
def gear_loop(cx, cy, R, teeth, depth):
    pts = []
    for i in range(teeth * 4):
        a = TAU * i / (teeth * 4)
        r = R + depth if (i % 4) in (0, 1) else R - depth
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

def gear_outline(cx, cy, R, teeth, width=0.16, depth=0.13):
    return slab([gear_loop(cx, cy, R, teeth, depth), gear_loop(cx, cy, R - width, teeth, depth)], 0.025, z=0.055)

parts = [slab([rect2d(0, 0, 2.5, 4.5)], 0.03),
         gear_outline(0.3, 1.6, 1.3, 12), gear_outline(-1.2, -0.1, 0.85, 8), gear_outline(0.29, -1.35, 1.1, 10),
         ]
for cx, cy, r in ((0.3, 1.6, 0.25), (-1.2, -0.1, 0.18), (0.29, -1.35, 0.22)):  # hubs
    parts.append(slab([circle2d(cx, cy, r, 12)], 0.025, z=0.055))
v, f = to_xz(merge(parts))
built["VFX2_RiftVoid"] = make("VFX2_RiftVoid", v, f)

# 14 ghost wisp: hooded head r0.8 at origin, shoulders, tapering tail 2.5 down -Z
parts = [sphere(0.8, 1.0, 16, 10),
         xform(sphere(1.0, 1.0, 16, 8), scale=(1.05, 0.6, 0.42), offset=(0, 0, -0.85))]
rings = []
for i in range(9):
    t = i / 8
    z = -0.9 - 2.4 * t
    r = 0.78 * (1 - t) ** 1.2 + 0.05
    rings.append(ring_pts((0.28 * math.sin(t * math.pi * 1.3), 0.0, z), r, 12))
parts.append(rings_tube(rings))
v, f = merge(parts)
built["VFX2_GhostWisp"] = make("VFX2_GhostWisp", v, f, smooth=True)

# 15 clock ring: annulus 5.4-6 with 12 numeral blocks and 60 tick notches
parts = [band(5.4, 6.0, 0.03, 96)]
for h in range(1, 13):
    a = TAU / 4 - TAU * h / 12
    r, w = 5.72, (0.07, 0.11, 0.09, 0.13, 0.1, 0.12, 0.08, 0.12, 0.1, 0.09, 0.07, 0.11)[h - 1]
    if h >= 10:  # two bars
        for off in (-0.13, 0.13):
            parts.append(box((r * math.cos(a) - off * math.sin(a), r * math.sin(a) + off * math.cos(a), 0.06), (0.17, 0.055, 0.045), a))
    else:
        parts.append(box((r * math.cos(a), r * math.sin(a), 0.06), (0.17, w, 0.045), a))
for i in range(60):
    a = TAU * i / 60
    big = i % 5 == 0
    parts.append(box((5.41 * math.cos(a), 5.41 * math.sin(a), 0), (0.13 if big else 0.08, 0.045 if big else 0.025, 0.05), a))
v, f = merge(parts)
built["VFX2_ClockRing"] = make("VFX2_ClockRing", v, f)

# 16/17 clock hands, pivot at origin, +Y
def hand(tip, tail, hw):
    outline = [(0, tip), (hw * 0.85, tip * 0.72), (hw, 0.0), (hw * 0.7, tail), (0, tail - 0.1), (-hw * 0.7, tail), (-hw, 0.0), (-hw * 0.85, tip * 0.72)]
    return merge([slab([outline], 0.03), cylinder(hw * 1.5, -0.04, 0.04, 16)])

v, f = hand(4.6, -0.3, 0.15)
built["VFX2_ClockHand"] = make("VFX2_ClockHand", v, f)
v, f = hand(3.0, -0.3, 0.18)
built["VFX2_ClockHandShort"] = make("VFX2_ClockHandShort", v, f)

# 18 tick sigil: disc r6 with 60 rim slots, 12 larger
holes = []
for i in range(60):
    a = TAU * i / 60
    if i % 5 == 0:
        holes.append(rect2d(5.35 * math.cos(a), 5.35 * math.sin(a), 0.4, 0.09, a))
    else:
        holes.append(rect2d(5.55 * math.cos(a), 5.55 * math.sin(a), 0.2, 0.04, a))
v, f = slab([circle2d(0, 0, 6.0, 96)] + holes, 0.02)
built["VFX2_TickSigil"] = make("VFX2_TickSigil", v, f)

# 19 numeral block 0.8 x 1.2 x 0.1 (glyph-like notch)
v, f = slab([[(-0.4, -0.6), (0.4, -0.6), (0.4, 0.6), (-0.4, 0.6), (-0.4, 0.3), (-0.08, 0.3), (-0.08, -0.3), (-0.4, -0.3)]], 0.05, check="Numeral")
built["VFX2_Numeral"] = make("VFX2_Numeral", v, f)

# 20 glass shard: thin triangle 0.6 x 2.2 x 0.06, slightly bent
pts, hw = [], []
for i in range(7):
    t = i / 6
    pts.append((0.0, -1.1 + 2.2 * t, 0.045 * math.sin(math.pi * t)))
    hw.append(0.3 * (1 - t) ** 0.9 + 0.01)
v, f = ribbon(pts, perps_from_centers(pts, UP), hw, 0.03, UP)
built["VFX2_GlassShard"] = make("VFX2_GlassShard", v, f)

# 21 hourglass frame 1.6 tall, centred
parts = [cylinder(0.5, 0.72, 0.8, 16), cylinder(0.5, -0.8, -0.72, 16)]
for i in range(3):
    a = TAU * i / 3 + TAU / 12
    parts.append(box((0.42 * math.cos(a), 0.42 * math.sin(a), 0), (0.035, 0.035, 0.72), a))
rings = []
for i in range(11):
    z = -0.7 + 1.4 * i / 10
    r = 0.08 + 0.33 * (abs(z) / 0.7) ** 0.8
    rings.append(ring_pts((0, 0, z), r, 12))
parts.append(rings_tube(rings))
v, f = merge(parts)
built["VFX2_Hourglass"] = make("VFX2_Hourglass", v, f)

# ================================================================ GROUND
def crack(length, w0, branches, seed, jit=0.22, n=13):
    """Jagged flat crack along +Y from the origin, raised 0.06 lip on both edges.
    branches: list of (t, side, length_frac, angle_deg)."""
    random.seed(seed)

    def path(start, direction, L, w, n):
        d = Vector(direction).normalized()
        side = Vector((-d.y, d.x, 0))
        pts, hw = [], []
        for i in range(n):
            t = i / (n - 1)
            j = random.uniform(-jit, jit) * math.sin(t * math.pi) ** 0.5 * L * 0.12 if 0 < i < n - 1 else 0
            pts.append(tuple(Vector(start) + d * (L * t) + side * j))
            hw.append(w * (1 - t) ** 0.8 + 0.02)
        return pts, hw

    def strokes(pts, hw):
        perps = perps_from_centers(pts, UP)
        out = [ribbon(pts, perps, hw, 0.02, UP)]
        for sgn in (1, -1):
            c = [tuple(Vector(p) + Vector(q) * (sgn * (w + 0.03)) + Vector((0, 0, 0.03))) for p, q, w in zip(pts, perps, hw)]
            out.append(ribbon(c, perps, [0.04] * len(c), 0.03, UP))
        return out, pts, hw

    parts, pts, hw = strokes(*path((0, 0, 0), (0, 1, 0), length, w0, n))
    for (t, side, lf, ang) in branches:
        k = int(round(t * (n - 1)))
        d = Vector(pts[min(k + 1, n - 1)]) - Vector(pts[max(k - 1, 0)])
        d = rz(side * ang) @ d
        p2, pts2, hw2 = strokes(*path(pts[k], d, length * lf, hw[k] * 0.7, 7))
        parts += p2
    return merge(parts)

v, f = crack(6.0, 0.25, [(0.5, 1, 0.45, 38)], 101)
built["VFX2_CrackA"] = make("VFX2_CrackA", v, f)
v, f = crack(6.0, 0.22, [(0.35, -1, 0.4, 42), (0.7, 1, 0.35, 30)], 202, jit=0.3)
built["VFX2_CrackB"] = make("VFX2_CrackB", v, f)
v, f = crack(6.0, 0.14, [(0.42, 1, 0.5, 26), (0.55, -1, 0.3, 48)], 303, jit=0.18, n=15)
built["VFX2_CrackC"] = make("VFX2_CrackC", v, f)
random.seed(12)

# 25 cobble 0.9 x 0.6 x 0.8
v, f = fit(hull(rock_points(40, (0.45, 0.3, 0.4), 0.9)), (0.9, 0.6, 0.8))
built["VFX2_Cobble"] = make("VFX2_Cobble", v, f)

# 26 grass clump: 7 flat blades fanning from the origin, 1.2 tall
parts = []
for i in range(7):
    az = TAU * i / 7 + random.uniform(-0.2, 0.2)
    lean = math.radians(random.uniform(10, 34))
    L = random.uniform(0.95, 1.22)
    if i == 0:
        lean, L = math.radians(10), 1.23
    d = Vector((math.sin(lean) * math.cos(az), math.sin(lean) * math.sin(az), math.cos(lean)))
    o = Vector((math.cos(az), math.sin(az), 0))
    pts, hw = [], []
    for k in range(7):
        t = k / 6
        pts.append(tuple(d * (L * t) + o * (0.3 * t * t)))
        hw.append(0.05 * (1 - t) + 0.01)
    up = (-math.sin(az), math.cos(az), 0)
    parts.append(ribbon(pts, perps_from_centers(pts, up), hw, 0.008, up))
v, f = merge(parts)
built["VFX2_GrassClump"] = make("VFX2_GrassClump", v, f)

# 27 hay straw: thin bent straw 1.5 long, centred
pts = [(-0.75 + 1.5 * t, 0.0, 0.18 * (1 - abs(2 * t - 1) ** 1.4)) for t in (i / 8 for i in range(9))]
v, f = ribbon(pts, perps_from_centers(pts, UP), [0.03] * 9, 0.03, UP)
built["VFX2_HayStraw"] = make("VFX2_HayStraw", v, f)

# ================================================================ SKY / WEATHER
# 28 cloud lobe: 5 merged spheres, 6 x 4 x 3
parts = []
for cx, cy, cz, r in ((0, 0, 0, 1.6), (-1.9, 0.2, -0.3, 1.25), (1.8, -0.2, -0.2, 1.35), (0.5, 1.1, 0.2, 1.1), (-0.6, -1.1, 0.1, 1.05)):
    parts.append(xform(sphere(r, 0.8, 16, 10), offset=(cx, cy, cz)))
v, f = fit(merge(parts), (6, 4, 3))
built["VFX2_CloudLobe"] = make("VFX2_CloudLobe", v, f, smooth=True)

# 29 lightning bull: angular side-view silhouette, facing +X, head down, 4 x 2.5, chest at origin
bull = [(-2.0, 0.35), (-1.85, 0.75), (-1.55, 0.85), (-1.0, 0.95), (-0.45, 1.15), (0.1, 1.1), (0.55, 0.85),
        (0.9, 0.55), (1.05, 0.6), (1.45, 0.95), (1.25, 0.45), (1.65, 0.55), (1.35, 0.25), (1.95, -0.45),
        (2.0, -0.75), (1.7, -0.85), (1.35, -0.6), (1.05, -0.45), (0.75, -0.55), (0.95, -0.85), (1.45, -1.1),
        (1.4, -1.3), (0.95, -1.15), (0.65, -0.95), (0.5, -1.2), (0.3, -1.4), (0.1, -1.3), (0.2, -0.95),
        (-0.1, -0.75), (-0.7, -0.75), (-0.9, -1.0), (-0.85, -1.35), (-1.1, -1.45), (-1.2, -1.1), (-1.35, -0.85),
        (-1.6, -1.1), (-2.0, -1.35), (-2.1, -1.2), (-1.75, -0.85), (-1.55, -0.5), (-1.75, -0.1)]
chest = (0.75, -0.55)
bull = [(x - chest[0], y - chest[1]) for x, y in bull]
v, f = fit(to_xz(slab([bull], 0.03, check="LightningBull")), (4.0, None, 2.5), about_origin=True)
built["VFX2_LightningBull"] = make("VFX2_LightningBull", v, f)

# 30 tornado rune ring 2.6-3.0 with 12 rune slots
holes = []
for i in range(12):
    a = TAU * i / 12
    cx, cy = 2.8 * math.cos(a), 2.8 * math.sin(a)
    ang = a + (0, TAU / 4, TAU / 8, -TAU / 8)[i % 4]
    holes.append(rect2d(cx, cy, 0.11, 0.035, ang))
    da = a + 0.06
    holes.append(rect2d(2.8 * math.cos(da), 2.8 * math.sin(da) , 0.03, 0.03, a) if i % 3 == 0 else
                 rect2d(2.72 * math.cos(a + 0.03), 2.72 * math.sin(a + 0.03), 0.025, 0.025, a))
v, f = slab([circle2d(0, 0, 3.0, 72), circle2d(0, 0, 2.6, 60)] + holes, 0.02)
built["VFX2_TornadoRing"] = make("VFX2_TornadoRing", v, f)

# 31 coin r0.35, thick 0.08, raised rim and star on each face
parts = [cylinder(0.33, -0.025, 0.025, 24), band(0.30, 0.35, 0.04, 24),
         xform(star(4, 0.2, 0.06, 0.012), offset=(0, 0, 0.033)), xform(star(4, 0.2, 0.06, 0.012), offset=(0, 0, -0.033))]
v, f = merge(parts)
built["VFX2_Coin"] = make("VFX2_Coin", v, f)

# 32 ribbon twist: 10 tall, 1 wide, 2 full twists
N = 61
pts, perps, ups = [], [], []
for i in range(N):
    t = i / (N - 1)
    a = 2 * TAU * t
    pts.append((0, 0, -5 + 10 * t))
    perps.append((math.cos(a), math.sin(a), 0))
    ups.append((-math.sin(a), math.cos(a), 0))
v, f = ribbon(pts, perps, [0.5] * N, 0.02, ups)
built["VFX2_RibbonTwist"] = make("VFX2_RibbonTwist", v, f)

# ================================================================ STARS / SPACE
# 33 star point flare 1.4 across
v, f = star(4, 0.7, 0.14, 0.03)
built["VFX2_StarPoint"] = make("VFX2_StarPoint", v, f)

# 34 ringed planet: sphere r0.9 + flat ring 1.3-2.1 tilted 20 deg
v, f = merge([sphere(0.9, 1.0, 24, 14), xform(band(1.3, 2.1, 0.02, 64), rot=rx(20))])
built["VFX2_PlanetRinged"] = make("VFX2_PlanetRinged", v, f, smooth=True)

# 35 lasso loop: torus R3 tube 0.12 with 12 small 4-point stars on it
parts = [torus(3.0, 0.12, 0.12, 96, 8)]
for i in range(12):
    a = TAU * i / 12
    parts.append(xform(star(4, 0.28, 0.08, 0.03), rot=rz(math.degrees(a)), offset=(3 * math.cos(a), 3 * math.sin(a), 0.13)))
v, f = merge(parts)
built["VFX2_LassoLoop"] = make("VFX2_LassoLoop", v, f)

# 36 constellation: 7 spheres r0.2 on a circle r2.5 joined by 0.06 bars
nodes = []
for i in range(7):
    a = TAU * i / 7 + random.uniform(-0.15, 0.15)
    r = 2.5 if i % 2 == 0 else 2.5 - random.uniform(0, 0.3)
    nodes.append(Vector((r * math.cos(a), r * math.sin(a), 0)))
parts = [xform(sphere(0.2, 1.0, 10, 6), offset=tuple(p)) for p in nodes]
links = [(i, (i + 1) % 7) for i in range(7)] + [(0, 3)]
for a, b in links:
    c = [tuple(nodes[a]), tuple(nodes[b])]
    parts.append(ribbon(c, perps_from_centers(c, UP), [0.03, 0.03], 0.03, UP))
v, f = fit(merge(parts), (None, None, None))
built["VFX2_Constellation"] = make("VFX2_Constellation", v, f)

# 37 light step: rounded rectangle 2.4 x 1.0 x 0.1 with soft chamfer
full = rounded_rect2d(1.2, 0.5, 0.25)
ins = rounded_rect2d(1.17, 0.47, 0.23)
v, f = loft([ins, full, full, ins], [-0.05, -0.025, 0.025, 0.05])
built["VFX2_LightStep"] = make("VFX2_LightStep", v, f)

# 38 halo crystal: hexagonal stalactite 1.8 long, root at origin, pointing -Z
v, f = crystal([(-1.45, 0.2), (-0.35, 0.33), (-0.06, 0.3)], 0.0, -1.8, 6, twist=0.15)
built["VFX2_HaloCrystal"] = make("VFX2_HaloCrystal", v, f)

# 39 prism crystal: hexagonal bipyramid 2.2 tall
v, f = crystal([(-0.55, 0.45), (0.55, 0.45)], 1.1, -1.1, 6)
built["VFX2_PrismCrystal"] = make("VFX2_PrismCrystal", v, f)

# 40 gem: brilliant-like cut, 0.6 across
v, f = crystal([(0.0, 0.3), (0.06, 0.3), (0.2, 0.18)], 0.22, -0.32, 8, twist=TAU / 16)
built["VFX2_Gem"] = make("VFX2_Gem", v, f)

# ================================================================ NATURE
# 41 cherry trunk: tapered bent trunk 10 tall, base at origin, 3 branch stubs
rings = []
axis = []
for i in range(16):
    t = i / 15
    c = Vector((0.7 * math.sin(t * math.pi * 0.9), 0.35 * math.sin(t * math.pi * 1.6), 10 * t))
    axis.append(c)
    r = 0.55 * (1 - t) ** 0.7 + 0.12
    rings.append(ring_pts(c, r * random.uniform(0.92, 1.08), 8))
parts = [rings_tube(rings)]
for t, az in ((0.42, 20), (0.63, 160), (0.84, 280)):
    k = int(round(t * 15))
    base = axis[k]
    d = Vector((math.cos(math.radians(az)), math.sin(math.radians(az)), 0.85)).normalized()
    side = Vector((0, 0, 1)).cross(d).normalized()
    upv = d.cross(side).normalized()
    r0 = (0.55 * (1 - t) ** 0.7 + 0.12) * 0.6
    br = []
    for j in range(4):
        s = j / 3
        br.append(ring_pts(base + d * (1.4 * s), r0 * (1 - s) + 0.07, 6, u=side, v=upv))
    parts.append(rings_tube(br))
v, f = merge(parts)
built["VFX2_CherryTrunk"] = make("VFX2_CherryTrunk", v, f)

# 42 blossom canopy: 6 merged spheres, 7 x 7 x 4
parts = []
for cx, cy, cz, r in ((0, 0, 0.2, 2.4), (2.3, 0.8, -0.2, 1.9), (-2.2, -0.6, -0.1, 2.0), (0.6, 2.3, -0.3, 1.7), (-0.5, -2.3, 0.1, 1.8), (1.2, -1.0, 0.9, 1.6)):
    parts.append(xform(sphere(r, 0.65, 16, 10), offset=(cx, cy, cz)))
v, f = fit(merge(parts), (7, 7, 4))
built["VFX2_Canopy"] = make("VFX2_Canopy", v, f, smooth=True)

# 43 lotus platform: disc r2.4 with 12 upturned petals rising 0.8
parts = [cylinder(2.4, -0.06, 0.06, 48)]
for i in range(12):
    a = 360 * i / 12
    parts.append(xform(petal(1.7, 0.8, 0.5), rot=rz(a), offset=(1.1 * math.cos(math.radians(a + 90)), 1.1 * math.sin(math.radians(a + 90)), 0.03 + 0.02 * (i % 2))))
v, f = merge(parts)
built["VFX2_Lotus"] = make("VFX2_Lotus", v, f)

# 44 flower crown: ring r0.7 with 6 tiny flowers
parts = [torus(0.7, 0.04, 0.04, 48, 6)]
for i in range(6):
    a = TAU * i / 6
    o = (0.7 * math.cos(a), 0.7 * math.sin(a), 0.03)
    parts.append(xform(star(5, 0.15, 0.06, 0.02), rot=rz(math.degrees(a)), offset=o))
    parts.append(xform(sphere(0.05, 1.0, 8, 5), offset=(o[0], o[1], 0.05)))
v, f = merge(parts)
built["VFX2_FlowerCrown"] = make("VFX2_FlowerCrown", v, f)

# 45 single lotus petal 2.4 long, root at origin, +Y
v, f = petal(2.4, 0.7, 0.6, n=14, ht=0.025)
built["VFX2_LotusPetal"] = make("VFX2_LotusPetal", v, f)

# ================================================================ STORM
# 46 spike crown: ring 2.4-2.8 with 8 spikes 1.6 tall (+Z)
parts = [band(2.4, 2.8, 0.04, 72)]
for i in range(8):
    a = TAU * i / 8
    spike = crystal([(0.0, 0.2)], 1.6, -0.08, 4)
    tilt = Matrix.Rotation(math.radians(10), 3, Vector((-math.sin(a), math.cos(a), 0)))
    parts.append(xform(spike, rot=tilt, offset=(2.6 * math.cos(a), 2.6 * math.sin(a), 0)))
v, f = merge(parts)
built["VFX2_SpikeCrown"] = make("VFX2_SpikeCrown", v, f)

# 47 ice spike: jagged hexagonal spike 3 tall, base at origin
def ice(height, r0, seed):
    random.seed(seed)
    rings = [(0.0, r0), (0.27 * height, r0 * 0.9), (0.57 * height, r0 * 0.65), (0.83 * height, r0 * 0.35)]
    v, f = crystal(rings, height, -0.04, 6, twist=0.3)
    return jitter_xy((v, f), 0.12, keep_z=0.0)

v, f = ice(3.0, 0.42, 7)
built["VFX2_IceSpike"] = make("VFX2_IceSpike", v, f)

# 48 ice spike cluster: 5 spikes 1.5-3.5 fanning out from the origin
parts = []
for k, (hgt, az, tilt) in enumerate(((3.5, 0, 0), (2.6, 40, 24), (2.0, 150, 32), (1.5, 230, 36), (3.0, 310, 18))):
    spike = ice(hgt, 0.16 + 0.07 * hgt, 20 + k)
    rot = Matrix.Rotation(math.radians(tilt), 3, Vector((-math.sin(math.radians(az)), math.cos(math.radians(az)), 0)))
    parts.append(xform(spike, rot=rot, offset=(0.15 * math.cos(math.radians(az)), 0.15 * math.sin(math.radians(az)), 0)))
v, f = merge(parts)
built["VFX2_IceSpikeCluster"] = make("VFX2_IceSpikeCluster", v, f)
random.seed(13)

# ================================================================ VOID
# 49 accretion disc: annulus 2-7 with 3 spiral ridges (raised grooves)
parts = [band(2.0, 7.0, 0.02, 96)]
for k in range(3):
    pts = []
    for i in range(50):
        t = i / 49
        r = 2.2 + 4.6 * t
        a = TAU * k / 3 + t * TAU * 0.8
        pts.append((r * math.cos(a), r * math.sin(a), 0.035))
    parts.append(ribbon(pts, perps_from_centers(pts, UP), [0.08] * 50, 0.02, UP))
v, f = merge(parts)
built["VFX2_AccretionDisc"] = make("VFX2_AccretionDisc", v, f)

# 50 lens sphere r1 smooth
v, f = sphere(1.0, 1.0, 32, 16)
built["VFX2_LensSphere"] = make("VFX2_LensSphere", v, f, smooth=True)

# 51 portal frame: vertical torn oval 7 tall x 5 wide, 10 rune notches
outer, inner = [], []
for i in range(72):
    a = TAU * i / 72
    j = random.uniform(-0.08, 0.14)
    outer.append(((2.5 + j) * math.cos(a), (3.5 + j) * math.sin(a)))
for i in range(70):
    a = TAU * i / 70
    j = random.uniform(-0.08, 0.06)
    if i % 7 == 3:
        j += 0.3
    inner.append(((1.9 + j) * math.cos(a), (2.85 + j) * math.sin(a)))
v, f = fit(to_xz(slab([outer, inner], 0.03)), (5.0, None, 7.0))
built["VFX2_PortalFrame"] = make("VFX2_PortalFrame", v, f)

# ================================================================ report
report = {}
pivots = {}
for name, ob in built.items():
    d = ob.dimensions
    if bpy is None:
        lo, hi = ob.lo, ob.hi
        ntris = ob.ntris
    else:
        lo, hi = bbox([v.co for v in ob.data.vertices])
        ntris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    report[name] = [round(d.x, 2), round(d.y, 2), round(d.z, 2), ntris]
    pivots[name] = {"bbox_center": [round((lo[k] + hi[k]) / 2, 4) for k in range(3)],
                    "size": [round(hi[k] - lo[k], 4) for k in range(3)]}

result = {"count": len(built), "meshes": report, "pivots": pivots}

if bpy is not None and bpy.app.background and "--export" in sys.argv:
    bpy.ops.export_scene.gltf(filepath="Aura_Pack.glb", export_format="GLB", use_selection=False)

if bpy is None and __name__ == "__main__":
    import json
    print(json.dumps(report, indent=0))
    print("count", len(built))
