# Cursed Dodgeball grey-box venue: builds the sunken pit, Ghost ring, stands, tunnels and a plain ball as
# white meshes for later art replacement. 1 Blender unit = 1 Roblox stud, Z up here (glTF export flips).
# Usage: blender --background --python build_greybox.py -- out.glb
import bpy
import sys
import math

LENGTH, WIDTH = 70.0, 50.0      # round 1 court
FREE = 4.0                      # free zone to the pit wall
DEPTH = 8.0                     # pit depth
RING = 6.0                      # ghost ring width
ROWS, RISE, ROW_DEPTH = 5, 1.5, 3.0
WALL = 1.0

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

col = bpy.data.collections.new("CursedGreybox")
bpy.context.scene.collection.children.link(col)

def box(name, size, loc):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    for c in ob.users_collection:
        c.objects.unlink(ob)
    col.objects.link(ob)
    return ob

pit_l, pit_w = LENGTH + 2 * FREE, WIDTH + 2 * FREE
box("Floor", (pit_l + 2, pit_w + 2, 1), (0, 0, -0.5))
box("WallN", (pit_l + 2 * WALL, WALL, DEPTH), (0, -(pit_w / 2 + WALL / 2), DEPTH / 2))
box("WallS", (pit_l + 2 * WALL, WALL, DEPTH), (0, (pit_w / 2 + WALL / 2), DEPTH / 2))
gap = 8.0
seg = (pit_w - gap) / 2
for sgn in (-1, 1):
    x = sgn * (pit_l / 2 + WALL / 2)
    box(f"WallE{sgn}A", (WALL, seg, DEPTH), (x, -(gap / 2 + seg / 2), DEPTH / 2))
    box(f"WallE{sgn}B", (WALL, seg, DEPTH), (x, (gap / 2 + seg / 2), DEPTH / 2))
outer_l = pit_l + 2 * WALL + 2 * RING
box("RingN", (outer_l, RING, 1), (0, -(pit_w / 2 + WALL + RING / 2), DEPTH - 0.5))
box("RingS", (outer_l, RING, 1), (0, (pit_w / 2 + WALL + RING / 2), DEPTH - 0.5))
box("RingE", (RING, pit_w + 2 * WALL, 1), ((pit_l / 2 + WALL + RING / 2), 0, DEPTH - 0.5))
box("RingW", (RING, pit_w + 2 * WALL, 1), (-(pit_l / 2 + WALL + RING / 2), 0, DEPTH - 0.5))
for row in range(1, ROWS + 1):
    inset = RING + (row - 1) * ROW_DEPTH + ROW_DEPTH / 2
    top = DEPTH + row * RISE
    len_l = pit_l + 2 * WALL + 2 * (RING + row * ROW_DEPTH)
    half_y = pit_w / 2 + WALL + inset
    half_x = pit_l / 2 + WALL + inset
    box(f"RowN{row}", (len_l, ROW_DEPTH, RISE), (0, -half_y, top - RISE / 2))
    box(f"RowS{row}", (len_l, ROW_DEPTH, RISE), (0, half_y, top - RISE / 2))
    len_w = pit_w + 2 * WALL + 2 * (RING + (row - 1) * ROW_DEPTH)
    box(f"RowE{row}", (ROW_DEPTH, len_w, RISE), (half_x, 0, top - RISE / 2))
    box(f"RowW{row}", (ROW_DEPTH, len_w, RISE), (-half_x, 0, top - RISE / 2))
bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=(0, 0, 1.0), segments=24, ring_count=12)
ball = bpy.context.active_object
ball.name = "BallPlain"
for c in ball.users_collection:
    c.objects.unlink(ball)
col.objects.link(ball)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if argv:
    bpy.ops.export_scene.gltf(filepath=argv[0], export_format="GLB", export_apply=True)
