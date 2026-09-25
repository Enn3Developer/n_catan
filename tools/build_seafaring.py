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
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_kit import (Vector, bmesh, box, cylinder, blob, empty, export as export_to, from_bmesh, join, lamp,  # noqa: E402
                         material, mesh, new_collection, reset, save)

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/seafaring.blend'
OUT = ROOT / 'assets/models/props'

reset('Seafaring')


def export(col, filename):
    export_to(col, OUT / filename)


# ------------------------------------------------------------------ ship

WOOD = material('PBR_Wood', 'a0774e')
DECK = material('Deck', 'c9a877')
TIMBER = material('Timber', '4e3524')
SAIL = material('Sail', 'efe6d2')
OWNER = material('Owner', 'ed815d')
OWNER_DARK = material('Owner-20', 'be674a')
LANTERN = material('NightLantern', 'ffd092')

ship_col = new_collection('Ship')
ship = empty('Ship', ship_col)

# Hull stations from stern (+Y) to bow (-Y): y, half beam, sheer height, keel depth.
STATIONS = [
    (.200, .036, .062, .010),
    (.160, .052, .054, -.004),
    (.090, .062, .050, -.016),
    (.000, .064, .048, -.020),
    (-.090, .058, .050, -.016),
    (-.160, .038, .058, -.006),
    (-.215, .004, .072, .012),
]
# Each station is a U: gunwale, turn of the bilge, keel, mirrored.
bm = bmesh.new()
rows = []
for y, beam, sheer, keel in STATIONS:
    shape = [(-beam, sheer), (-beam * .92, sheer * .45), (-beam * .55, keel * .6 + .004), (0, keel),
             (beam * .55, keel * .6 + .004), (beam * .92, sheer * .45), (beam, sheer)]
    rows.append([bm.verts.new((x, y, z)) for x, z in shape])
for a, b in zip(rows, rows[1:]):
    for i in range(len(a) - 1):
        bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
# The transom closes the stern.
bm.faces.new(list(reversed(rows[0])))
hull = from_bmesh('Hull', bm, [WOOD], ship_col, ship, smooth=True, recalc=False)
# Every hull face must point away from the keel line, or the textured wood shader culls it.
centre = Vector((0, 0, .03))
assert all(poly.normal.dot(poly.center - centre) > 0 for poly in hull.data.polygons), 'hull faces point inward'
bevel = hull.modifiers.new('Soften', 'BEVEL')
bevel.width = .003
bevel.segments = 2

# Deck planking just below the gunwale, and a strake in the owner's color.
deck_outline = [(s[0], s[1] * .9) for s in STATIONS]
deck_vertices = [(-b, y, .044) for y, b in deck_outline] + [(b, y, .044) for y, b in reversed(deck_outline)]
mesh('Deck', deck_vertices, [tuple(range(len(deck_vertices)))], [DECK], ship_col, ship)
for side in (-1, 1):
    strake = []
    for y, beam, sheer, keel in STATIONS[:-1]:
        strake.append((side * (beam + .002), y, sheer - .004))
        strake.append((side * (beam * .97 + .002), y, sheer - .016))
    faces = [(i, i + 1, i + 3, i + 2) for i in range(0, len(strake) - 2, 2)]
    mesh('Strake' + ('Port' if side < 0 else 'Starboard'), strake, faces, [OWNER_DARK], ship_col, ship)

# Mast, yard and bowsprit.
mast_foot = Vector((0, .01, .044))
cylinder('Mast', mast_foot, mast_foot + Vector((0, 0, .30)), .0075, TIMBER, ship_col, ship, radius_end=.005)
cylinder('Yard', (-.075, .004, .245), (.075, .004, .245), .004, TIMBER, ship_col, ship)
cylinder('Boom', (0, .012, .085), (0, .15, .088), .004, TIMBER, ship_col, ship)
cylinder('Bowsprit', (0, -.19, .062), (0, -.29, .09), .004, TIMBER, ship_col, ship)

# A square sail billowing forward, hung from the yard, in the owner's color.
grid = []
columns, lines = 5, 4
for row in range(lines + 1):
    v = row / lines
    for column in range(columns + 1):
        u = column / columns - .5
        belly = (1 - (2 * u) ** 2) * math.sin(v * math.pi * .9) * .028
        grid.append((u * .145 * (1 - v * .08), -belly - .002, .24 - v * .15))
faces = []
for row in range(lines):
    for column in range(columns):
        a = row * (columns + 1) + column
        faces.append((a, a + 1, a + columns + 2, a + columns + 1))
mesh('Mainsail', grid, faces, [OWNER], ship_col, ship, smooth=True)
# A triangular jib from the bowsprit.
mesh('Jib', [(0, -.012, .23), (0, -.27, .085), (0, -.03, .075)], [(0, 1, 2)], [SAIL], ship_col, ship)
mesh('Pennant', [(0, .005, .345), (0, .075, .335), (0, .005, .322)], [(0, 1, 2)], [OWNER], ship_col, ship)

