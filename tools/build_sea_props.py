"""Build the offshore rocks, the lighthouse and the sailboat with Blender Python.

Run: python3 tools/build_sea_props.py (needs the bpy module or Blender's Python).
It writes assets/source/sea_props.blend and one glTF per model in
assets/models/props/. Sizes are in scenery units (one tile across).

The game relies on these names and places (see docs/development.md):

- Offshore rocks: one mesh "Rock" in PBR_SeaRock, about one unit across. The
  board stands them upright with z 0 at the water line; the part below
  spreads wide so it fades into the deep water.
- Lighthouse: the water line is at z .175 on its islet. "Lamp" is the glazed
  lantern room, centred at z 1.0, where the scene hangs its NightLight and the
  sweeping beam.
- Sailboat: top-level Hull, Deck, Mast and Sail. Blender -Y is the bow, which
  exports as Godot +Z, the way sea traffic steers it. The water line is at
  z -.07.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_kit import export, material, new_collection, reset, save  # noqa: E402
from model_kit import Part, euler, triangles  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/props'
SOURCE = ROOT / 'assets/source/sea_props.blend'

reset('SeaProps')

ROCK = material('PBR_SeaRock', '675f56')
MOSS = material('SeaMoss', '7d8a4c')
GUANO = material('Guano', 'e6e1d2')
report = {}


def finish(name, col):
    export(col, OUT / (name + '.glb'))
    report[name] = sum(triangles(o) for o in col.all_objects if o.type == 'MESH')
    for obj in col.all_objects:
        obj.name = col.name + '.' + obj.name


def paint_tops(obj, mat, min_z, min_up=.72, every=1):
    """Give the upward faces above min_z another material: moss or droppings on a ledge."""
    if mat.name not in obj.data.materials:
        obj.data.materials.append(mat)
    index = list(obj.data.materials).index(mat)
    for i, poly in enumerate(obj.data.polygons):
        if poly.center.z > min_z and poly.normal.z > min_up and i % every == 0:
            poly.material_index = index


# ------------------------------------------------------------------ offshore rocks

# Three sea stacks, each a cluster of chiselled crags. The biggest mass sits
# a little off centre so a random turn on the board changes the silhouette.
ROCKS = [
    # A tall stack with ledges and a lower shoulder.
    [((0, 0, .08), (.36, .30, .58), 11, .16, .10), ((.26, .10, -.12), (.26, .24, .30), 12, 0, 0),
     ((-.20, -.16, -.20), (.24, .22, .22), 13, 0, 0), ((.02, .02, -.36), (.50, .46, .24), 14, 0, 0)],
    # A broad reef with two humps.
    [((-.18, .04, -.02), (.36, .30, .22), 21, .16, .2), ((.20, -.08, -.04), (.30, .26, .18), 22, .14, -.15),
     ((.04, .22, -.08), (.26, .20, .14), 23, 0, .1), ((-.02, -.24, -.1), (.2, .16, .12), 25, 0, 0),
     ((0, 0, -.3), (.56, .48, .22), 24, 0, 0)],
    # Two leaning pinnacles split by a cleft.
    [((-.13, 0, .10), (.22, .26, .54), 31, .14, .12), ((.16, .04, .02), (.20, .22, .40), 32, .12, 0),
     ((.02, -.18, -.16), (.30, .20, .20), 33, 0, 0), ((0, .02, -.34), (.50, .44, .24), 34, 0, 0)],
]
for index, crags in enumerate(ROCKS):
    col = new_collection('OffshoreRock%d' % index)
    part = Part('Rock')
    for center, radii, seed, terrace, lean in crags:
        part.crag(center, radii, ROCK, seed=seed, cuts=12, terrace=terrace, subdiv=3, matrix=euler((lean, lean * .5, seed)))
    rock = part.build(col)
    if index == 1:
        paint_tops(rock, MOSS, .1, every=2)
    else:
        paint_tops(rock, GUANO, .3, .8, every=3)
    finish('offshore_rock_%d' % index, col)


# ------------------------------------------------------------------ lighthouse

WATER = .175
WHITE = material('Whitewash', 'efe9dc')
RED = material('TowerBrick', 'bf4b3a')
STONE = material('TowerStone', '9d978a')
STONE_DARK = material('TowerStoneDark', '777266')
IRON = material('LanternIron', '2f3336', .5, .5)
GLASS = material('LanternGlass', 'e9b85e')
COPPER = material('CopperRoof', '5f9483', .5, .3)
GOLD = material('Finial', 'd9ac4a', .35, .7)
DOOR = material('TowerDoor', '6b4a2f')
SHADE = material('TowerShade', '2b2a2c')
PLANK = material('Plank', '9a7550')
TIMBER = material('Wood', '6b4a2f')
SLATE = material('SlateRoof', '596b72')
GRASS = material('IsletGrass', '7a9a4a')

col = new_collection('Lighthouse')

# The islet: a flat topped mound the tower stands on, with boulders round it.
islet = Part('Outcrop')
islet.crag((0, .02, WATER - .02), (.46, .40, .20), ROCK, seed=41, cuts=10, top=.7, subdiv=3)
islet.crag((0, 0, WATER - .24), (.66, .52, .26), ROCK, seed=42, cuts=8, subdiv=2)
for i, (x, y, r, h) in enumerate(((.42, -.18, .15, .13), (-.40, .16, .17, .16), (-.30, -.30, .12, .09),
                                  (.28, .32, .14, .12), (.52, .10, .09, .07), (-.52, -.08, .10, .08))):
    islet.crag((x, y, WATER + h * .15), (r, r * .85, h), ROCK, seed=50 + i, cuts=10, rough=.22, subdiv=2)
outcrop = islet.build(col)
paint_tops(outcrop, GRASS, WATER + .1, .8)

TOP = WATER + .135      # the plateau the tower stands on
BASE = TOP + .03        # tower plinth top
NECK = .86              # where the tower meets the gallery


def tower_radius(z):
    t = (z - BASE) / (NECK - BASE)
    return .108 + .05 * (1 - t) ** 1.4


tower = Part('Tower')
# A stone plinth, octagonal, with a step.
tower.lathe([(.19, TOP - .04), (.19, TOP + .01), (.175, TOP + .012), (.175, BASE)], STONE_DARK, 8, smooth=False)
# Painted bands, red and white; each band bulges a hair so the seams read.
bands = 6
for i in range(bands):
    z0 = BASE + (NECK - BASE) * i / bands
    z1 = BASE + (NECK - BASE) * (i + 1) / bands
    steps = [z0 + (z1 - z0) * k / 3 for k in range(4)]
    tower.lathe([(tower_radius(z) + .002 * math.sin(math.pi * k / 3), z) for k, z in enumerate(steps)],
                RED if i % 2 else WHITE, 20, cap_bottom=False, cap_top=False)
# The door faces the camera side (-Y), under a little stone hood, with a step.
angle = -math.pi / 2 - .35
direction = Vector((math.cos(angle), math.sin(angle), 0))
side = Vector((-direction.y, direction.x, 0))
r = tower_radius(BASE + .05)
at = direction * (r + .004)
tower.box(at + Vector((0, 0, BASE + .052)), (.062, .016, .104), STONE, bevel=.004, rot=(0, 0, angle + math.pi / 2))
tower.box(at + direction * .004 + Vector((0, 0, BASE + .046)), (.044, .012, .09), DOOR, bevel=.003, rot=(0, 0, angle + math.pi / 2))
tower.box(at + direction * .010 + Vector((0, 0, BASE + .112)), (.078, .03, .012), STONE_DARK, bevel=.003, rot=(0, 0, angle + math.pi / 2))
tower.box(direction * (r + .03) + Vector((0, 0, BASE - .004)), (.07, .05, .012), STONE, bevel=.003, rot=(0, 0, angle + math.pi / 2))
tower.box(direction * (r + .005) + side * .014 + Vector((0, 0, BASE + .05)), (.004, .01, .004), material('Brass', 'c9a24a', .4, .6))
# Small windows climbing round the tower.
for i, (a, z) in enumerate(((-.9, .50), (.4, .60), (1.9, .70), (-2.2, .78), (-1.3, .66))):
    d = Vector((math.cos(a), math.sin(a), 0))
    rr = tower_radius(z)
    rot = (0, 0, a + math.pi / 2)
    tower.box(d * (rr - .002) + Vector((0, 0, z)), (.034, .014, .05), STONE, bevel=.004, rot=rot)
    tower.box(d * (rr + .004) + Vector((0, 0, z - .002)), (.022, .01, .036), SHADE, bevel=.003, rot=rot)
    tower.box(d * (rr + .008) + Vector((0, 0, z - .024)), (.036, .016, .007), STONE_DARK, bevel=.002, rot=rot)
# Corbels carry the gallery.
gallery_z = NECK + .03
for i in range(14):
    a = math.tau * i / 14
    d = Vector((math.cos(a), math.sin(a), 0))
    tower.box(d * .118 + Vector((0, 0, NECK + .008)), (.03, .016, .034), STONE, bevel=.003, rot=(0, 0, a + math.pi / 2), taper=(1.5, 1))
tower.lathe([(.108, NECK - .004), (.17, gallery_z - .012), (.17, gallery_z)], STONE_DARK, 20, smooth=False)
tower.build(col)

lantern = Part('LanternRoom')
# Railing round the gallery.
for i in range(18):
    a = math.tau * i / 18
    lantern.tube((math.cos(a) * .162, math.sin(a) * .162, gallery_z), (math.cos(a) * .162, math.sin(a) * .162, gallery_z + .06), .003, .003, IRON, 5)
lantern.torus((0, 0, gallery_z + .06), .162, .004, IRON, 36, 5)
lantern.torus((0, 0, gallery_z + .032), .162, .0025, IRON, 36, 4)
# The lantern room: a low iron wall, glazing bars and a cornice.
lantern.lathe([(.098, gallery_z), (.098, gallery_z + .026), (.094, gallery_z + .03)], IRON, 8, smooth=False)
for i in range(8):
    a = math.tau * (i + .5) / 8
    lantern.box((math.cos(a) * .092, math.sin(a) * .092, 1.0), (.008, .008, .14), IRON, rot=(0, 0, a))
lantern.lathe([(.094, 1.068), (.112, 1.074), (.112, 1.084), (.09, 1.086)], IRON, 8, smooth=False)
lantern.build(col)

lamp = Part('Lamp')
lamp.lathe([(.088, gallery_z + .026), (.088, 1.07)], GLASS, 8, smooth=False)
lamp.build(col, name='Lamp')

roof = Part('Roof')
roof.lathe([(.116, 1.08), (.108, 1.094), (.086, 1.13), (.058, 1.162), (.03, 1.186), (.012, 1.2), (0, 1.203)], COPPER, 16)
roof.ellipsoid((0, 0, 1.214), (.016, .016, .016), GOLD, 10, 6)
roof.tube((0, 0, 1.22), (0, 0, 1.285), .003, .002, IRON, 5)
roof.box((0, .012, 1.266), (.004, .05, .004), IRON)
roof.polygon([Vector((0, -.012, 1.258)), Vector((0, -.03, 1.266)), Vector((0, -.012, 1.274))], IRON, thickness=.003)
roof.polygon([Vector((0, .028, 1.259)), Vector((0, .044, 1.259)), Vector((0, .044, 1.276)), Vector((0, .028, 1.272))], GOLD, thickness=.003)
roof.build(col)

# The keeper's shed leans on the back of the tower, with a landing stage below the door.
shed = Part('Shed')
sx, sy = .10, .19
shed.box((sx, sy, TOP + .032), (.13, .09, .075), STONE, bevel=.005)
for k, (y0, y1) in enumerate(((sy - .06, sy + .005), (sy + .06, sy - .005))):
    shed.polygon([Vector((sx - .075, y0, TOP + .062)), Vector((sx + .075, y0, TOP + .062)),
                  Vector((sx + .075, y1, TOP + .11)), Vector((sx - .075, y1, TOP + .11))], SLATE, thickness=.008)
for s in (-1, 1):
    shed.polygon([Vector((sx + s * .064, sy - .045, TOP + .07)), Vector((sx + s * .064, sy + .045, TOP + .07)),
                  Vector((sx + s * .064, sy, TOP + .105))], STONE)
shed.box((sx + .066, sy + .01, TOP + .03), (.006, .03, .05), DOOR, bevel=.002)
shed.box((sx + .05, sy + .034, TOP + .13), (.018, .018, .05), STONE_DARK, bevel=.003)
# Landing stage. A ray cast finds the islet's real surface, so the steps from
# the door follow the rock down and the jetty starts where the rock meets it.
verts = [v.co.copy() for v in outcrop.data.vertices]
tree = BVHTree.FromPolygons(verts, [p.vertices[:] for p in outcrop.data.polygons])


def ground(p):
    hit = tree.ray_cast(Vector((p.x, p.y, 2)), Vector((0, 0, -1)))
    return hit[0].z if hit[0] else WATER


# High enough that calm-weather swell (about .05 here) passes under the planks.
JETTY_Z = WATER + .075
turn = angle + math.pi / 2
start = r + .03
while ground(direction * start) > JETTY_Z + .004 and start < .8:
    start += .005
# Steps: flat treads resting on the rock, from the door down to the jetty.
t = r + .055
while t < start - .01:
    p = direction * t
    z = min(ground(p) + .008, TOP)
    shed.box((p.x, p.y, (z + ground(p) - .03) / 2), (.07, .03, z - ground(p) + .03), STONE, bevel=.004, rot=(0, 0, turn))
    t += .032
# The jetty: stringers, planks laid across them, piles under both sides.
length = .28
root = direction * (start - .04)
for s in (-1, 1):
    a = root + side * s * .036
    b = a + direction * length
    shed.sweep([(a.x, a.y, JETTY_Z - .012), (b.x, b.y, JETTY_Z - .012)], .007, TIMBER, 6, smooth=False)
planks = 10
for i in range(planks):
    p = root + direction * (length * (i + .5) / planks)
    shed.box((p.x, p.y, JETTY_Z), (.11, length / planks - .004, .01), PLANK, bevel=.002,
             rot=(0, (i % 3 - 1) * .02, turn + (i % 2 - .5) * .03))
for k, u in enumerate((.1, .19, .28)):
    for s in (-1, 1):
        q = root + direction * u + side * s * .044
        top = JETTY_Z + (.035 if k == 2 else -.004)
        shed.tube((q.x, q.y, WATER - .1), (q.x, q.y, top), .009, .008, TIMBER, 6)
        if k == 2:
            shed.ellipsoid((q.x, q.y, top), (.009, .009, .004), TIMBER, 6, 3)
# Crates and a barrel by the door.
crate = direction * (r + .07) - side * .1
shed.box((crate.x, crate.y, ground(crate) + .018), (.04, .04, .04), PLANK, bevel=.003, rot=(0, 0, .3))
barrel = crate + side * .05 - direction * .01
shed.lathe([(.016, 0), (.02, .02), (.016, .04)], TIMBER, 10, center=(barrel.x, barrel.y, ground(barrel) - .004))
shed.build(col)

# A rowboat tied up alongside the jetty. The game floats it on the swell
# (lighthouse.gd), so its origin is its water line.
boat = Part('Rowboat')
OAR = material('BoatSpar', '7a5534')
TRIM_R = material('BoatTrim', '3d7a80')
INSIDE = material('BoatDeck', 'b38b5a')


def dinghy(t, u, inset=0.0):
    """A point on the rowboat: t runs stern (0) to bow (1), u keel (0) to rim (1)."""
    y = .1 - .2 * t
    beam = (.05 * math.sin(math.pi * (.2 + .8 * t)) ** .7 + .002) * (1 - .13 * t * t) - inset
    sheer = .034 + .018 * t ** 3
    keel = -.016 + .012 * t ** 4
    th = u * math.pi / 2
    return Vector((max(beam, .001) * math.sin(th), y, keel + inset * .8 + (sheer - keel - inset * .8) * (1 - math.cos(th))))


STEPS, RISE = 9, 5
for hand in (-1, 1):
    for skin, inset, mats in (('out', 0.0, (TIMBER, TIMBER, PLANK, PLANK, TRIM_R)), ('in', .005, (INSIDE,) * RISE)):
        for k in range(RISE):
            rows = [[dinghy(i / STEPS, k / RISE, inset), dinghy(i / STEPS, (k + 1) / RISE, inset)] for i in range(STEPS + 1)]
            rows = [[Vector((hand * v.x, v.y, v.z)) for v in r] for r in rows]
            if (hand > 0) != (skin == 'in'):
                rows = [list(reversed(r)) for r in rows]
            boat.quad_strip(rows, mats[k], smooth=True)
    # The rim joins the two skins along the sheer.
    rim = [[dinghy(i / STEPS, 1), dinghy(i / STEPS, 1, .005)] for i in range(STEPS + 1)]
    rim = [[Vector((hand * v.x, v.y, v.z + .002)) for v in r] for r in rim]
    boat.quad_strip(rim if hand < 0 else [list(reversed(r)) for r in rim], OAR, smooth=False)
# A flat transom closes the stern.
transom = [dinghy(0, k / RISE) for k in range(RISE + 1)]
outline = [Vector((-v.x, v.y, v.z)) for v in reversed(transom)] + [v for v in transom[1:]]
boat.polygon(outline, PLANK, thickness=.004)
# Stem post, thwarts and two oars shipped along the benches.
boat.tube(dinghy(1, 0) + Vector((0, .006, 0)), dinghy(1, 1) + Vector((0, -.004, .01)), .004, .004, OAR, 5)
for t in (.3, .62):
    half = dinghy(t, 1, .005).x
    boat.box((0, .1 - .2 * t, .024), (half * 2, .024, .005), PLANK, bevel=.001)
for s in (-1, 1):
    boat.sweep([(s * .022, .07, .028), (s * .016, -.06, .03)], .0028, OAR, 5)
    boat.box((s * .02, .082, .027), (.012, .03, .002), OAR, rot=(0, 0, -s * .05))
berth = root + direction * .18 + side * .118
obj = boat.build(col, location=(berth.x, berth.y, WATER + .004))
obj.rotation_euler = (0, 0, angle - math.pi / 2 + .1)
# Its painter runs from the last pile down into the water by the bow.
post = root + direction * .28 + side * .044
bow = berth + direction * .1 + side * .005
rope = Part('Painter')
rope.sweep([(bow.x, bow.y, WATER - .01), ((bow.x + post.x) / 2, (bow.y + post.y) / 2, WATER + .02), (post.x, post.y, JETTY_Z + .025)],
           .0025, material('Rope', '5a4634'), 4)
rope.build(col)

finish('lighthouse', col)


# ------------------------------------------------------------------ sailboat

TAR = material('BoatTar', '3e2e25')
PLANK_A = material('BoatPlank', 'a87b4f')
PLANK_B = material('BoatPlankDark', '8e6641')
TRIM = material('BoatTrim', '3d7a80')
DECK = material('BoatDeck', 'b38b5a')
SPAR = material('BoatSpar', '7a5534')
ROPE = material('Rope', '5a4634')
CANVAS = material('BoatCanvas', 'efe4cb')
STRIPE = material('BoatCanvasStripe', 'b8483a')
IRON_B = material('BoatIron', '2f2d2c', .5, .5)

col = new_collection('Sailboat')

# Stations from stern (+Y) to bow (-Y): y, half beam, sheer height, keel height.
STATIONS = [(.38, .085, .135, -.06), (.30, .125, .112, -.098), (.18, .148, .096, -.118), (.04, .152, .09, -.124),
            (-.10, .142, .094, -.12), (-.22, .112, .106, -.108), (-.33, .064, .126, -.086), (-.41, .012, .152, -.05)]
STRAKES = 6


def hull_point(station, t, side, out=0.0):
    """A point on the hull at height fraction t (0 keel, 1 gunwale), pushed out by `out`."""
    y, beam, sheer, keel = station
    th = t * math.pi / 2
    x = beam * (math.sin(th) + .06 * t * t)
    z = keel + (sheer - keel) * (1 - math.cos(th)) ** .85
    n = Vector((math.sin(th), 0, -math.cos(th)))
    return Vector((side * (x + n.x * out), y, z + n.z * out))


hull = Part('Hull')
mats = [TAR, TAR, PLANK_B, PLANK_A, PLANK_B, TRIM]
for side in (-1, 1):
    for k in range(STRAKES):
        t0, t1 = k / STRAKES, (k + 1) / STRAKES
        lap = .0045 if k > 0 else 0
        rows = [[hull_point(st, t0, side, lap), hull_point(st, (t0 + t1) / 2, side, lap * .4), hull_point(st, t1, side)] for st in STATIONS]
        if side > 0:
            rows = [list(reversed(r)) for r in rows]
        hull.quad_strip(rows, mats[k], smooth=True)
        if k > 0:
            # The lip where this strake laps over the one below.
            lip = [[hull_point(st, t0, side), hull_point(st, t0, side, lap)] for st in STATIONS]
            if side < 0:
                lip = [list(reversed(r)) for r in lip]
            hull.quad_strip(lip, TAR, smooth=False)
# Transom across the stern.
stern = STATIONS[0]
outline = [hull_point(stern, k / STRAKES, -1) for k in range(STRAKES + 1)]
outline += [hull_point(stern, k / STRAKES, 1) for k in range(STRAKES, -1, -1)]
hull.polygon(list(reversed(outline)), PLANK_B)
# Keel, stem and sternpost.
keel = [Vector((0, st[0], st[3] - .006)) for st in STATIONS]
for a, b in zip(keel, keel[1:]):
    hull.tube(a, b, .009, .009, TAR, 6, smooth=False)
stem_base = Vector((0, STATIONS[-1][0] - .004, STATIONS[-1][3]))
hull.tube(stem_base, stem_base + Vector((0, -.035, .14)), .010, .008, SPAR, 6)
hull.tube(stem_base + Vector((0, -.035, .14)), stem_base + Vector((0, -.05, .2)), .008, .006, SPAR, 6)
hull.ellipsoid(stem_base + Vector((0, -.05, .204)), (.01, .012, .01), SPAR, 8, 5)
post = Vector((0, stern[0] + .006, stern[3]))
hull.tube(post, post + Vector((0, .02, .2)), .009, .008, SPAR, 6)
# Rudder hung on the sternpost, with the tiller over the transom.
y0 = stern[0] + .012
blade = [(y0, .13), (y0 + .022, .13), (y0 + .03, .02), (y0 + .07, -.06), (y0 + .06, -.1), (y0, -.1)]
hull.polygon([Vector((-.005, y, z)) for y, z in blade], SPAR, thickness=.01)
hull.tube((0, stern[0] + .02, .15), (0, stern[0] - .09, .17), .005, .004, SPAR, 6)
# Gunwale rail capping the sheer on each side.
for side in (-1, 1):
    hull.sweep([hull_point(st, 1, side) + Vector((0, 0, .005)) for st in STATIONS], .0075, SPAR, 6)
hull.build(col)

DECK_Z = .072


def deck_edge(station):
    """Where the flat deck meets the inside of the hull at this station."""
    lo, hi = 0.0, 1.0
    for _ in range(30):
        mid = (lo + hi) / 2
        if hull_point(station, mid, 1).z < DECK_Z:
            lo = mid
        else:
            hi = mid
    return hull_point(station, lo, 1).x - .003


deck = Part('Deck')
edges = [(st[0], deck_edge(st)) for st in STATIONS]
outline = [Vector((-x, y, DECK_Z)) for y, x in edges] + [Vector((x, y, DECK_Z)) for y, x in reversed(edges)]
deck.polygon(outline, DECK)
# Plank seams, clipped to the deck outline.
for x in (-.1, -.05, 0, .05, .1):
    inside = [y for y, half in edges if half > abs(x) + .01]
    deck.box((x, (min(inside) + max(inside)) / 2, DECK_Z + .001), (.003, max(inside) - min(inside), .002), PLANK_B)
# A hatch, a barrel, a crate, a coiled rope and a heap of net.
deck.box((0, .12, .078), (.1, .08, .014), PLANK_B, bevel=.003)
deck.box((0, .12, .08), (.08, .06, .004), SPAR)
deck.lathe([(.022, 0), (.027, .025), (.022, .05)], PLANK_A, 12, center=(.07, .22, DECK_Z))
deck.torus((.07, .22, DECK_Z + .014), .026, .003, IRON_B, 12, 4)
deck.box((-.07, .23, DECK_Z + .02), (.045, .045, .04), PLANK_B, bevel=.003, rot=(0, 0, .25))
for i in range(3):
    deck.torus((-.05, -.17, DECK_Z + .004 + i * .005), .03 - i * .007, .005, ROPE, 14, 5)
deck.ellipsoid((.05, -.2, DECK_Z + .006), (.045, .04, .016), material('Net', '8d7a5b'), 10, 5,
               squash=lambda v: (v.x, v.y, v.z + .25 * math.sin(v.x * 6) * math.cos(v.y * 5)))
deck.build(col)

MAST = Vector((0, -.05, DECK_Z))
TOP_Z = .84
mast = Part('Mast')
mast.tube(MAST, (0, MAST.y, TOP_Z), .013, .009, SPAR, 8)
mast.lathe([(.016, 0), (.018, .01), (.016, .02)], IRON_B, 8, center=(0, MAST.y, TOP_Z - .08))
mast.ellipsoid((0, MAST.y, TOP_Z + .01), (.012, .012, .012), SPAR, 8, 5)
# The yard with its sling, and the fighting top ring below the masthead.
YARD_Z = .72
mast.tube((-.24, MAST.y - .018, YARD_Z), (.24, MAST.y - .018, YARD_Z), .006, .006, SPAR, 6, round_ends=True)
mast.torus((0, MAST.y - .008, YARD_Z), .016, .004, ROPE, 8, 4)
# Shrouds from the masthead to the rails, the forestay to the stem and a backstay.
head = Vector((0, MAST.y, TOP_Z - .08))
for side in (-1, 1):
    for y in (MAST.y + .03, MAST.y + .11):
        st = min(STATIONS, key=lambda s: abs(s[0] - y))
        mast.tube(head, hull_point((y, st[1], st[2], st[3]), 1, side) + Vector((0, 0, .006)), .0022, .0022, ROPE, 4, smooth=False)
mast.tube(head, post + Vector((0, .02, .2)), .0022, .0022, ROPE, 4, smooth=False)
mast.build(col)

# A square sail, full of wind blowing from astern, with red and cream cloths.
sail = Part('Sail')
columns, lines = 8, 6
top_w, foot_w = .44, .48
grid = []
for row in range(lines + 1):
    v = row / lines
    line = []
    for c in range(columns + 1):
        u = c / columns - .5
        w = top_w + (foot_w - top_w) * v
        belly = (1 - (2 * u) ** 2) * math.sin(math.pi * (.15 + .8 * v)) * .075
        line.append(Vector((u * w, MAST.y - .03 - belly, YARD_Z - .012 - v * .42 + (2 * u) ** 2 * v * .02)))
    grid.append(line)
for c in range(columns):
    sail.quad_strip([[grid[row][c], grid[row][c + 1]] for row in range(lines + 1)], STRIPE if c in (1, 3, 4, 6) else CANVAS, smooth=True)
# Sheets from the clews back to the rails, and a long pennant at the masthead.
for side in (-1, 1):
    clew = grid[-1][0 if side < 0 else -1]
    sail.tube(clew, hull_point(STATIONS[2], 1, side) + Vector((0, 0, .006)), .002, .002, ROPE, 4, smooth=False)
flag = []
for k in range(6):
    t = k / 5
    wave = math.sin(t * math.pi * 1.6) * .012
    flag.append([Vector((wave, MAST.y + .01 + t * .16, TOP_Z + .005 - t * .012)),
                 Vector((wave, MAST.y + .01 + t * .16, TOP_Z + .04 - t * .026))])
sail.quad_strip(flag, STRIPE, smooth=True)
sail.build(col)

finish('sailboat', col)

save(SOURCE)
for name, count in report.items():
    print('%-18s %6d triangles' % (name, count))
