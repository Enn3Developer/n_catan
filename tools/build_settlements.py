"""Build the cottage, the harbor, the robber camp and the worksites with Blender Python.

Run: python3 tools/build_settlements.py (needs the bpy module or Blender's Python).
It writes assets/source/settlements.blend and one glTF per model in
assets/models/settlements/.

Blender -Y is the front: it exports as Godot +Z, towards the default camera.
The game relies on these names and places (see docs/development.md):

- Cottage: fits a 0.22 square; NightWindow glows at night beside NightLight.
- Harbor: the quay top is at z .236 on the land side, the pier deck at .08
  runs out to y -.75; Lantern (with NightLantern and NightLight) at
  (.135, -.54, .16); MooredBoat floats at (.29, -.61) and the board bobs it;
  TimberHouse holds a half-size cottage on the quay.
- Robber camp: every top-level part is lifted onto the ground separately.
  Campfire glows at night. The outlaws stand at x ±.145 and z ±.05, and the
  number token starts .145 in front, so props keep to the sides and back.
- Worksites: the worker strikes a point .14 in front of the origin, at
  height .044 on the stump and .0345 on the clay and stone piles.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_kit import empty, export, lamp, material, new_collection, reset, save  # noqa: E402
from model_kit import Part, aim, euler, triangles  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/settlements'
SOURCE = ROOT / 'assets/source/settlements.blend'

reset('Settlements')

PLASTER = material('CottagePlaster', 'eadbb8')
STONE = material('Stone', 'a19b8e')
STONE_DARK = material('StoneDark', '7d776c')
TIMBER = material('Wood', '6b4a2f')
PLANK = material('Plank', '9a7550')
DOOR = material('Door', '7c5332')
IRON = material('Iron', '3d3a36', .5, .5)
SHADE = material('Shade', '2e2620')
GLOW = material('NightGlow', '665544')
ROOF = material('CottageRoof', '9b5b3d')
ROOF_DARK = material('CottageRoofDark', '7f4a33')
SLATE = material('SlateRoof', '687b80')
SLATE_DARK = material('SlateRoofDark', '55666c')
CHIMNEY = material('Chimney', '8f6e5b')
FLOWER_RED = material('FlowerRed', 'c9503f')
FLOWER_GOLD = material('FlowerGold', 'e0b54f')
LEAF = material('Leaf', '5f8a4a')
HAY = material('Hay', 'd8b565')

report = {}


def finish(name, col):
    export(col, OUT / (name + '.glb'))
    report[name] = sum(triangles(o) for o in col.all_objects if o.type == 'MESH')
    for obj in col.all_objects:
        obj.name = col.name + '.' + obj.name


# ------------------------------------------------------------------ cottage

def roof_slab(p, x0, x1, y_ridge, z_ridge, y_eave, z_eave, mat, dark, rows=5, thick=.010):
    """One pitched roof side as overlapping shingle courses, eave to ridge."""
    for r in range(rows):
        t0 = r / rows
        t1 = (r + 1.25) / rows
        ya, za = y_eave + (y_ridge - y_eave) * t0, z_eave + (z_ridge - z_eave) * t0
        yb, zb = y_eave + (y_ridge - y_eave) * min(t1, 1), z_eave + (z_ridge - z_eave) * min(t1, 1)
        n = Vector((0, -(zb - za), yb - ya)).normalized()
        if n.z < 0:
            n = -n
        lift = n * thick * (.6 if r % 2 else 1.0)
        pts = [Vector((x0, ya, za)) + lift, Vector((x1, ya, za)) + lift, Vector((x1, yb, zb)) + lift, Vector((x0, yb, zb)) + lift]
        p.polygon(pts, dark if r % 2 else mat, thickness=thick)


def window(p, x, y, z, w=.026, h=.030, facing=-1, glow=None, flowers=True):
    """A deep-set window with frame, sill, shutters and a flower box."""
    p.box((x, y + facing * .002, z), (w + .008, .006, h + .008), TIMBER, .0015)
    if glow is None:
        p.box((x, y + facing * .004, z), (w, .004, h), SHADE, .001)
    p.box((x, y + facing * .004, z), (.0025, .005, h), TIMBER)
    p.box((x, y + facing * .004, z), (w, .005, .0025), TIMBER)
    for s in (-1, 1):
        p.box((x + s * (w * .5 + .009), y + facing * .006, z), (.010, .003, h + .004), DOOR, .0012)
    p.box((x, y + facing * .008, z - h * .5 - .004), (w + .012, .010, .004), TIMBER, .001)
    if flowers:
        p.box((x, y + facing * .012, z - h * .5 - .010), (w + .006, .010, .009), PLANK, .0012)
        for i in range(5):
            fx = x - w * .45 + i * w * .225
            p.ellipsoid((fx, y + facing * .013, z - h * .5 - .003), (.0042, .0042, .0038), LEAF, 6, 4)
            p.ellipsoid((fx + .001, y + facing * .016, z - h * .5 + .0015), (.0026, .0026, .0024), FLOWER_RED if i % 2 else FLOWER_GOLD, 6, 4)


def cottage(col, parent=None, location=(0, 0, 0), roof=ROOF, roof_dark=ROOF_DARK, name='Cottage'):
    """A half-timbered cottage, front to -Y, fitting a 0.22 square."""
    p = Part(name)
    W, D, H = .160, .126, .118        # walls: width (x), depth (y), height above the plinth
    base = .016
    # Rubble plinth, slightly wider than the walls.
    p.box((0, 0, base / 2 - .004), (W + .014, D + .014, base + .008), STONE, .004)
    for i in range(14):
        a = i * 2.39
        sx = math.cos(a) * (W / 2 + .006)
        sy = math.sin(a) * (D / 2 + .006)
        p.rock((max(-W / 2 - .004, min(W / 2 + .004, sx)), max(-D / 2 - .004, min(D / 2 + .004, sy)), .006), (.009, .008, .006), STONE_DARK, seed=i)
    # Plaster walls with timber framing proud of the surface.
    p.box((0, 0, base + H / 2), (W, D, H), PLASTER, .002)
    beam = .0075
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (W / 2 - beam / 2 + .0015), sy * (D / 2 - beam / 2 + .0015), base + H / 2), (beam + .002, beam + .002, H), TIMBER, .0015)
    for sy in (-1, 1):
        y = sy * (D / 2 + .0015)
        for z in (base + .003, base + H * .52, base + H - .003):
            p.box((0, y, z), (W + .004, .006, beam), TIMBER, .0015)
        # Cross braces in the side panels of each long wall.
        for sx in (-1, 1):
            cx = sx * W * .36
            ang = math.atan2(H * .45, W * .22)
            p.box((cx, y, base + H * .26), (.006, .006, math.hypot(H * .45, W * .22)), TIMBER, .001, rot=(0, sx * (math.pi / 2 - ang), 0))
    for sx in (-1, 1):
        x = sx * (W / 2 + .0015)
        for z in (base + .003, base + H - .003):
            p.box((x, 0, z), (.006, D + .004, beam), TIMBER, .0015)
        p.box((x, 0, base + H * .5), (.006, beam, H), TIMBER, .0015)
    # Gable ends: plaster triangles with a king post.
    ridge = base + H + .092
    for sx in (-1, 1):
        x = sx * (W / 2)
        tri = [Vector((x, -D / 2, base + H)), Vector((x, D / 2, base + H)), Vector((x, 0, ridge - .004))]
        if sx < 0:
            tri.reverse()
        p.polygon(tri, PLASTER, thickness=.004)
        p.box((x + sx * .003, 0, (base + H + ridge) / 2), (.006, beam, ridge - base - H), TIMBER, .0012)
        p.box((x + sx * .003, 0, base + H + .004), (.006, D + .004, beam), TIMBER, .0012)
    # Door with frame, planks, hinges and a stone step.
    dx = .032
    p.box((dx, -D / 2 - .003, base + .038), (.038, .008, .078), TIMBER, .0015)
    p.box((dx, -D / 2 - .006, base + .036), (.030, .004, .070), DOOR, .001)
    for i in range(3):
        p.box((dx - .010 + i * .010, -D / 2 - .0085, base + .036), (.0015, .001, .068), TIMBER)
    for z in (.020, .052):
        p.box((dx - .006, -D / 2 - .0088, base + z), (.018, .0015, .004), IRON)
    p.ellipsoid((dx + .010, -D / 2 - .010, base + .036), (.0022, .0022, .0022), IRON, 6, 4)
    p.box((dx, -D / 2 - .016, .006), (.046, .020, .012), STONE, .003)
    # Windows: the lit one is its own mesh; the others are painted dark.
    window(p, -.040, -D / 2 - .002, base + .072, glow=True)
    window(p, -.050, D / 2 + .002, base + .070, facing=1, flowers=False)
    window(p, .045, D / 2 + .002, base + .070, facing=1, flowers=False)
    # Roof: two shingled slabs overhanging the walls, a ridge beam, bargeboards.
    over_x, over_y = .022, .024
    for sy in (-1, 1):
        roof_slab(p, -W / 2 - over_x, W / 2 + over_x, 0, ridge, sy * (D / 2 + over_y), base + H - .012, roof, roof_dark)
        for sx in (-1, 1):
            a = Vector((sx * (W / 2 + over_x - .002), sy * (D / 2 + over_y), base + H - .010))
            b = Vector((sx * (W / 2 + over_x - .002), 0, ridge + .004))
            p.tube(a, b, .0045, .0045, TIMBER, 6, smooth=False)
    p.tube((-W / 2 - over_x - .006, 0, ridge + .008), (W / 2 + over_x + .006, 0, ridge + .008), .0075, .0075, roof_dark, 8, smooth=True)
    # Stone chimney through the back slope, with a cap.
    cx, cy = -.048, .026
    p.box((cx, cy, ridge - .010), (.026, .024, .10), CHIMNEY, .002)
    for i in range(6):
        p.box((cx, cy, ridge - .050 + i * .016), (.029, .027, .004), STONE_DARK, .001)
    p.box((cx, cy, ridge + .044), (.032, .030, .006), STONE, .0015)
    # Firewood stacked under the eave on the right, and a water barrel on the left.
    for row in range(3):
        for i in range(4 - row):
            y = -.030 + i * .016 + row * .008
            p.tube((W / 2 + .004, y, .010 + row * .013), (W / 2 + .024, y, .010 + row * .013), .0068, .0068, PLANK if (i + row) % 2 else TIMBER, 8)
    p.lathe([(.0, .0), (.014, .0), (.016, .012), (.016, .022), (.014, .032), (.0, .032)], PLANK, 12, center=(-W / 2 - .010, -D / 2 + .012, .0), smooth=True)
    for z in (.006, .026):
        p.torus((-W / 2 - .010, -D / 2 + .012, z), .0158, .0014, IRON, 12, 4)
    obj = p.build(col, parent, location)
    # The lit window pane glows at night; its lamp sits just outside.
    g = Part('NightWindow')
    g.box((0, 0, 0), (.026, .004, .030), GLOW)
    glow = g.build(col, parent, (location[0] - .040, location[1] - D / 2 - .006, location[2] + base + .072))
    lamp('NightLight', (location[0] - .040, location[1] - D / 2 - .030, location[2] + base + .072), col, parent, .28, 2.2)
    return obj, glow


# ------------------------------------------------------------------ harbor

def harbor():
    col = new_collection('Harbor')
    p = Part('HarborMesh')
    # A stone quay block against the coast, its top at .236.
    p.box((0, -.065, .110), (.19, .20, .236), STONE, .006)
    rng = random.Random(4)
    for row in range(5):
        for i in range(6):
            x = -.080 + i * .032 + (row % 2) * .016
            if abs(x) > .085:
                continue
            p.box((x, -.166, .028 + row * .044), (.029, .006, .040), STONE_DARK if (i + row) % 3 == 0 else STONE, .004)
    p.box((0, -.065, .232), (.198, .208, .010), material('QuayTop', 'b7ae9c'), .003)
    # Steps down the seaward face to the pier.
    steps = material('Steps', 'a8a092')
    for i in range(6):
        z = .212 - i * .026
        p.box((0, -.176 - i * .034, z / 2 + .02), (.13, .036, z - .03), steps, .003)
    # The pier: deck planks on piles, a rail on one side, bollards and a lantern.
    planks = [material('Plank0', 'a47d55'), material('Plank1', '8f6a45')]
    for i in range(12):
        y = -.37 - i * .031
        p.box((0, y, .068), (.30 + (.006 if i % 3 == 0 else 0), .028, .012), planks[i % 2], .0025, rot=(0, 0, rng.uniform(-.02, .02)))
    for sx in (-1, 1):
        p.box((sx * .142, -.555, .056), (.014, .39, .014), TIMBER, .002)
    wood = TIMBER
    cap = material('PileCap', '5a3e27')
    for y in (-.38, -.52, -.66, -.745):
        for sx in (-1, 1):
            p.tube((sx * .150, y, -.10), (sx * .150, y, .115), .0125, .0115, wood, 10)
            p.ellipsoid((sx * .150, y, .118), (.013, .013, .006), cap, 10, 5)
    # Rope rail posts on the east side.
    rope = material('Rope', 'c7ad7a')
    for y0, y1 in ((-.38, -.52), (-.52, -.66), (-.66, -.745)):
        mid = [Vector((.150, y0 + (y1 - y0) * t, .112 - math.sin(math.pi * t) * .018)) for t in (0, .25, .5, .75, 1)]
        for a, b in zip(mid, mid[1:]):
            p.tube(a, b, .0028, .0028, rope, 6)
    # A coil of rope, barrels and crates of goods waiting to ship.
    p.torus((-.090, -.70, .080), .018, .006, rope, 14, 6)
    p.torus((-.090, -.70, .088), .012, .005, rope, 12, 6)
    crate = material('Crate', 'b08a58')
    for (x, y, z, s) in ((.050, -.050, .258, .030), (.070, -.090, .258, .026), (.058, -.068, .286, .024), (-.110, -.46, .092, .028)):
        p.box((x, y, z), (s, s, s), crate, .002)
        p.box((x, y - s / 2 - .0005, z), (s * .86, .001, .004), TIMBER)
        p.box((x, y - s / 2 - .0005, z), (.004, .001, s * .86), TIMBER)
    for (x, y) in ((-.110, -.50), (-.084, -.515)):
        p.lathe([(.0, .0), (.012, .0), (.014, .010), (.014, .020), (.012, .030), (.0, .030)], PLANK, 12, center=(x, y, .074))
        for z in (.079, .099):
            p.torus((x, y, z), .0135, .0012, IRON, 12, 4)
    # Bollard at the pier end.
    p.lathe([(.0, .0), (.012, .0), (.010, .018), (.013, .022), (.0, .026)], IRON, 10, center=(-.110, -.735, .074))
    p.build(col)
    # Lantern on a post at the pier end, beside the sign.
    lantern = empty('Lantern', col, (.135, -.54, .16))
    post = Part('LanternPost')
    post.tube((0, 0, -.090), (0, 0, .018), .0055, .005, TIMBER, 8)
    post.box((-.010, 0, .026), (.024, .005, .005), TIMBER, .001)
    post.lathe([(.0, .018), (.013, .018), (.013, .021), (.0, .021)], IRON, 8, center=(0, 0, .0), smooth=False)
    post.lathe([(.013, .0), (.016, .003), (.0, .014)], IRON, 8, center=(0, 0, .021), smooth=False)
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        post.tube((math.cos(a) * .011, math.sin(a) * .011, -.016), (math.cos(a) * .011, math.sin(a) * .011, .018), .0014, .0014, IRON, 4)
    post.lathe([(.0, -.019), (.013, -.019), (.013, -.016), (.0, -.016)], IRON, 8, smooth=False)
    post.build(col, lantern)
    g = Part('NightLantern')
    g.lathe([(.0, -.016), (.0095, -.016), (.0095, .016), (.0, .016)], GLOW, 8, smooth=False)
    g.build(col, lantern)
    lamp('NightLight', (0, 0, 0), col, lantern, .38, 4.0)
    # A small fishing boat tied up at the pier.
    boat = empty('MooredBoat', col, (.29, -.61, -.025))
    boat.scale = (.65, .65, .65)
    b = Part('MooredBoatMesh')
    hull = material('MooredHull', '7a5236')
    deck = material('MooredDeck', 'c4a070')
    stripe = material('MooredStripe', '3f6f8a')
    rows = []
    stations = [(.44, .02, .12), (.36, .09, .10), (.18, .14, .08), (0, .15, .075), (-.18, .14, .08), (-.34, .10, .095), (-.43, .04, .12)]
    for y, beam, sheer in stations:
        row = []
        for t in (-1, -.85, -.55, 0, .55, .85, 1):
            x = t * beam
            z = sheer if abs(t) == 1 else (sheer * .45 if abs(t) > .8 else (-.05 if abs(t) > .3 else -.085))
            row.append(Vector((x, y, z)))
        rows.append(row)
    b.quad_strip(rows, hull)
    b.polygon([Vector((-.12, .17, .06)), Vector((.12, .17, .06)), Vector((.13, -.17, .06)), Vector((-.13, -.17, .06))], deck, .008)
    for sx in (-1, 1):
        b.quad_strip([[Vector((sx * beam * 1.005, y, sheer - .012)), Vector((sx * beam * 1.005, y, sheer - .030))] for y, beam, sheer in stations[1:-1]], stripe, smooth=False)
    for y in (.12, -.12):
        b.box((0, y, .075), (.27, .03, .012), PLANK, .003)
    b.tube((0, .05, .06), (0, .05, .80), .012, .008, TIMBER, 8)
    # The sail is furled along the boom: a fat, folded bundle of canvas held by rope ties.
    canvas = material('Canvas', 'e9dfc6')
    rope = material('Rope', '5a4634')
    boom_a, boom_b = Vector((0, .04, .30)), Vector((0, -.34, .255))
    b.tube(boom_a, boom_b, .008, .007, TIMBER, 6)
    length = (boom_b - boom_a).length
    folds = [(.012 + .032 * math.sin(math.pi * min(1, t / .9)) ** .6 + .007 * abs(math.sin(t * math.pi * 6)), t * length)
             for t in [k / 24 for k in range(25)]]
    folds = [(.0, -.004)] + folds + [(.0, length + .004)]
    lift = Vector((0, 0, .03))
    b.lathe(folds, canvas, 12, matrix=aim(boom_a + lift, boom_b + lift), scale=(1.0, .8))
    axis = (boom_b - boom_a).normalized()
    for t in (.18, .42, .66, .86):
        at = boom_a + lift + axis * (length * t)
        r = .012 + .032 * math.sin(math.pi * min(1, t / .9)) ** .6
        b.torus(at, r + .002, .004, rope, 16, 4, matrix=aim(Vector(), axis))
    # Stays from the masthead to the bow, the stern and both rails, and a pennant.
    head = Vector((0, .05, .76))
    for end in ((0, -.43, .12), (0, .44, .12), (.14, .06, .08), (-.14, .06, .08)):
        b.tube(head, end, .003, .003, rope, 4, smooth=False)
    b.quad_strip([[Vector((0, .05 + k * .03, .80 - k * .004)), Vector((0, .05 + k * .03, .76 - k * .002))] for k in range(6)], stripe, smooth=True)
    b.build(col, boat)
    # The harbourmaster's cottage on the quay.
    house = empty('TimberHouse', col, (-.025, -.055, .238))
    house.scale = (.5, .5, .5)
    cottage(col, house, roof=SLATE, roof_dark=SLATE_DARK)
    finish('harbor', col)


# ------------------------------------------------------------------ robber camp

def camp():
    col = new_collection('Camp')
    rng = random.Random(9)
    # Hearth: a ring of stones around crossed logs and embers.
    hearth = empty('Hearth', col, (0, 0, 0))
    p = Part('HearthMesh')
    for i in range(9):
        a = i * math.tau / 9 + rng.uniform(-.1, .1)
        p.rock((math.cos(a) * .036, math.sin(a) * .036, .007), (.012, .010, .009), STONE if i % 2 else STONE_DARK, seed=i)
    for i in range(4):
        a = i * math.pi / 4 + .3
        d = Vector((math.cos(a), math.sin(a), 0))
        p.tube(-d * .030 + Vector((0, 0, .006 + i * .002)), d * .030 + Vector((0, 0, .010 + i * .002)), .0055, .0050, TIMBER, 8)
    # A log bench and a stump seat.
    p.tube((-.10, .085, .012), (-.02, .115, .012), .012, .011, TIMBER, 10)
    p.lathe([(.0, .0), (.016, .0), (.015, .022), (.0, .023)], TIMBER, 10, center=(.085, .095, 0))
    p.lathe([(.0, .0228), (.015, .0228), (.0, .0232)], PLANK, 10, center=(.085, .095, 0))
    p.build(col, hearth)
    fire = Part('Campfire')
    for i, (h, r) in enumerate(((.040, .016), (.030, .011), (.024, .009))):
        a = i * 2.1
        fire.lathe([(r, .0), (r * .9, h * .4), (r * .45, h * .8), (.0, h)], GLOW, 7, center=(math.cos(a) * .006 * (i > 0), math.sin(a) * .006 * (i > 0), .006), smooth=True)
    fire.build(col, None, (0, 0, .004))
    # A patched lean-to tent behind the fire.
    tent = empty('Tent', col, (-.02, .19, 0))
    t = Part('TentMesh')
    canvas = material('TentCanvas', 'a38b63')
    patch = material('TentPatch', '7b6647')
    for sx in (-1, 1):
        t.polygon([Vector((sx * .09, -.07, .0)), Vector((sx * .09, .07, .0)), Vector((0, .07, .15)), Vector((0, -.07, .15))][::(1 if sx > 0 else -1)], canvas, .004)
    t.polygon([Vector((-.09, .07, .0)), Vector((.09, .07, .0)), Vector((0, .07, .15))], patch, .004)
    t.box((.035, -.071, .045), (.03, .002, .025), patch, .0, rot=(0, .6, 0))
    t.tube((0, -.09, .153), (0, .09, .153), .0045, .0045, TIMBER, 6)
    for y in (-.085, .085):
        t.tube((.0, y, .0), (.0, y, .16), .0045, .0045, TIMBER, 6)
    for sx in (-1, 1):
        t.tube((sx * .105, -.10, .0), (sx * .05, -.07, .085), .0012, .0012, material('Rope', 'c7ad7a'), 4)
        t.box((sx * .105, -.10, .003), (.004, .004, .012), TIMBER)
    t.build(col, tent)
    # Loot: sacks, a chest and a crate beside the tent, clear of the token.
    for i, (x, y, s) in enumerate(((.20, .08, 1.0), (.235, .10, .9), (.215, .125, .85))):
        sack = empty(f'Sack{i}', col, (x, y, .0))
        q = Part(f'Sack{i}Mesh')
        q.ellipsoid((0, 0, .022 * s), (.022 * s, .019 * s, .024 * s), material('Sack', 'b69a6b'), 12, 8,
                    squash=lambda v: (v.x * (1 + .25 * max(0, -v.z)), v.y * (1 + .25 * max(0, -v.z)), max(v.z, -.8)))
        q.lathe([(.009 * s, .043 * s), (.006 * s, .050 * s), (.010 * s, .056 * s), (.0, .058 * s)], material('Sack', 'b69a6b'), 8)
        q.torus((0, 0, .046 * s), .007 * s, .0018, material('Rope', 'c7ad7a'), 8, 4)
        q.build(col, sack)
    chest = empty('Chest', col, (-.20, .07, .0))
    c = Part('ChestMesh')
    c.box((0, 0, .016), (.052, .034, .032), PLANK, .003)
    c.prism([(-.026, .032), (.026, .032), (.026, .042), (.018, .049), (.0, .052), (-.018, .049), (-.026, .042)], -.017, .017, PLANK, .0015,
            matrix=Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
    for x in (-.018, .018):
        c.box((x, 0, .026), (.005, .036, .052), IRON)
    c.box((0, -.0175, .030), (.008, .003, .010), material('Gold', 'd8b04a', .4, .6))
    c.build(col, chest)
    # Two stolen swords stuck in the ground and a banner on a pole.
    banner = empty('Banner', col, (-.24, .17, .0))
    f = Part('BannerMesh')
    f.tube((0, 0, .0), (0, 0, .24), .0045, .004, TIMBER, 6)
    cloth = material('BannerCloth', '3c3f3b')
    f.polygon([Vector((.002, 0, .235)), Vector((.062, .004, .228)), Vector((.050, .006, .200)), Vector((.064, .002, .172)), Vector((.002, 0, .168))], cloth, .003)
    f.ellipsoid((.028, -.002, .202), (.009, .002, .009), material('BannerMark', 'c9b58a'), 8, 4)
    f.build(col, banner)
    finish('robber_camp', col)


# ------------------------------------------------------------------ worksites

def worksite_stump():
    col = new_collection('Stump')
    p = Part('StumpMesh')
    bark = material('Wood', '6b4a2f')
    heart = material('Heartwood', 'd9b27a')
    ring = material('Ring', 'b88d5a')
    # A chopping stump: flared roots, bark ridges, a pale cut face with rings.
    wob = lambda a, z: 1 + .07 * math.sin(a * 7) + .05 * math.cos(a * 3)
    p.lathe([(.042, -.002), (.036, .006), (.030, .016), (.029, .036), (.030, .043)], bark, 16, center=(0, .14, 0), wobble=wob, cap_top=False)
    p.lathe([(.029, .043), (.0, .044)], heart, 16, center=(0, .14, 0), wobble=wob, cap_bottom=False)
    for r in (.010, .019):
        p.torus((0, .14, .0442), r, .0009, ring, 16, 3)
    for i in range(5):
        a = i * 1.26
        p.tube((math.cos(a) * .026, .14 + math.sin(a) * .026, .004), (math.cos(a) * .052, .14 + math.sin(a) * .052, -.002), .008, .004, bark, 6)
    # Split logs and chips around it.
    for i, (x, y, rot) in enumerate(((-.05, .10, .3), (.048, .105, -.5), (.055, .17, 1.1))):
        p.prism([(0, 0), (.018, 0), (.009, .014)], -.018, .018, heart if i % 2 else ring, .0015,
                matrix=Matrix.Translation((x, y, .0)) @ euler((math.pi / 2, 0, rot)))
    for i in range(7):
        a = i * 2.2
        p.box((math.cos(a) * .045, .14 + math.sin(a) * .04, .0015), (.008, .005, .002), heart, 0, rot=(0, 0, a))
    p.build(col)
    finish('worksite_stump', col)


def worksite_pile(name, mat_name, color, dark, bricks):
    col = new_collection(name)
    p = Part(name + 'Mesh')
    main = material(mat_name, color)
    shade = material(mat_name + 'Dark', dark)
    rng = random.Random(len(name))
    if bricks:
        # Wet clay dug into a heap, with cut bricks stacked beside it.
        p.rock((0, .14, .010), (.040, .034, .030), main, seed=3, rough=.30, subdiv=1, smooth=True)
        p.rock((.018, .15, .022), (.020, .018, .016), shade, seed=5, rough=.3, subdiv=1, smooth=True)
        p.rock((-.020, .155, .016), (.016, .015, .012), main, seed=8, rough=.3, subdiv=1, smooth=True)
        for row in range(2):
            for i in range(3 - row):
                p.box((-.062 + i * .019 + row * .0095, .12, .007 + row * .012), (.017, .026, .011), shade if (i + row) % 2 else main, .002)
        # A spade stuck in the heap.
        p.tube((.036, .12, .000), (.056, .10, .060), .0024, .0024, material('Handle', '93693f'), 6)
        p.box((.034, .122, .004), (.014, .003, .018), IRON, .001, rot=(0, -.3, .7))
    else:
        # Quarried blocks and rubble; the top of the pile is the worker's target.
        blocks = [((0, .14, .012), (.034, .030, .024)), ((-.008, .145, .031), (.022, .020, .014)),
                  ((.040, .12, .008), (.026, .024, .016)), ((-.044, .125, .009), (.024, .026, .018))]
        for i, (c, s) in enumerate(blocks):
            p.box(c, s, main if i % 2 == 0 else shade, .003, rot=(0, 0, rng.uniform(-.4, .4)))
        for i in range(8):
            a = i * 2.4
            p.rock((math.cos(a) * .050, .14 + math.sin(a) * .036, .004), (.007, .006, .005), shade, seed=i)
        # A mallet left beside the blocks.
        p.tube((-.050, .10, .003), (-.030, .085, .003), .0022, .0022, material('Handle', '93693f'), 6)
        p.box((-.052, .101, .005), (.010, .016, .010), material('Handle', '93693f'), .002, rot=(0, 0, .6))
    p.build(col)
    finish({'ClayPile': 'worksite_clay', 'StonePile': 'worksite_stone'}[name], col)


col = new_collection('Cottage')
cottage(col)
finish('cottage', col)
harbor()
camp()
worksite_stump()
worksite_pile('ClayPile', 'Clay', 'b56c4b', '96573c', True)
worksite_pile('StonePile', 'StoneBlock', 'aba59a', '8a857a', False)
save(SOURCE)
print('SETTLEMENTS', report)
