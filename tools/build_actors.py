"""Build the island's people and sheep with Blender Python.

Run: python3 tools/build_actors.py (needs the bpy module or Blender's Python).
It writes assets/source/actors.blend and one glTF per actor in
assets/models/actors/.

The rigs are fixed by scripts/living_world.gd, which drives the pivots by name
and solves the arms with fixed bone lengths, so only the meshes are free:

- Workers and the outlaw: Thigh0/1 at (±.020, 0, .079) with Knee at -.035;
  Torso at .079 with Head at +.074, UpperArm0/1 at (±.034, 0, .055) and
  Forearm at -.042. The hand sits .043 below the forearm pivot. Tool hangs
  from the torso origin; its handle runs along local Z, gripped at +.018 and
  -.017, with the axe edge at (0, .038, .084) and the pick tip at
  (0, .052, .069).
- Dwellers: Leg0/1 at (±.017, 0, .079), Torso at .079 with Arm0/1 at
  (±.031, 0, .052) and a Hat pivot at +.133.
- Sheep: Body at .070, legs at (±.031, ±.051, -.020) with knees at -.024,
  Neck at (0, .065, .005) with Ear0/1, and Tail at (0, -.071, .015).

Blender +Y is the way a figure faces; it exports as Godot -Z. Materials named
"Shirt" or "Skin" (with an optional signed percentage) take their color at
runtime; see docs/development.md.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_kit import empty, export, material, new_collection, reset, save  # noqa: E402
from model_kit import Part, aim, euler, triangles  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/actors'
SOURCE = ROOT / 'assets/source/actors.blend'

reset('Actors')

SHIRT = material('Shirt', 'b77453')
SHIRT_DARK = material('Shirt-12', '9f6246')
SHIRT_DEEP = material('Shirt-25', '87523a')
SHIRT_HOOD = material('Shirt-15', '9a6044')
SKIN = material('Skin', 'd9a784')
CHEEK = material('Skin-06', 'cf9a78')
HAIR = material('Hair', '5a3a24')
EYE = material('Eye', '1c1410', .4)
TROUSERS = material('Trousers', '5d4c3b')
BOOT = material('Boot', '3f2c20')
BELT = material('Belt', '4a3322')
BUCKLE = material('Buckle', 'c9a24a', .45, .6)
APRON = material('Apron', '8d6b49')
HANDLE = material('Handle', '93693f')
IRON = material('AxeHead', '6d7780', .45, .6)
EDGE = material('AxeEdge', 'c9d0d4', .35, .7)
STRAW = material('Straw', 'dcbc6c')
STRAW_BAND = material('StrawCrown', 'a8443a')
TINES = material('Tines', '8a6a45')
BLADE = material('Blade', 'b9c1c7', .35, .7)
CLOTH = material('Cloth', '4a4f4b')

report = {}


def finish(name, col):
    export(col, OUT / (name + '.glb'))
    report[name] = sum(triangles(o) for o in col.all_objects if o.type == 'MESH')
    # Free the pivot names for the next actor; the .blend keeps them prefixed.
    for obj in col.all_objects:
        obj.name = col.name + '.' + obj.name


# ------------------------------------------------------------------ shared body

def boot(p, toe=.026, heel=-.010, bottom=-.046, top=-.028, width=.0125):
    """A rounded boot: the sole is flat, the toe turns up a little."""
    mid = (toe + heel) / 2
    half = (toe - heel) / 2
    p.ellipsoid((0, mid, bottom + .0075), (width, half, .0095), BOOT, 12, 7,
                squash=lambda v: (v.x, v.y, max(v.z, -.55) + .08 * max(0, v.y) ** 2))
    p.tube((0, 0, bottom + .006), (0, 0, top), width * .95, width * .9, BOOT, 10)
    # A turned-down cuff hides the join with the trousers.
    p.torus((0, 0, top), width * .92, .0028, BOOT, 12, 5)


def worker_legs(root, col):
    for i, x in enumerate((-.020, .020)):
        thigh = empty(f'Thigh{i}', col, (x, 0, .079), root)
        p = Part(f'Thigh{i}Mesh')
        p.tube((0, 0, 0), (0, 0, -.036), .0135, .0115, TROUSERS, 10, round_ends=True)
        p.build(col, thigh, (0, 0, 0))
        knee = empty(f'Knee{i}', col, (0, 0, -.035), thigh)
        p = Part(f'Knee{i}Mesh')
        p.tube((0, 0, .002), (0, 0, -.022), .0112, .0104, TROUSERS, 10, round_ends=True)
        boot(p)
        p.build(col, knee)


def torso(p, apron=True, belly=1.0):
    """Tunic from hip to shoulder, belt and buckle; local to the Torso pivot."""
    profile = [(.0, -.010), (.022, -.009), (.028 * belly, -.002), (.030 * belly, .014), (.031 * belly, .030),
               (.032, .046), (.030, .058), (.024, .066), (.013, .071), (.0, .072)]
    p.lathe(profile, SHIRT, 16, scale=(1, .84))
    # The tunic flares a little below the belt.
    p.lathe([(.0295 * belly, -.004), (.032 * belly, -.016), (.030 * belly, -.020), (.0, -.021)], SHIRT_DARK, 16, scale=(1, .86))
    p.torus((0, 0, .009), .0305 * belly, .0035, BELT, 16, 5, matrix=Matrix.Diagonal((1, .85, 1, 1)))
    p.box((0, .0272 * belly, .009), (.011, .004, .0085), BUCKLE, .0012)
    # Collar.
    p.torus((0, 0, .066), .0145, .0032, SHIRT_DARK, 12, 5)
    if apron:
        # A leather apron wraps the front from chest to thigh.
        rows = []
        for z in (.040, .025, .009, -.008, -.024):
            row = []
            for i in range(9):
                a = math.radians(-58 + i * 14.5)
                r = (.0335 * belly if z < .03 else .0325) + (.002 if z < 0 else 0)
                row.append(Vector((math.sin(a) * r, math.cos(a) * r * .86 + .0012, z)))
            rows.append(row)
        p.quad_strip(rows, APRON)
        # Shoulder strap.
        for side in (-1, 1):
            p.tube((side * .014, .025, .040), (side * .012, .012, .066), .0022, .0022, APRON, 6)


def arms(root, col, forearm_mat=SKIN, sleeve=SHIRT, cuff=SHIRT_DARK):
    for i, x in enumerate((-.034, .034)):
        upper = empty(f'UpperArm{i}', col, (x, 0, .055), root)
        p = Part(f'UpperArm{i}Mesh')
        # A round shoulder cap and a sleeve that narrows to the elbow.
        p.ellipsoid((0, 0, -.002), (.0125, .012, .012), sleeve, 12, 7)
        p.tube((0, 0, -.002), (0, 0, -.043), .0112, .0092, sleeve, 10, round_ends=True)
        p.build(col, upper)
        fore = empty(f'Forearm{i}', col, (0, 0, -.042), upper)
        p = Part(f'Forearm{i}Mesh')
        p.torus((0, 0, -.004), .0088, .0028, cuff, 12, 5)
        p.tube((0, 0, .0), (0, 0, -.036), .0082, .0068, forearm_mat, 10, round_ends=True)
        # Mitten hand with a thumb, closed round the grip at -.043.
        p.ellipsoid((0, .001, -.043), (.0088, .0084, .0098), SKIN, 10, 7)
        p.ellipsoid((-x / abs(x) * .0065, .006, -.039), (.0035, .0042, .0052), SKIN, 8, 5)
        p.build(col, fore)


def face(p, z=.032, width=.027, depth=.026, height=.029, cheeks=True, nose=True, eyes=True, ears=True):
    """A big round cartoon head centred at z above the Head pivot."""
    p.tube((0, 0, -.002), (0, 0, .012), .0095, .0092, SKIN, 10)
    p.ellipsoid((0, .001, z), (width, depth, height), SKIN, 16, 11,
                squash=lambda v: (v.x * (1 - .08 * max(0, -v.z)), v.y, v.z))
    if nose:
        p.ellipsoid((0, depth + .0015, z - .003), (.0062, .0058, .0068), CHEEK, 10, 6)
    if cheeks:
        for s in (-1, 1):
            p.ellipsoid((s * .0145, depth * .83, z - .007), (.0058, .0035, .0045), CHEEK, 8, 5)
    if eyes:
        for s in (-1, 1):
            p.ellipsoid((s * .0098, depth * .93, z + .005), (.0034, .0022, .0044), EYE, 8, 5)
    if ears:
        for s in (-1, 1):
            p.ellipsoid((s * width * .98, -.002, z), (.0042, .0062, .0078), SKIN, 8, 5)


def hair_cap(p, z=.032, width=.027, depth=.026, height=.029, fringe=True, mat=HAIR):
    """Hair covering the back and top of the head, leaving the face clear."""
    def shape(v):
        # Pull the front edge back so the face shows; keep the back full.
        y = v.y
        if y > .15:
            y = .15 + (y - .15) * .25
        return (v.x * 1.06, y * 1.05 - .04, v.z * 1.04 + .02)
    p.ellipsoid((0, -.002, z + .002), (width, depth, height), mat, 16, 10, squash=shape)
    if fringe:
        p.ellipsoid((0, depth * .55, z + height * .62), (width * .78, .010, .0085), mat, 10, 6)


def tool_handle(p, top=.094, bottom=-.040, r=.0042):
    p.tube((0, 0, bottom), (0, 0, top), r * 1.05, r * .95, HANDLE, 8, round_ends=True)


def worker(name, head_extra, tool_extra, apron=True, belly=1.0, sleeve=SHIRT):
    col = new_collection(name)
    root = None  # Pivots sit at the top of the glTF, where living_world.gd looks.
    worker_legs(root, col)
    body = empty('Torso', col, (0, 0, .079), root)
    p = Part('TorsoMesh')
    torso(p, apron, belly)
    p.build(col, body)
    head = empty('Head', col, (0, 0, .074), body)
    p = Part('HeadMesh')
    head_extra(p)
    p.build(col, head)
    arms(body, col, sleeve=sleeve)
    tool = empty('Tool', col, (0, 0, 0), body)
    p = Part('ToolMesh')
    tool_extra(p)
    # The mesh keeps the old offset, so tool poses in living_world.gd still line up.
    obj = p.build(col, tool, (0, 0, .027))
    for v in obj.data.vertices:
        v.co.z -= .027
    return col


# ------------------------------------------------------------------ woodcutter

def woodcutter_head(p):
    face(p)
    hair_cap(p, fringe=False)
    # A full beard and a knitted cap with a turned-up brim.
    p.ellipsoid((0, .012, .018), (.022, .017, .016), HAIR, 12, 7,
                squash=lambda v: (v.x, v.y, min(v.z, .35)))
    p.ellipsoid((0, .026, .024), (.009, .004, .004), HAIR, 8, 4)
    p.lathe([(.0295, .040), (.0300, .049), (.0270, .060), (.020, .068), (.010, .072), (.0, .073)], SHIRT_DEEP, 14)
    p.torus((0, 0, .043), .0298, .0045, SHIRT_DARK, 14, 6)
    p.ellipsoid((0, -.002, .076), (.0065, .0065, .0065), SHIRT_DARK, 8, 5)


def axe(p):
    tool_handle(p)
    # Wedge head at the top: poll behind, cutting edge forward (+Y) at z .084.
    cheek = [(-.004, .076), (-.004, .092), (.014, .095), (.030, .100), (.040, .098), (.040, .070), (.030, .068), (.014, .077)]
    p.prism([(y, z) for y, z in cheek], -.0045, .0045, IRON, bevel=.0008,
            matrix=Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
    p.prism([(.034, .070), (.041, .069), (.042, .100), (.035, .100)], -.0030, .0030, EDGE,
            matrix=Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1))))
    p.ellipsoid((0, -.007, .084), (.0058, .0055, .008), IRON, 8, 5)


# ------------------------------------------------------------------ quarry worker

def quarry_head(p):
    face(p)
    hair_cap(p)
    # A leather work cap with a short peak, and a moustache.
    p.lathe([(.0292, .041), (.0298, .050), (.0255, .061), (.016, .067), (.0, .069)], APRON, 14)
    p.ellipsoid((0, .025, .042), (.020, .012, .0028), APRON, 12, 5)
    for s in (-1, 1):
        p.ellipsoid((s * .006, .0265, .023), (.0075, .0035, .0030), HAIR, 8, 5, matrix=euler((0, s * .35, 0)))


def pick(p):
    tool_handle(p)
    # Curved pick head crossing the handle top; tips at y ±.052, z .069.
    pts = []
    for i in range(13):
        t = -1 + i / 6
        y = t * .053
        z = .080 - (t * t) * .011
        r = .0055 * (1 - .65 * abs(t) ** 1.6) + .0012
        pts.append((Vector((0, y, z)), r))
    for (a, ra), (b, rb) in zip(pts, pts[1:]):
        mat = EDGE if abs(a.y) > .040 else IRON
        p.tube(a, b, ra, rb, mat, 8)
    p.box((0, 0, .080), (.011, .014, .015), IRON, .002)


# ------------------------------------------------------------------ farmer

def farmer_head(p):
    face(p)
    hair_cap(p)
    # A broad straw hat with a red band.
    p.lathe([(.0, .052), (.043, .050), (.046, .047), (.044, .045), (.030, .047), (.0, .048)], STRAW, 20)
    p.lathe([(.024, .046), (.0245, .058), (.020, .068), (.010, .072), (.0, .0725)], STRAW, 16)
    p.torus((0, 0, .050), .0248, .0028, STRAW_BAND, 16, 5)


def rake(p):
    tool_handle(p)
    # A wooden hay rake: head across the top, teeth pointing forward.
    p.tube((-.035, 0, .092), (.035, 0, .092), .0045, .0045, TINES, 8, round_ends=True)
    for i in range(7):
        x = -.030 + i * .010
        p.tube((x, .002, .092), (x, .027, .089), .0019, .0014, TINES, 6, round_ends=True)
    # Two braces from the handle into the head.
    for s in (-1, 1):
        p.tube((0, 0, .074), (s * .020, 0, .091), .0018, .0018, TINES, 6)


# ------------------------------------------------------------------ outlaw

def outlaw_head(p):
    face(p, cheeks=False)
    # Eyes sit in the shadow of the hood, over a scarf that hides the mouth.
    p.ellipsoid((0, .006, .019), (.0285, .0235, .0145), CLOTH, 14, 7)
    # A pointed hood with a face opening, falling onto the shoulders.
    def hood(v):
        y = v.y
        if y > .30:
            y = .30 + (y - .30) * .20
        z = v.z
        if z > 0:
            z = z * (1 + .55 * max(0, -v.y) * z)
        return (v.x * 1.12, y * 1.10 - .05, z * 1.10 + .03)
    p.ellipsoid((0, -.002, .033), (.029, .028, .031), SHIRT_HOOD, 16, 11, squash=hood)
    p.tube((0, -.024, .058), (0, -.043, .066), .008, .0015, SHIRT_HOOD, 8, round_ends=True)
    p.lathe([(.038, -.012), (.033, .000), (.022, .010), (.0, .011)], SHIRT_HOOD, 14, scale=(1, .9))


def sword(p):
    # A short sword: grip in the hand, crossguard, broad blade upward.
    p.tube((0, 0, -.030), (0, 0, .024), .0040, .0040, HANDLE, 8)
    p.ellipsoid((0, 0, -.032), (.0055, .0055, .0055), BUCKLE, 8, 5)
    p.box((0, 0, .026), (.024, .006, .005), BUCKLE, .0012)
    blade = [(-.0048, .029), (.0048, .029), (.0042, .104), (.0, .118), (-.0042, .104)]
    p.prism(blade, -.0014, .0014, BLADE, matrix=Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1))))


def outlaw():
    col = worker('HoodedOutlaw', outlaw_head, sword, apron=False, sleeve=SHIRT)
    body = next(o for o in col.objects if o.name == 'Torso')
    # A cloak hangs from the shoulders down the back.
    p = Part('Cloak')
    rows = []
    for z, spread, back in ((.066, .020, -.014), (.050, .036, -.028), (.020, .042, -.034), (-.012, .044, -.036), (-.045, .046, -.035)):
        row = []
        for i in range(9):
            a = math.radians(-100 + i * 25)
            row.append(Vector((math.sin(a) * spread, math.cos(a) * spread * .55 + back + .012 * (1 - abs(math.sin(a))) * -1, z)))
        rows.append(row)
    p.quad_strip(rows, SHIRT_HOOD)
    cloak = p.build(col, body)
    cloak.name = 'CloakMesh'
    finish('outlaw', col)


# ------------------------------------------------------------------ dweller

def dweller():
    col = new_collection('Dweller')
    root = None
    trousers = material('DwellerTrousers', '5d5245')
    shoe = material('DwellerShoe', '3b2c22')
    hat_mat = material('DwellerHat', 'd8bf86')
    hair = material('DwellerHair', '4f3522')
    for i, x in enumerate((-.017, .017)):
        leg = empty(f'Leg{i}', col, (x, 0, .079), root)
        p = Part(f'Leg{i}Mesh')
        p.tube((0, 0, .004), (0, 0, -.066), .0118, .0100, trousers, 8, round_ends=True)
        p.ellipsoid((0, .007, -.0715), (.0112, .0185, .0085), shoe, 10, 6,
                    squash=lambda v: (v.x, v.y, max(v.z, -.5)))
        p.build(col, leg)
    body = empty('Torso', col, (0, 0, .079), root)
    p = Part('TorsoMesh')
    # Tunic, belt, then a big head on a short neck. Low poly: towns hold dozens.
    p.lathe([(.0, -.012), (.026, -.011), (.029, .004), (.028, .030), (.026, .050), (.020, .060), (.010, .064), (.0, .065)], SHIRT, 12, scale=(1, .86))
    p.torus((0, 0, .008), .0285, .003, material('Belt', '4a3322'), 12, 4, matrix=Matrix.Diagonal((1, .86, 1, 1)))
    p.tube((0, 0, .060), (0, 0, .070), .0085, .0085, SKIN, 8)
    p.ellipsoid((0, .001, .096), (.025, .024, .027), SKIN, 12, 8)
    p.ellipsoid((0, .025, .093), (.0058, .0055, .0062), SKIN, 8, 5)
    for s in (-1, 1):
        p.ellipsoid((s * .0092, .0222, .100), (.0032, .002, .004), EYE, 6, 4)
    def cap(v):
        y = v.y
        if y > .15:
            y = .15 + (y - .15) * .25
        return (v.x * 1.06, y * 1.05 - .04, v.z * 1.04 + .02)
    p.ellipsoid((0, -.002, .098), (.025, .024, .027), hair, 12, 8, squash=cap)
    p.build(col, body)
    for i, x in enumerate((-.031, .031)):
        arm = empty(f'Arm{i}', col, (x, 0, .052), body)
        p = Part(f'Arm{i}Mesh')
        p.ellipsoid((0, 0, -.001), (.0105, .010, .010), SHIRT, 8, 5)
        p.tube((0, 0, -.002), (0, 0, -.052), .0092, .0078, SHIRT, 8, round_ends=True)
        p.ellipsoid((0, .001, -.060), (.0080, .0076, .0088), SKIN, 8, 5)
        p.build(col, arm)
    hat = empty('Hat', col, (0, 0, .133), body)
    p = Part('HatMesh')
    # A soft felt hat with a round brim, worn on the crown of the head.
    p.lathe([(.0, -.008), (.034, -.009), (.036, -.006), (.033, -.004), (.022, -.004), (.0, -.003)], hat_mat, 14)
    p.lathe([(.020, -.006), (.0205, .004), (.015, .011), (.0, .013)], hat_mat, 12)
    p.torus((0, 0, -.003), .0205, .0022, material('HatBand', '8a5a3a'), 12, 4)
    p.build(col, hat)
    finish('dweller', col)


# ------------------------------------------------------------------ sheep

def sheep():
    col = new_collection('Sheep')
    root = None
    fleece = [material('Fleece0', 'eee8da'), material('Fleece1', 'e3dccb'), material('Fleece2', 'f6f2e8')]
    head_mat = material('SheepHead', '3e3631')
    muzzle = material('Muzzle', '5b4e46')
    eye = material('SheepEye', '120e0c', .3)
    ear_mat = material('SheepEar', '4a403a')
    leg_mat = material('SheepLeg', '3a322d')
    shin = material('SheepShin', '342d29')
    hoof = material('Hoof', '1f1a17')
    body = empty('Body', col, (0, 0, .070), root)
    p = Part('BodyMesh')
    # A fluffy barrel built from overlapping puffs.
    p.ellipsoid((0, 0, .002), (.045, .062, .046), fleece[0], 16, 10)
    k = 0
    for iy, y in enumerate((-.046, -.022, .002, .026, .046)):
        for ia, a in enumerate(range(-150, 181, 45)):
            ang = math.radians(a + (iy % 2) * 22)
            r = .036 if abs(y) < .04 else .028
            x = math.sin(ang) * r
            z = math.cos(ang) * r * .95 + .006
            if z < -.026:
                continue
            k += 1
            size = .017 + .004 * ((k * 7) % 3) / 2
            p.ellipsoid((x, y, z), (size, size * 1.05, size * .9), fleece[k % 3], 10, 7)
    p.ellipsoid((0, .058, .022), (.022, .014, .020), fleece[2], 10, 7)
    p.build(col, body)
    for i, (x, y) in enumerate(((-.031, .051), (-.031, -.051), (.031, .051), (.031, -.051))):
        leg = empty(f'Leg{i}', col, (x, y, -.020), body)
        p = Part(f'Leg{i}Mesh')
        p.tube((0, 0, .004), (0, 0, -.025), .0098, .0086, leg_mat, 8, round_ends=True)
        p.build(col, leg)
        knee = empty(f'Knee{i}', col, (0, 0, -.024), leg)
        p = Part(f'Knee{i}Mesh')
        p.tube((0, 0, .002), (0, 0, -.019), .0082, .0074, shin, 8, round_ends=True)
        p.ellipsoid((0, .0015, -.0205), (.0088, .0098, .0052), hoof, 8, 5)
        p.build(col, knee)
    neck = empty('Neck', col, (0, .065, .005), body)
    p = Part('NeckMesh')
    # A dark wedge-shaped face with a woolly topknot.
    p.ellipsoid((0, .014, -.004), (.0145, .022, .0155), head_mat, 12, 8,
                squash=lambda v: (v.x * (1 - .25 * max(0, v.y)), v.y, v.z * (1 - .2 * max(0, v.y))))
    p.ellipsoid((0, .033, -.010), (.0098, .0080, .0085), muzzle, 10, 6)
    for s in (-1, 1):
        p.ellipsoid((s * .0105, .020, .003), (.0028, .0032, .0034), eye, 6, 4)
    p.ellipsoid((0, .006, .010), (.014, .012, .010), fleece[2], 10, 6)
    p.ellipsoid((0, -.004, .002), (.016, .014, .016), fleece[1], 10, 6)
    p.build(col, neck)
    for i, s in enumerate((-1, 1)):
        ear = empty(f'Ear{i}', col, (s * .018, .017, .008), neck)
        p = Part(f'Ear{i}Mesh')
        p.ellipsoid((s * .010, 0, -.002), (.011, .0048, .0032), ear_mat, 8, 5, matrix=euler((0, s * -.35, 0)))
        p.build(col, ear)
    tail = empty('Tail', col, (0, -.071, .015), body)
    p = Part('TailMesh')
    p.ellipsoid((0, -.004, -.008), (.0085, .0085, .012), fleece[0], 8, 6)
    p.build(col, tail)
    finish('sheep', col)


# ------------------------------------------------------------------ build all

col = worker('Woodcutter', woodcutter_head, axe)
finish('woodcutter', col)
col = worker('QuarryWorker', quarry_head, pick)
finish('quarry_worker', col)
col = worker('Farmer', farmer_head, rake, belly=1.06)
finish('farmer', col)
outlaw()
dweller()
sheep()
save(SOURCE)
print('ACTORS', report)
