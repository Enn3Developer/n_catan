"""Build the ship piece, the treasure chest and the fog bank with Blender Python.

Run: python3 tools/build_seafaring.py (needs the bpy module or Blender's Python).
It writes assets/source/seafaring.blend and one glTF per model in
assets/models/props/. Blender -Y is the ship's bow, which exports as Godot +Z.
Sizes are in tile units, like the settlement pieces.

Material roles follow docs/development.md: "Owner" (with an optional signed
percentage) takes the player's color at runtime, "PBR_Wood" takes the wood
texture tier, and "NightLantern" glows at night beside its NightLight lamp.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_kit import Vector, blob, empty, export as export_to, join, lamp, material, new_collection, reset, save  # noqa: E402
from model_kit import Part, euler  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/seafaring.blend'
OUT = ROOT / 'assets/models/props'

reset('Seafaring')


def export(col, filename):
    export_to(col, OUT / filename)


# ------------------------------------------------------------------ ship

WOOD = material('PBR_Wood', 'a0774e')
TAR = material('Tar', '3e2e25')
DECK = material('Deck', 'c29c6a')
TIMBER = material('Timber', '6b4a2f')
ROPE = material('Rope', '5a4634')
OWNER = material('Owner', 'ed815d')
OWNER_DARK = material('Owner-20', 'be674a')
LANTERN = material('NightLantern', 'ffd092')
IRON = material('Iron', '5b5048', roughness=.5, metallic=.6)

ship_col = new_collection('Ship')
ship = empty('Ship', ship_col)

# A little cog. Stations from stern (+Y) to bow (-Y): y, half beam, sheer height, keel height.
STATIONS = [(.200, .040, .088, .012), (.160, .056, .070, -.006), (.090, .064, .058, -.018), (.000, .066, .055, -.022),
            (-.090, .060, .058, -.018), (-.160, .042, .070, -.006), (-.215, .006, .088, .012)]
DECK_Z = .044


def hull_point(station, t, side, out=0.0):
    """A point on the hull at height fraction t (0 keel, 1 gunwale), pushed out by `out`."""
    y, beam, sheer, keel = station
    th = t * math.pi / 2
    x = beam * (math.sin(th) + .06 * t * t)
    z = keel + (sheer - keel) * (1 - math.cos(th)) ** .85
    return Vector((side * (x + math.sin(th) * out), y, z - math.cos(th) * out))


# Clinker planking: each strake laps over the one below; tarred bottom, a band in the owner's color.
hull = Part('Hull')
strakes = [TAR, TAR, WOOD, WOOD, OWNER_DARK]
for side in (-1, 1):
    for k, mat in enumerate(strakes):
        t0, t1 = k / len(strakes), (k + 1) / len(strakes)
        lap = .002 if k else 0
        rows = [[hull_point(st, t0, side, lap), hull_point(st, (t0 + t1) / 2, side, lap * .4), hull_point(st, t1, side)] for st in STATIONS]
        hull.quad_strip(rows if side < 0 else [list(reversed(r)) for r in rows], mat, smooth=True)
        if k:
            lip = [[hull_point(st, t0, side), hull_point(st, t0, side, lap)] for st in STATIONS]
            hull.quad_strip(lip if side > 0 else [list(reversed(r)) for r in lip], TAR, smooth=False)
    hull.sweep([hull_point(st, 1, side) + Vector((0, 0, .003)) for st in STATIONS], .004, TIMBER, 6)
stern = STATIONS[0]
outline = [hull_point(stern, k / 5, -1) for k in range(6)] + [hull_point(stern, k / 5, 1) for k in range(5, -1, -1)]
hull.polygon(list(reversed(outline)), WOOD)
keel = [Vector((0, st[0], st[3] - .004)) for st in STATIONS]
hull.sweep(keel, .005, TAR, 6, smooth=False)
stem = Vector((0, STATIONS[-1][0] - .002, STATIONS[-1][3]))
hull.sweep([stem, stem + Vector((0, -.012, .05)), stem + Vector((0, -.018, .09))], .005, TIMBER, 6)
post = Vector((0, stern[0] + .003, stern[3]))
hull.tube(post, post + Vector((0, .006, .1)), .005, .005, TIMBER, 6)
blade = [(stern[0] + .004, .07), (stern[0] + .016, .07), (stern[0] + .02, .0), (stern[0] + .04, -.03), (stern[0] + .03, -.042), (stern[0] + .004, -.042)]
hull.polygon([Vector((-.003, y, z)) for y, z in blade], TIMBER, thickness=.006)
hull.build(ship_col, ship)

deck = Part('Deck')


def deck_edge(station):
    lo, hi = 0.0, 1.0
    for _ in range(30):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if hull_point(station, mid, 1).z < DECK_Z else (lo, mid)
    return hull_point(station, lo, 1).x - .002


edges = [(st[0], deck_edge(st)) for st in STATIONS]
deck.polygon([Vector((-x, y, DECK_Z)) for y, x in edges] + [Vector((x, y, DECK_Z)) for y, x in reversed(edges)], DECK)
for x in (-.04, -.013, .013, .04):
    inside = [y for y, half in edges if half > abs(x) + .006]
    deck.box((x, (min(inside) + max(inside)) / 2, DECK_Z + .0006), (.0015, max(inside) - min(inside), .001), TIMBER)
# Stern castle: a raised platform with a railing and a door, and a small forecastle.
deck.box((0, .165, DECK_Z + .02), (.084, .07, .04), WOOD, bevel=.003)
deck.box((0, .165, DECK_Z + .042), (.094, .08, .006), TIMBER, bevel=.002)
deck.box((0, .129, DECK_Z + .016), (.02, .004, .03), TIMBER, bevel=.001)
for x in (-.042, -.021, 0, .021, .042):
    deck.box((x, .128, DECK_Z + .053), (.005, .005, .018), TIMBER)
for y in (.14, .165, .19):
    for s in (-1, 1):
        deck.box((s * .044, y, DECK_Z + .053), (.005, .005, .018), TIMBER)
deck.box((0, .128, DECK_Z + .063), (.094, .006, .004), OWNER_DARK)
for s in (-1, 1):
    deck.box((s * .044, .165, DECK_Z + .063), (.006, .08, .004), OWNER_DARK)
deck.prism([(0, -.2), (-.034, -.13), (.034, -.13)], DECK_Z + .02, DECK_Z + .026, TIMBER, bevel=.001)
# Cargo amidships: a barrel and a lashed crate.
deck.lathe([(.011, 0), (.014, .013), (.011, .026)], WOOD, 10, center=(.026, .06, DECK_Z))
deck.box((-.024, .075, DECK_Z + .012), (.026, .026, .024), WOOD, bevel=.002, rot=(0, 0, .3))
deck.build(ship_col, ship)

MAST_Y = -.01
TOP = .33
YARD = .27
mast = Part('Mast')
mast.tube((0, MAST_Y, DECK_Z), (0, MAST_Y, TOP), .0065, .0045, TIMBER, 8)
mast.tube((-.088, MAST_Y - .008, YARD), (.088, MAST_Y - .008, YARD), .003, .003, TIMBER, 6, round_ends=True)
# A crow's nest below the masthead.
mast.lathe([(.011, 0), (.013, .014), (.013, .016)], WOOD, 10, center=(0, MAST_Y, YARD + .018), cap_top=False)
mast.torus((0, MAST_Y, YARD + .033), .013, .0018, TIMBER, 12, 4)
mast.tube((0, -.2, .075), (0, -.29, .1), .0035, .0025, TIMBER, 6)
head = Vector((0, MAST_Y, YARD + .012))
for side in (-1, 1):
    for y in (MAST_Y + .03, MAST_Y + .07):
        st = min(STATIONS, key=lambda s: abs(s[0] - y))
        mast.tube(head, hull_point((y, st[1], st[2], st[3]), 1, side), .0012, .0012, ROPE, 4, smooth=False)
mast.tube(head, post + Vector((0, .006, .1)), .0012, .0012, ROPE, 4, smooth=False)
mast.tube((0, MAST_Y, TOP - .01), (0, -.29, .1), .0012, .0012, ROPE, 4, smooth=False)
mast.build(ship_col, ship)

# The square sail in the owner's color, with darker cloths, bellied by a following wind.
sail = Part('Mainsail')
columns, lines = 6, 5
grid = []
for row in range(lines + 1):
    v = row / lines
    grid.append([Vector((u * (.16 + .02 * v), MAST_Y - .014 - (1 - (2 * u) ** 2) * math.sin(math.pi * (.15 + .8 * v)) * .03,
                         YARD - .004 - v * .17 + (2 * u) ** 2 * v * .008))
                 for u in [c / columns - .5 for c in range(columns + 1)]])
for c in range(columns):
    sail.quad_strip([[grid[row][c], grid[row][c + 1]] for row in range(lines + 1)], OWNER_DARK if c % 2 else OWNER, smooth=True)
for side in (-1, 1):
    sail.tube(grid[-1][0 if side < 0 else -1], hull_point(STATIONS[2], 1, side), .0012, .0012, ROPE, 4, smooth=False)
# A long pennant at the masthead.
flag = []
for k in range(6):
    t = k / 5
    wave = math.sin(t * math.pi * 1.6) * .006
    flag.append([Vector((wave, MAST_Y + .004 + t * .075, TOP + .002 - t * .006)), Vector((wave, MAST_Y + .004 + t * .075, TOP + .018 - t * .013))])
sail.quad_strip(flag, OWNER, smooth=True)
sail.build(ship_col, ship)

# A lantern on the stern post that lights up at night.
lantern_pivot = empty('LanternPivot', ship_col, (0, stern[0] + .01, .113), ship)
glass = Part('NightLantern')
glass.lathe([(.006, -.008), (.007, 0), (.006, .008)], LANTERN, 8)
glass.build(ship_col, lantern_pivot)
frame = Part('LanternFrame')
frame.lathe([(.008, .008), (.004, .014), (0, .016)], IRON, 8)
frame.lathe([(.007, -.011), (.007, -.008)], IRON, 8)
frame.build(ship_col, lantern_pivot)
lamp('NightLight', (0, 0, .004), ship_col, lantern_pivot, .5, 3.0)

# ------------------------------------------------------------------ treasure

GOLD = material('Gold', 'e2b64a', roughness=.35, metallic=.8)
RUBY = material('Ruby', 'd24c4c', roughness=.2)
SAPPHIRE = material('Sapphire', '4c8fd2', roughness=.2)
EMERALD = material('Emerald', '5cc27a', roughness=.2)
PAINT = material('Paint', 'a33a2c')
GLINT = material('NightLantern', 'ffd092')
SAND = material('Sand', 'd8c08e')

treasure_col = new_collection('Treasure')
treasure = empty('Treasure', treasure_col)
W, D, H = .1, .066, .05

chest = Part('Chest')
chest.box((0, 0, H / 2), (W, D, H), WOOD, bevel=.003)
# Plank seams, iron bands, corner brackets, handles and a lock plate with a keyhole.
for z in (.017, .034):
    chest.box((0, -D / 2 - .0003, z), (W - .006, .001, .0012), TIMBER)
for x in (-.034, .034):
    chest.box((x, 0, H / 2), (.009, D + .003, H + .002), IRON, bevel=.001)
for x in (-1, 1):
    for y in (-1, 1):
        chest.box((x * (W / 2 - .002), y * (D / 2 - .002), .006), (.008, .008, .012), IRON, bevel=.001)
    chest.torus((x * (W / 2 + .003), 0, .03), .007, .0015, IRON, 10, 4, matrix=euler((0, math.pi / 2, 0)))
chest.box((0, -D / 2 - .002, .036), (.018, .004, .022), GOLD, bevel=.001)
chest.box((0, -D / 2 - .0042, .034), (.003, .001, .008), TIMBER)
# Half-buried in a little sand drift.
chest.ellipsoid((0, 0, -.004), (.085, .065, .012), SAND, 14, 6, squash=lambda v: (v.x, v.y, max(v.z, -.2)))
chest.build(treasure_col, treasure)

# The lid: a solid half barrel with bands, hinged at the back and thrown open.
hinge = empty('LidHinge', treasure_col, (0, D / 2, H), treasure)
hinge.rotation_euler = (math.radians(-110), 0, 0)
lid = Part('Lid')
profile = [(D / 2 * (1 - math.cos(math.pi * i / 8)), .022 * math.sin(math.pi * i / 8)) for i in range(9)]
for x0, x1, mat, grow in ((-W / 2, W / 2, WOOD, 0), (-.0385, -.0295, IRON, .0015), (.0295, .0385, IRON, .0015)):
    outer = [[Vector((x, -D + y, z + grow)) for x in (x0, x1)] for y, z in profile]
    lid.quad_strip(outer, mat, smooth=True)
    inner = [[Vector((x, -D + y, z - .005)) for x in (x0, x1)] for y, z in profile]
    lid.quad_strip([list(reversed(r)) for r in inner], mat, smooth=True)
    for x in (x0, x1):
        lid.polygon([Vector((x, -D + y, z + grow)) for y, z in profile] + [Vector((x, -D + y, z - .005)) for y, z in reversed(profile)], mat)
lid.build(treasure_col, hinge)

# A heap of coins with gems on top; the heap glints at night.
heap_pivot = empty('HeapPivot', treasure_col, (0, 0, H), treasure)
heap = Part('NightLantern')
heap.ellipsoid((0, 0, 0), (.044, .028, .014), GLINT, 12, 6)
heap.build(treasure_col, heap_pivot)
lamp('NightLight', (0, 0, .02), treasure_col, heap_pivot, .45, 2.0)
rng = random.Random(3)
coins = Part('Coins')
for i in range(22):
    a = rng.uniform(0, math.tau)
    r = math.sqrt(rng.random())
    x, y = math.cos(a) * r * .04, math.sin(a) * r * .025
    z = H + .014 * (1 - r * r) + .002
    tilt = (rng.uniform(-.5, .5), rng.uniform(-.5, .5), 0)
    coins.lathe([(.0075, -.001), (.0075, .001)], GOLD, 10, center=(x, y, z), matrix=euler(tilt), smooth=False)
for i in range(11):
    a = -1 + 2 * i / 10
    r = .07 + (i % 3) * .016
    x, y = math.sin(a) * r, -.03 - math.cos(a) * r * .7
    coins.lathe([(.0075, 0), (.0075, .002)], GOLD, 10, center=(x, y, .001), matrix=euler((rng.uniform(-.2, .2), rng.uniform(-.2, .2), 0)), smooth=False)
for i in range(3):
    coins.lathe([(.0075, 0), (.0075, .002)], GOLD, 10, center=(.07 + i * .002, .01, .002 + i * .002), smooth=False)
coins.build(treasure_col, treasure)
gems = Part('Gems')
for mat, at in ((RUBY, (-.016, .004, H + .018)), (SAPPHIRE, (.018, -.008, H + .016)), (EMERALD, (.002, .013, H + .019))):
    gems.ellipsoid(at, (.006, .006, .005), mat, 6, 4, smooth=False)
gems.build(treasure_col, treasure)
# A painted cross marking the spot, in front of the chest.
cross = Part('Cross')
for turn in (math.pi / 4, -math.pi / 4):
    cross.box((0, -.14, .001), (.1, .014, .002), PAINT, rot=(0, 0, turn))
cross.build(treasure_col, treasure)


# ------------------------------------------------------------------ fog bank

# A low bank of cloud that hides one hex under the Fog house rule. Puffs sit
# on a hex grid inside the tile's corners (radius 1), a broad lower layer and
# smaller ones heaped on top, so the hex reads as a soft mound of mist. The
# game shades it by height and lets it drift; one mesh keeps it one draw call.

rng = random.Random(7)
MIST = material('Fog', 'e8edf0', roughness=1.0)
fog_col = new_collection('FogBank')
fog = empty('FogBank', fog_col)
puffs = []
spacing = .36
for q in range(-3, 4):
    for r in range(-3, 4):
        x = spacing * (q + r * .5)
        y = spacing * r * math.sqrt(3) / 2
        if math.hypot(x, y) > .92:
            continue
        x += rng.uniform(-.05, .05)
        y += rng.uniform(-.05, .05)
        size = rng.uniform(.24, .3)
        puffs.append(blob('Puff', (x, y, .2), (size, size, size * .5), MIST, fog_col, fog, 10, 6))
for i in range(16):
    angle = rng.uniform(0, math.tau)
    reach = math.sqrt(rng.uniform(0, 1)) * .6
    size = rng.uniform(.16, .24)
    puffs.append(blob('Puff', (math.cos(angle) * reach, math.sin(angle) * reach, .3 + rng.uniform(0, .08)),
                      (size, size, size * .62), MIST, fog_col, fog, 10, 6))
join('FogBank', puffs, fog_col, fog)

OUT.mkdir(parents=True, exist_ok=True)
export(ship_col, 'ship.glb')
export(treasure_col, 'treasure.glb')
export(fog_col, 'fog_bank.glb')
save(SOURCE)
print('built', OUT / 'ship.glb', OUT / 'treasure.glb', SOURCE)
