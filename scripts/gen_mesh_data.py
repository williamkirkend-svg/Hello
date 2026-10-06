#!/usr/bin/env python3
"""Generate src/ReplicatedStorage/FarmLasso/CelebrationFX/AuraMeshData.lua from blender/aura_pack_pivots.json.

The JSON (written by blender/build_aura_pack.py) maps each object name to {"bbox_center": [x, y, z], "size": [x, y, z]}
in Blender units (Z up). Roblox imports with Y up: (x, y, z) -> (x, z, -y). Pivots[name] is the bounding-box centre
measured from the authored origin, in Roblox axes, which AuraKit.Place adds back. Fallback[name] is the stand-in
Part size (Roblox axes) used when the mesh is not imported.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "blender" / "aura_pack_pivots.json"
OUT = ROOT / "src" / "ReplicatedStorage" / "FarmLasso" / "CelebrationFX" / "AuraMeshData.lua"

V1_PIVOTS = {
    "GalaxyArm": (0.636, 0, 1.607), "Wing": (3.38, 1.458, 0), "BoltA": (-0.205, -4.969, 0), "BoltB": (-0.184, -4.923, 0.062),
    "BeamColumn": (0, 0.5, 0), "GodRay": (0, 0.5, 0), "Slash": (0, 0, 0.676), "ShardA": (0, 0.6, 0), "ShardB": (0, 0.25, 0),
}


def rbx(v):
    x, y, z = v
    return (x, z, -y)


def fmt(v):
    return "V(%s, %s, %s)" % tuple(("%.4f" % c).rstrip("0").rstrip(".") or "0" for c in v)


def main():
    data = json.loads(SRC.read_text()) if SRC.exists() else {}
    pivots, fallback = dict(V1_PIVOTS), {}
    for name, info in sorted(data.items()):
        key = name[5:] if name.startswith("VFX2_") else (name[4:] if name.startswith("VFX_") else name)
        c = rbx(info.get("bbox_center", [0, 0, 0]))
        s = rbx(info.get("size", [1, 1, 1]))
        if any(abs(x) > 1e-3 for x in c):
            pivots[key] = c
        fallback[key] = tuple(abs(x) for x in s)
    lines = [
        "-- CelebrationFX.AuraMeshData: per-mesh pivot offsets and stand-in sizes for the Aura mesh pack (generated from",
        "-- blender/aura_pack_pivots.json by scripts/gen_mesh_data.py; edit the JSON or the script, not this file).",
        "-- Roblox centres an imported MeshPart on its bounding box. Pivots[name] is the bounding-box centre measured from",
        "-- the mesh's authored origin, in Roblox axes (Blender x, y, z -> Roblox x, z, -y), at scale 1. AuraKit.Place adds it",
        "-- back so a wing root, a crack root or a petal base lands where the show puts it.",
        "-- Fallback[name] is the Part size AuraKit uses when the mesh is not imported.",
        "local V = Vector3.new",
        "return {",
        "\tPivots = {",
    ]
    for k in sorted(pivots):
        lines.append("\t\t%s = %s," % (k, fmt(pivots[k])))
    lines.append("\t},")
    lines.append("\tFallback = {")
    for k in sorted(fallback):
        s = fallback[k]
        lines.append("\t\t%s = {%s, %s, %s}," % (k, "%.3g" % s[0], "%.3g" % s[1], "%.3g" % s[2]))
    lines += ["\t},", "}", ""]
    OUT.write_text("\n".join(lines))
    print("wrote", OUT, "with", len(pivots), "pivots and", len(fallback), "fallback sizes")
    if not data:
        print("note: no JSON at", SRC, "- only the v1 pivots were written", file=sys.stderr)


if __name__ == "__main__":
    main()
