"""Build the ship piece and the treasure chest with Blender Python.

Run: python3 tools/build_seafaring.py (needs the bpy module or Blender's Python).
It writes assets/source/seafaring.blend and one glTF per model in
assets/models/props/. Blender -Y is the ship's bow, which exports as Godot +Z.
Sizes are in tile units, like the settlement pieces.

Material roles follow docs/development.md: "Owner" (with an optional signed
percentage) takes the player's color at runtime, "PBR_Wood" takes the wood
texture tier, and "NightLantern" glows at night beside its NightLight lamp.
"""
import math
from pathlib import Path

import bpy  # noqa: I001, bmesh only loads after bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/seafaring.blend'
OUT = ROOT / 'assets/models/props'

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = 'Seafaring'
scene.unit_settings.system = 'METRIC'


def srgb_to_linear(v):
    return v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4


def material(name, color, roughness=.85, metallic=0.0):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    srgb = tuple(int(color[i:i + 2], 16) / 255 for i in (0, 2, 4))
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*srgb, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = tuple(srgb_to_linear(v) for v in srgb) + (1,)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    return m


def new_collection(name):
    col = bpy.data.collections.new(name)
    scene.collection.children.link(col)
    return col


def link(obj, col, parent=None):
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    col.objects.link(obj)
    obj.parent = parent
    return obj


def empty(name, col, position=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    col.objects.link(obj)
    obj.parent = parent
    obj.location = position
    return obj


def from_bmesh(name, bm, mats, col, parent, smooth=False, recalc=True):
    data = bpy.data.meshes.new(name)
    # Open shells like the hull keep their authored winding; recalc can turn them inside out.
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    for m in mats:
        data.materials.append(m)
    for poly in data.polygons:
        poly.use_smooth = smooth
    obj = bpy.data.objects.new(name, data)
    col.objects.link(obj)
    obj.parent = parent
    return obj


def mesh(name, vertices, faces, mats, col, parent, indices=None, smooth=False):
    bm = bmesh.new()
    verts = [bm.verts.new(v) for v in vertices]
    for i, face in enumerate(faces):
        f = bm.faces.new([verts[j] for j in face])
        if indices:
            f.material_index = indices[i]
    return from_bmesh(name, bm, mats, col, parent, smooth)


def cylinder(name, start, end, radius, mat, col, parent, segments=8, radius_end=None):
    """A capped tube from start to end, baked into the mesh."""
    radius_end = radius if radius_end is None else radius_end
    a, b = Vector(start), Vector(end)
    axis = (b - a).normalized()
    side = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < .9 else Vector((1, 0, 0))).normalized()
    up = axis.cross(side)
    ring_a, ring_b = [], []
    for i in range(segments):
        t = math.tau * i / segments
        offset = side * math.cos(t) + up * math.sin(t)
        ring_a.append(a + offset * radius)
        ring_b.append(b + offset * radius_end)
    vertices = ring_a + ring_b
    faces = [(i, (i + 1) % segments, segments + (i + 1) % segments, segments + i) for i in range(segments)]
    faces.append(tuple(range(segments - 1, -1, -1)))
    faces.append(tuple(segments + i for i in range(segments)))
    return mesh(name, vertices, faces, [mat], col, parent)


def box(name, center, size, mat, col, parent, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0] + center[0], v.co.y * size[1] + center[1], v.co.z * size[2] + center[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect='EDGES')
    return from_bmesh(name, bm, [mat], col, parent)


def blob(name, center, radius, mat, col, parent, segments=8, rings=5):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radius[0] + center[0], v.co.y * radius[1] + center[1], v.co.z * radius[2] + center[2]))
    return from_bmesh(name, bm, [mat], col, parent, smooth=True)


def lamp(name, position, col, parent, local_range, night_energy):
    data = bpy.data.lights.new(name, 'POINT')
    data.energy = 1.0
    obj = bpy.data.objects.new(name, data)
    col.objects.link(obj)
    obj.parent = parent
    obj.location = position
    obj['local_range'] = local_range
    obj['night_energy'] = night_energy
    return obj


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


def export(col, filename):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in col.all_objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / filename),
        export_format='GLB',
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_extras=True,
        export_lights=True,
    )


OUT.mkdir(parents=True, exist_ok=True)
export(ship_col, 'ship.glb')
export(treasure_col, 'treasure.glb')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
# Blender keeps the previous save as .blend1; git history already does that job.
SOURCE.with_suffix(".blend1").unlink(missing_ok=True)
print('built', OUT / 'ship.glb', OUT / 'treasure.glb', SOURCE)
