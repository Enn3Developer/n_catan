"""Build the original hinged, low-poly gull through Blender MCP or Blender Python.

+Y is forward in Blender; exported glTF faces Godot -Z. Origins at the shoulders,
wrists and neck allow the game to animate this small model without a skeleton.
The new scene is isolated from any scene already open in Blender.
"""
import bpy
import bmesh
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SCENE_NAME = 'Catan_Seagull'
if bpy.data.scenes.get(SCENE_NAME):
    raise RuntimeError('Catan_Seagull already exists. Inspect it before rebuilding.')
scene = bpy.data.scenes.new(SCENE_NAME)
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'
collection = bpy.data.collections.new('Seagull_Model')
scene.collection.children.link(collection)


def material(name, color):
    srgb = tuple(int(color[i:i + 2], 16) / 255 for i in (0, 2, 4))
    m = bpy.data.materials.new('Gull_' + name)
    m.diffuse_color = (*srgb, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = tuple(v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb) + (1,)
    bsdf.inputs['Roughness'].default_value = .88
    return m


white = material('Ivory', 'eeeadd')
grey = material('Mantle', '93a6ad')
dark = material('Primaries', '303c43')
gold = material('Beak', 'd8a54d')
feet_mat = material('Feet', 'bd9164')
eye_mat = material('Eyes', '202b30')


def empty(name, position=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.parent = parent
    obj.location = position
    return obj


root = empty('Seagull')


def ellipsoid(name, position, scale, mat, parent=root, segments=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings)
    obj = bpy.context.object
    obj.name = name
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)
    # Bake dimensions into the mesh; hinge transforms remain clean on export.
    for vertex in obj.data.vertices:
        vertex.co = Vector((vertex.co.x * scale[0], vertex.co.y * scale[1], vertex.co.z * scale[2]))
    obj.parent = parent
    obj.location = position
    obj.data.materials.append(mat)
    return obj


def mesh(name, vertices, faces, mats, indices=None, parent=root):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    for mat in mats:
        data.materials.append(mat)
    if indices:
        for face, index in zip(data.polygons, indices):
            face.material_index = index
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    obj.parent = parent
    return obj


ellipsoid('Body', (0, -.025, .155), (.092, .195, .082), white)
ellipsoid('Mantle', (0, -.045, .218), (.080, .157, .027), grey)
ellipsoid('Neck', (0, .115, .186), (.062, .085, .080), white)
head = empty('Head', (0, .183, .229), root)
ellipsoid('Crown', (0, .016, .009), (.067, .080, .064), white, head)
# Closed wedge with a slight hook at the tip.
mesh('Beak', [(-.022,.076,.018),(.022,.076,.018),(-.018,.076,-.012),(.018,.076,-.012),(-.010,.163,.004),(.010,.163,.004),(0,.165,-.010)],
     [(0,1,5,4),(2,6,3),(0,4,6,2),(1,3,6,5),(4,5,6),(0,2,3,1)], [gold], parent=head)
for side in (-1, 1):
    ellipsoid('EyeLeft' if side < 0 else 'EyeRight', (side*.061,.039,.022), (.009,.011,.011), eye_mat, head, 8, 6)
# Separate tail feathers keep the fan readable from the board camera.
for i in range(5):
    x = (i-2)*.023
    mesh('TailFeather%d' % i,
         [(x-.020,-.165,.137),(x+.020,-.165,.137),(x+.023,-.335-abs(i-2)*.004,.123),(x-.023,-.335-abs(i-2)*.004,.123),(x,-.232,.150)],
         [(0,1,4),(1,2,4),(2,3,4),(3,0,4),(0,3,2,1)], [white])


def wing(name, stations, parent, side):
    vertices, faces, indices = [], [], []
    for x, y, z, chord in stations:
        vertices.extend([(side*x,y+chord*.5,z),(side*x,y,z+.015),(side*x,y-chord*.5,z),(side*x,y,z-.012)])
    for row in range(len(stations)-1):
        for j in range(4):
            faces.append((row*4+j,row*4+(j+1)%4,(row+1)*4+(j+1)%4,(row+1)*4+j))
            indices.append(0 if j < 2 else 1)
    faces.extend([(3,2,1,0),tuple(range((len(stations)-1)*4,len(stations)*4))])
    indices.extend([0,0])
    return mesh(name, vertices, faces, [grey,white], indices, parent)


for side, label in [(-1,'Left'),(1,'Right')]:
    hinge = empty('Wing'+label, (side*.066,.025,.204), root)
    wing('UpperWing'+label, [(0,0,0,.16),(.115,.035,.024,.19),(.26,.014,.017,.16)], hinge, side)
    wrist = empty('Wrist'+label, (side*.26,.014,.017), hinge)
    wing('Forewing'+label, [(0,0,0,.16),(.145,-.049,-.013,.155),(.29,-.115,-.022,.085)], wrist, side)
    # Long, pointed black primary feathers with ivory mirrors near their tips.
    for i in range(4):
        start_x=.17-i*.014
        tip_x=.365-i*.028
        y=-.046-i*.044
        mesh('Primary%s%d' % (label,i),
             [(side*start_x,y+.028,-.006),(side*(start_x+.008),y-.030,-.009),(side*tip_x,y-.087,-.023),(side*(tip_x+.011),y-.061,-.017),(side*(start_x+.085),y-.018,.002)],
             [(0,1,4),(1,2,4),(2,3,4),(3,0,4),(0,3,2,1)], [dark], parent=wrist)
        if i<3:
            mesh('WingMirror%s%d' % (label,i),
                 [(side*(tip_x-.043),y-.050,-.010),(side*(tip_x-.019),y-.063,-.012),(side*(tip_x-.009),y-.052,-.009)],
                 [(0,1,2) if side>0 else (2,1,0)], [white], parent=wrist)
feet = empty('Feet', parent=root)
for side in (-1,1):
    ellipsoid('Leg', (side*.034,-.010,.069), (.010,.011,.044), feet_mat, feet, 8, 6)
    mesh('WebbedFoot', [(side*.034-.021,.039,.008),(side*.034+.021,.039,.008),(side*.034,-.031,.008),(side*.034,.003,.024)],
         [(0,1,2),(0,3,1),(1,3,2),(2,3,0)], [feet_mat], parent=feet)

# Batch static pieces under each hinge to keep runtime draw calls small.
for parent in [root, head, feet] + [o for o in collection.objects if o.name.startswith(('WingLeft','WingRight','WristLeft','WristRight')) and o.type == 'EMPTY']:
    parts = [o for o in parent.children if o.type == 'MESH']
    if len(parts) > 1:
        bpy.ops.object.select_all(action='DESELECT')
        for obj in parts:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        bpy.context.object.name = parent.name + 'Mesh'

# A compact resting shape keeps the folded feathers against the body.
# Shoulder/wrist hinges still provide the flapping motion in flight.
bpy.context.view_layer.update()
for obj in collection.objects:
    if obj.type != 'MESH' or obj.parent.name not in ('WingLeft','WingRight','WristLeft','WristRight'):
        continue
    obj.shape_key_add(name='Basis')
    folded = obj.shape_key_add(name='Folded')
    inverse = obj.matrix_world.inverted()
    for source, target in zip(obj.data.vertices, folded.data):
        p = obj.matrix_world @ source.co
        side = -1 if p.x < 0 else 1
        u = max(0, min(1, (abs(p.x)-.066)/.64))
        chord = p.y - (.025+.06*u-.24*u*u)
        target.co = inverse @ Vector((side*(.085+math.sin(math.pi*u)*.025+(p.z-.21)*.3), .075-u*.34, .16+chord*.52-.015*u))

# Export the model only. The studio belongs to the editable source scene.
bpy.ops.object.select_all(action='DESELECT')
for obj in collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
out = ROOT / 'assets/premium/seagull.glb'
bpy.ops.export_scene.gltf(filepath=str(out), export_format='GLB', use_selection=True, use_active_scene=True, export_yup=True, export_materials='EXPORT')

studio = bpy.data.collections.new('Seagull_Studio')
scene.collection.children.link(studio)
camera_data = bpy.data.cameras.new('Seagull_PreviewCamera')
camera = bpy.data.objects.new('Seagull_PreviewCamera', camera_data)
studio.objects.link(camera)
camera.location = (1.1,1.6,1.45)
camera.rotation_euler = (Vector((0,0,.16))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 1.64
scene.camera = camera
for name, pos, energy, size in [('Key',(1,2,4),280,4),('Fill',(-2,-1,2),140,3)]:
    data = bpy.data.lights.new('Seagull_'+name,'AREA')
    data.energy = energy
    data.shape = 'DISK'
    data.size = size
    obj = bpy.data.objects.new(data.name,data)
    studio.objects.link(obj)
    obj.location = pos
    obj.rotation_euler = (Vector((0,0,.1))-obj.location).to_track_quat('-Z','Y').to_euler()
scene.world = bpy.data.worlds.new('Seagull_StudioWorld')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.075,.105,.12,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .7
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 1000
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = '/tmp/catan-seagull-model.png'
scene.view_settings.view_transform = 'AgX'
bpy.context.view_layer.update()
# Save just this new scene and its dependencies; preserve the user's open file.
bpy.data.libraries.write(str(ROOT/'assets/source/seagull.blend'), {scene})
result = {'file':str(out),'source':str(ROOT/'assets/source/seagull.blend'),'meshes':sum(o.type=='MESH' for o in collection.objects),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in collection.objects if o.type=='MESH'),'hinges':['WingLeft','WingRight','WristLeft','WristRight','Head','Feet']}
