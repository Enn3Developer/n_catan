"""Shared helpers for the Blender Python model builders in tools/.

Import after bpy is loaded. Every builder starts from factory settings, so
materials are looked up by name and reused within one run.
"""
import math

import bpy  # noqa: I001, bmesh only loads after bpy
import bmesh
from mathutils import Vector


def reset(name):
    """Start an empty scene measured in metres."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = name
    scene.unit_settings.system = 'METRIC'
    return scene


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
    bpy.context.scene.collection.children.link(col)
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


def export(col, path):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in col.all_objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format='GLB',
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_extras=True,
        export_lights=True,
    )




def join(name, objects, col, parent=None):
    """Merge parts into one mesh object, so a MultiMesh can draw it."""
    objects = list(objects)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    for obj in objects:
        for modifier in list(obj.modifiers):
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    merged = bpy.context.view_layer.objects.active
    merged.name = name
    merged.data.name = name
    merged.parent = parent
    return merged


def save(path):
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    # Blender keeps the previous save as .blend1; git history already does that job.
    path.with_suffix('.blend1').unlink(missing_ok=True)
