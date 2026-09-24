"""Build the shore boulders and the sea life with Blender Python.

Run: python3 tools/build_sealife.py (needs the bpy module or Blender's Python).
It writes assets/source/sealife.blend and one glTF per model in
assets/models/sealife/. Sizes are in metres, the board's world unit.

Every model is one joined mesh, because the board draws them in MultiMeshes.
Fish face Blender -Y, which exports as Godot +Z, with the tail towards +Y so
the swim shader can bend it. Plants stand on their origin. The game colors
fish and plants in its own shaders; the materials here are for Blender views.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_kit import (Vector, bmesh, empty, export, from_bmesh, join, material,  # noqa: E402
                         new_collection, reset, save)
from mathutils import noise  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/sealife.blend'
OUT = ROOT / 'assets/models/sealife'

reset('Sealife')
rng = random.Random(1907)
built = []


def finish(name, col, parts):
    root = empty(name, col)
    join(name + 'Mesh', parts, col, root)
    built.append((col, name))


def loft(name, stations, segments, mat, col, parent):
    """A closed body through elliptic rings. Each station is
    (y, half width, half height, centre height); ends close to points."""
    bm = bmesh.new()
    rings = []
    for y, w, h, z in stations:
        if w <= 0 and h <= 0:
            rings.append([bm.verts.new((0, y, z))])
            continue
        ring = []
        for i in range(segments):
            t = math.tau * i / segments
            ring.append(bm.verts.new((math.cos(t) * w, y, z + math.sin(t) * h)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1:
            for i in range(segments):
                bm.faces.new((a[0], b[(i + 1) % segments], b[i]))
        elif len(b) == 1:
            for i in range(segments):
                bm.faces.new((a[i], a[(i + 1) % segments], b[0]))
        else:
            for i in range(segments):
                bm.faces.new((a[i], a[(i + 1) % segments], b[(i + 1) % segments], b[i]))
    return from_bmesh(name, bm, [mat], col, parent, smooth=True)


def sheet(name, points, mat, col, parent):
    """A flat fin or blade from a polygon outline, triangulated as a fan."""
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in points]
    bm.faces.new(verts)
    return from_bmesh(name, bm, [mat], col, parent)


def ribbon(name, path, widths, mat, col, parent, twist=0.0):
    """A strip following a path, turning slowly about it; blades and kelp."""
    bm = bmesh.new()
    rows = []
    for i, (p, w) in enumerate(zip(path, widths)):
        angle = twist * i / max(1, len(path) - 1)
        side = Vector((math.cos(angle), math.sin(angle), 0)) * w
        rows.append((bm.verts.new(Vector(p) - side), bm.verts.new(Vector(p) + side)))
    for (a0, a1), (b0, b1) in zip(rows, rows[1:]):
        bm.faces.new((a0, a1, b1, b0))
    return from_bmesh(name, bm, [mat], col, parent, smooth=True)


def tube(name, path, radii, mat, col, parent, segments=6, open_top=False):
    """A tapered tube along a path; branches, stipes and sponges."""
    bm = bmesh.new()
    rings = []
    for i, (p, r) in enumerate(zip(path, radii)):
        p = Vector(p)
        ahead = Vector(path[min(i + 1, len(path) - 1)]) - Vector(path[max(i - 1, 0)])
        axis = ahead.normalized() if ahead.length > 1e-6 else Vector((0, 0, 1))
        side = axis.cross(Vector((1, 0, 0)) if abs(axis.x) < .9 else Vector((0, 1, 0))).normalized()
        up = axis.cross(side)
        rings.append([bm.verts.new(p + (side * math.cos(t) + up * math.sin(t)) * r)
                      for t in (math.tau * k / segments for k in range(segments))])
    for a, b in zip(rings, rings[1:]):
        for k in range(segments):
            bm.faces.new((a[k], a[(k + 1) % segments], b[(k + 1) % segments], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    if not open_top:
        bm.faces.new(rings[-1])
    return from_bmesh(name, bm, [mat], col, parent, smooth=True)


# ---------------------------------------------------------------- boulders
ROCK = material('PBR_Rock', '8c8478')
for n in range(4):
    rock_col = new_collection('Boulder%d' % n)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    seed = Vector((n * 7.3, n * 3.1, n * 5.7))
    squash = (1.0 + rng.uniform(-.2, .3), 1.0 + rng.uniform(-.25, .2), .55 + rng.uniform(0, .25))
    for v in bm.verts:
        d = v.co.normalized()
        # Broad lumps, then facets, like weathered granite and limestone.
        bump = noise.noise(d * 1.3 + seed) * .28 + noise.noise(d * 3.1 + seed) * .1
        v.co = Vector((d.x * squash[0], d.y * squash[1], d.z * squash[2])) * (1 + bump)
        v.co.z = max(v.co.z, -.35)
    parts = [from_bmesh('Boulder%dBody' % n, bm, [ROCK], rock_col, None)]
    finish('Boulder%d' % n, rock_col, parts)

# ---------------------------------------------------------------- fish
FISH = material('Fish', 'a9b7c0', roughness=.4)


def fish(name, length, depth, width, tail, dorsal, stretch=1.0):
    col = new_collection(name)
    half = length / 2
    stations = [
        (-half, 0, 0, 0),
        (-half * .8, width * .55, depth * .5, 0),
        (-half * .45, width, depth, depth * .05),
        (0, width * .92, depth * .95, depth * .06),
        (half * .45, width * .6, depth * .62 * stretch, depth * .02),
        (half * .8, width * .25, depth * .25, 0),
        (half * .9, 0, 0, 0),
    ]
    parts = [loft(name + 'Body', stations, 10, FISH, col, None)]
    # Tail fin forked behind the body, and a dorsal fin along the back.
    y = half * .86
    parts.append(sheet(name + 'Tail', [(0, y, 0), (0, y + tail, tail * .75), (0, y + tail * .7, 0),
                                       (0, y + tail, -tail * .7)], FISH, col, None))
    parts.append(sheet(name + 'Dorsal', [(0, -half * .2, depth * .9), (0, half * .05, depth * .9 + dorsal),
                                         (0, half * .35, depth * .6)], FISH, col, None))
    parts.append(sheet(name + 'Anal', [(0, half * .15, -depth * .8), (0, half * .45, -depth * .8 - dorsal * .5),
                                       (0, half * .55, -depth * .45)], FISH, col, None))
    finish(name, col, parts)


# Sardines are slim, bream deep-bodied, wrasse long with a rounded tail.
fish('Sardine', 1.0, .11, .07, .2, .08)
fish('Bream', 1.1, .26, .08, .24, .12)
fish('Wrasse', 1.2, .16, .08, .16, .07, stretch=1.15)

# ---------------------------------------------------------------- plants
KELP = material('Kelp', '6b6a2c')
kelp_col = new_collection('Kelp')
parts = []
for s in range(3):
    base = Vector((rng.uniform(-.4, .4), rng.uniform(-.4, .4), 0))
    lean = Vector((rng.uniform(-.25, .25), rng.uniform(-.25, .25), 0))
    height = rng.uniform(4.2, 5.6)
    path = [base + lean * (k / 10) ** 2 * 3 + Vector((0, 0, height * k / 10)) for k in range(11)]
    parts.append(tube('Stipe%d' % s, path, [.05 - .003 * k for k in range(11)], KELP, kelp_col, None, 5))
    for b in range(4, 11, 2):
        p = path[b]
        turn = rng.uniform(0, math.tau)
        out = Vector((math.cos(turn), math.sin(turn), .35)).normalized()
        blade = [p + out * (1.3 * k / 6) + Vector((0, 0, -.25 * math.sin(k / 6 * math.pi))) for k in range(7)]
        widths = [.03, .12, .16, .16, .13, .08, .01]
        parts.append(ribbon('Blade%d_%d' % (s, b), blade, widths, KELP, kelp_col, None, twist=.8))
finish('Kelp', kelp_col, parts)

GRASS = material('Seagrass', '4f7f3b')
grass_col = new_collection('Seagrass')
parts = []
for b in range(14):
    turn = rng.uniform(0, math.tau)
    lean = rng.uniform(.1, .45)
    height = rng.uniform(.8, 1.4)
    root = Vector((math.cos(turn) * .12, math.sin(turn) * .12, 0))
    path = [root + Vector((math.cos(turn) * lean * (k / 6) ** 1.6, math.sin(turn) * lean * (k / 6) ** 1.6,
                           height * k / 6)) for k in range(7)]
    parts.append(ribbon('Leaf%d' % b, path, [.035, .04, .04, .038, .034, .028, .012], GRASS, grass_col, None,
                        twist=rng.uniform(-1, 1)))
finish('Seagrass', grass_col, parts)

CORAL = material('Coral', 'c8372d')
coral_col = new_collection('Coral')
parts = []


def branch(start, direction, length, radius, depth):
    steps = 4
    path = [start]
    d = direction.normalized()
    for k in range(steps):
        d = (d + Vector((rng.uniform(-.25, .25), rng.uniform(-.25, .25), .15))).normalized()
        path.append(path[-1] + d * length / steps)
    parts.append(tube('Branch%d' % len(parts), path, [radius * (1 - .45 * k / steps) for k in range(steps + 1)],
                      CORAL, coral_col, None, 5))
    if depth > 0:
        for _ in range(2 if depth > 1 else rng.randint(1, 3)):
            turn = rng.uniform(0, math.tau)
            side = Vector((math.cos(turn), math.sin(turn), 1.1))
            branch(path[-1], side, length * .7, radius * .6, depth - 1)


for trunk in range(3):
    turn = trunk * math.tau / 3 + rng.uniform(-.3, .3)
    branch(Vector((0, 0, 0)), Vector((math.cos(turn) * .4, math.sin(turn) * .4, 1)), .5, .07, 2)
finish('Coral', coral_col, parts)

FAN = material('SeaFan', '7c3b8a')
fan_col = new_collection('SeaFan')
parts = []
# A gorgonian grows in one plane, across the current.
for k in range(9):
    spread = (k - 4) / 4
    path = [Vector((0, 0, 0))]
    for step in range(1, 7):
        t = step / 6
        path.append(Vector((spread * 1.0 * t ** .8 + math.sin(step + k) * .04, math.sin(step * 1.7 + k) * .03,
                            1.7 * t * (1 - abs(spread) * .25))))
    parts.append(tube('Rib%d' % k, path, [.035 - .004 * s for s in range(7)], FAN, fan_col, None, 4))
    for step in range(2, 6, 1):
        if k < 8:
            a = path[step]
            parts.append(tube('Mesh%d_%d' % (k, step), [a, a + Vector((.12, 0, .06))], [.012, .01], FAN, fan_col,
                              None, 3))
finish('SeaFan', fan_col, parts)

SPONGE = material('Sponge', 'd9a13a')
sponge_col = new_collection('Sponge')
parts = []
for k in range(5):
    turn = rng.uniform(0, math.tau)
    r = rng.uniform(0, .25)
    base = Vector((math.cos(turn) * r, math.sin(turn) * r, 0))
    height = rng.uniform(.35, .8)
    lean = Vector((math.cos(turn), math.sin(turn), 0)) * rng.uniform(0, .12)
    path = [base + lean * (s / 4) + Vector((0, 0, height * s / 4)) for s in range(5)]
    width = rng.uniform(.09, .14)
    parts.append(tube('Tube%d' % k, path, [width * f for f in (.8, 1.0, 1.05, 1.1, 1.15)], SPONGE, sponge_col,
                      None, 7, open_top=True))
finish('Sponge', sponge_col, parts)

STAR = material('Starfish', 'e0703a')
star_col = new_collection('Starfish')
points = []
for k in range(10):
    t = math.tau * k / 10
    r = .28 if k % 2 == 0 else .09
    points.append((math.cos(t) * r, math.sin(t) * r, .02))
bm = bmesh.new()
top = bm.verts.new((0, 0, .06))
rim = [bm.verts.new(p) for p in points]
bottom = bm.verts.new((0, 0, 0))
for k in range(10):
    bm.faces.new((top, rim[k], rim[(k + 1) % 10]))
    bm.faces.new((bottom, rim[(k + 1) % 10], rim[k]))
finish('Starfish', star_col, [from_bmesh('StarBody', bm, [STAR], star_col, None, smooth=True)])

OUT.mkdir(parents=True, exist_ok=True)
for col, name in built:
    export(col, OUT / (name[0].lower() + ''.join('_' + c.lower() if c.isupper() else c for c in name[1:]) + '.glb'))
save(SOURCE)
print('built', len(built), 'models into', OUT, 'and', SOURCE)