# Stern cabin with a lantern that lights up at night.
box('Cabin', (0, .15, .062), (.07, .06, .035), WOOD, ship_col, ship, bevel=.003)
box('CabinRoof', (0, .15, .082), (.08, .07, .007), TIMBER, ship_col, ship)
lantern_pivot = empty('LanternPivot', ship_col, (0, .205, .1), ship)
box('NightLantern', (0, 0, 0), (.014, .014, .018), LANTERN, ship_col, lantern_pivot)
cylinder('LanternPost', (0, .19, .08), (0, .205, .092), .002, TIMBER, ship_col, ship)
lamp('NightLight', (0, 0, .004), ship_col, lantern_pivot, .5, 3.0)

# ------------------------------------------------------------------ treasure

GOLD = material('Gold', 'e2b64a', roughness=.35, metallic=.8)
IRON = material('Iron', '5b5048', roughness=.5, metallic=.6)
RUBY = material('Ruby', 'd24c4c', roughness=.2)
SAPPHIRE = material('Sapphire', '4c8fd2', roughness=.2)
EMERALD = material('Emerald', '5cc27a', roughness=.2)
PAINT = material('Paint', 'a33a2c')
GLINT = material('NightLantern', 'ffd092')

treasure_col = new_collection('Treasure')
treasure = empty('Treasure', treasure_col)

box('Chest', (0, 0, .026), (.1, .066, .052), WOOD, treasure_col, treasure, bevel=.003)
for x in (-.036, .036):
    box('Band%s' % ('Left' if x < 0 else 'Right'), (x, 0, .026), (.009, .07, .056), IRON, treasure_col, treasure)
box('Lock', (0, -.035, .034), (.016, .006, .02), GOLD, treasure_col, treasure)
# The lid is a half barrel, hinged at the back and thrown open.
hinge = empty('LidHinge', treasure_col, (0, .033, .052), treasure)
hinge.rotation_euler = (math.radians(-105), 0, 0)
lid = []
segments = 8
for i in range(segments + 1):
    t = math.pi * i / segments
    for x in (-.05, .05):
        lid.append((x, -.033 + .033 * (1 - math.cos(t)), .02 * math.sin(t)))
faces = [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(segments)]
mesh('Lid', lid, faces, [WOOD], treasure_col, hinge)
lid_bm = hinge.children[0]
solid = lid_bm.modifiers.new('Thickness', 'SOLIDIFY')
solid.thickness = .006

# A heap of coins with gems on top; the heap glints at night.
heap_pivot = empty('HeapPivot', treasure_col, (0, 0, .052), treasure)
blob('NightLantern', (0, 0, 0), (.044, .028, .012), GLINT, treasure_col, heap_pivot)
lamp('NightLight', (0, 0, .02), treasure_col, heap_pivot, .45, 2.0)
coins = [(-.03, -.01, .006), (.028, .012, .008), (.01, -.018, .01), (-.012, .014, .011), (.034, -.016, .004)]
for i, (x, y, z) in enumerate(coins):
    cylinder('HeapCoin%d' % i, (x, y, .052 + z), (x, y, .055 + z), .009, GOLD, treasure_col, treasure, segments=10)
for name, mat, at in (('Ruby', RUBY, (-.016, .004, .07)), ('Sapphire', SAPPHIRE, (.018, -.008, .068)), ('Emerald', EMERALD, (.002, .014, .072))):
    blob(name, at, (.007, .007, .006), mat, treasure_col, treasure, 6, 4)
# Coins spilled on the sand in front, and a painted cross marking the spot.
for i in range(9):
    a = -.9 + 1.8 * i / 8
    r = .055 + (i % 3) * .018
    x, y = math.sin(a) * r, -.04 - math.cos(a) * r * .6
    cylinder('SpilledCoin%d' % i, (x, y, 0), (x, y, .003), .008, GOLD, treasure_col, treasure, segments=10)
for i, turn in enumerate((math.pi / 4, -math.pi / 4)):
    stroke = box('Cross%d' % i, (0, 0, .001), (.1, .014, .002), PAINT, treasure_col, treasure)
    stroke.rotation_euler = (0, 0, turn)
    stroke.location = (0, -.13, 0)


# ------------------------------------------------------------------ fog bank

# A low bank of cloud that hides one hex under the Fog house rule. Puffs sit
# on a hex grid inside the tile's corners (radius 1), a broad lower layer and
# smaller ones heaped on top, so the hex reads as a soft mound of mist. The
# game shades it by height and lets it drift; one mesh keeps it one draw call.
import random  # noqa: E402

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
