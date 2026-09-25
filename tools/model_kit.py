"""Sculpting helpers for the hand-built models: rounded primitives gathered
into one mesh per part, each face tagged with a material and a shading mode.

Import after bpy is loaded (see blender_kit). A Part collects shapes and turns
into a single Blender object; smooth shapes (heads, fleece, sacks) share
normals, hard shapes (planks, stones, blades) keep flat faces with a small
bevel so their edges catch the light.
"""
import math
import random

import bpy  # noqa: F401, bmesh only loads after bpy
import bmesh
from mathutils import Matrix, Vector


class Part:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []
        self.smooth = {}

    def _index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _add(self, bm, mat, smooth, matrix=None):
        """Merge a finished bmesh shape into the part."""
        if matrix is not None:
            bm.transform(matrix)
        index = self._index(mat)
        mesh = bpy.data.meshes.new('tmp')
        bm.to_mesh(mesh)
        bm.free()
        start = len(self.bm.faces)
        self.bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
        self.bm.faces.ensure_lookup_table()
        for face in self.bm.faces[start:]:
            face.material_index = index
            self.smooth[face.index] = smooth
        return self

    # ------------------------------------------------------------ shapes

    def ellipsoid(self, center, radii, mat, segments=12, rings=8, smooth=True, matrix=None, squash=None):
        """A sphere scaled per axis. squash(v) may reshape each unit vertex."""
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
        for v in bm.verts:
            co = v.co.copy()
            if squash:
                co = Vector(squash(co))
            v.co = Vector((co.x * radii[0], co.y * radii[1], co.z * radii[2]))
        m = Matrix.Translation(Vector(center))
        if matrix is not None:
            m = m @ matrix
        return self._add(bm, mat, smooth, m)

    def lathe(self, profile, mat, segments=12, center=(0, 0, 0), smooth=True, matrix=None, scale=(1, 1), cap_bottom=True, cap_top=True, wobble=None):
        """Revolve [(radius, z)] around the local Z axis. Radii of 0 close the ends."""
        bm = bmesh.new()
        rings = []
        for r, z in profile:
            ring = []
            for i in range(segments):
                a = math.tau * i / segments
                rr = r * (wobble(a, z) if wobble else 1)
                ring.append(bm.verts.new((math.cos(a) * rr * scale[0], math.sin(a) * rr * scale[1], z)))
            rings.append(ring)
        for lo, hi in zip(rings, rings[1:]):
            for i in range(segments):
                j = (i + 1) % segments
                bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
        if cap_bottom and profile[0][0] > 0:
            bm.faces.new(list(reversed(rings[0])))
        if cap_top and profile[-1][0] > 0:
            bm.faces.new(rings[-1])
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        m = Matrix.Translation(Vector(center))
        if matrix is not None:
            m = m @ matrix
        return self._add(bm, mat, smooth, m)

    def tube(self, a, b, r1, r2, mat, segments=10, smooth=True, round_ends=False):
        """A tapered rod from a to b; round_ends adds half-sphere caps."""
        a, b = Vector(a), Vector(b)
        length = (b - a).length
        profile = [(r1, 0), (r2, length)]
        if round_ends:
            profile = [(0, -r1)] + [(r1 * math.sin(t), -r1 * math.cos(t)) for t in (math.pi / 5, math.pi / 2.6)] + profile
            profile += [(r2 * math.cos(t), length + r2 * math.sin(t)) for t in (math.pi / 5, math.pi / 2.6)] + [(0, length + r2)]
        return self.lathe(profile, mat, segments, smooth=smooth, matrix=aim(a, b))

    def box(self, center, size, mat, bevel=.0, segments=2, rot=(0, 0, 0), smooth=False, taper=None):
        """A bevelled box. taper=(sx, sy) narrows the top face."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            x, y, z = v.co
            if taper and z > 0:
                x *= taper[0]
                y *= taper[1]
            v.co = Vector((x * size[0], y * size[1], z * size[2]))
        if bevel > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(size) * .45), segments=segments, affect='EDGES', profile=.5)
        m = Matrix.Translation(Vector(center)) @ euler(rot)
        return self._add(bm, mat, smooth, m)

    def prism(self, outline, z0, z1, mat, bevel=0.0, smooth=False, matrix=None):
        """Extrude a closed 2D outline [(x, y)] from z0 to z1."""
        bm = bmesh.new()
        lo = [bm.verts.new((x, y, z0)) for x, y in outline]
        hi = [bm.verts.new((x, y, z1)) for x, y in outline]
        n = len(outline)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
        bm.faces.new(list(reversed(lo)))
        bm.faces.new(hi)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        if bevel > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect='EDGES', profile=.5)
        return self._add(bm, mat, smooth, matrix)

    def torus(self, center, major, minor, mat, segments=16, sides=6, matrix=None, smooth=True):
        profile = []
        bm = bmesh.new()
        rings = []
        for i in range(segments):
            a = math.tau * i / segments
            ring = []
            for j in range(sides):
                b = math.tau * j / sides
                r = major + minor * math.cos(b)
                ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, minor * math.sin(b))))
            rings.append(ring)
        for i in range(segments):
            for j in range(sides):
                a, b = rings[i], rings[(i + 1) % segments]
                bm.faces.new((a[j], b[j], b[(j + 1) % sides], a[(j + 1) % sides]))
        del profile
        m = Matrix.Translation(Vector(center))
        if matrix is not None:
            m = m @ matrix
        return self._add(bm, mat, smooth, m)

    def rock(self, center, radii, mat, seed=0, rough=.22, subdiv=0, smooth=False, matrix=None, flat_base=True):
        """A faceted stone: an icosphere pushed about by a hash, base sliced flat."""
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv + 1, radius=1.0)
        for v in bm.verts:
            n = v.co.normalized()
            h = math.sin(n.x * 5.1 + seed * 1.7) * math.cos(n.y * 4.3 - seed) + math.sin(n.z * 6.7 + seed * .7) * .6
            d = 1 + rough * h * .5
            co = n * d
            if flat_base and co.z < -.35:
                co.z = -.35 - (co.z + .35) * .15
            v.co = Vector((co.x * radii[0], co.y * radii[1], co.z * radii[2]))
        m = Matrix.Translation(Vector(center))
        if matrix is not None:
            m = m @ matrix
        return self._add(bm, mat, smooth, m)

    def crag(self, center, radii, mat, seed=0, cuts=8, rough=.16, terrace=0.0, subdiv=2, top=None, matrix=None):
        """A chiselled boulder: a lumpy sphere with random planes sliced off it.

        Each cut flattens everything past a plane, so the rock gets broad flat
        facets like split stone. terrace bunches heights into ledges (in unit
        sphere terms, before radii), and top shaves a flat summit at that height.
        """
        rng = random.Random(seed)
        waves = [(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized() * rng.uniform(2.5, 5.5),
                  rng.uniform(0, math.tau), rng.uniform(.4, 1)) for _ in range(4)]
        planes = []
        for _ in range(cuts):
            n = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-.35, 1))).normalized()
            planes.append((n, rng.uniform(.5, .84)))
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
        for v in bm.verts:
            n = v.co.normalized()
            h = sum(a * math.sin(n.dot(k) + p) for k, p, a in waves) / 2.5
            co = n * (1 + rough * h)
            for pn, d in planes:
                over = co.dot(pn) - d
                if over > 0:
                    co -= pn * over
            if terrace and co.z > -.3:
                co.z += (round(co.z / terrace) * terrace - co.z) * .6
            if top is not None and co.z > top:
                co.z = top + (co.z - top) * .12
            v.co = Vector((co.x * radii[0], co.y * radii[1], co.z * radii[2]))
        m = Matrix.Translation(Vector(center))
        if matrix is not None:
            m = m @ matrix
        return self._add(bm, mat, False, m)

    def sweep(self, points, radius, mat, sides=6, smooth=True):
        """A rod of constant radius following a polyline: rails, ropes, hoops."""
        points = [Vector(p) for p in points]
        rings = []
        up = Vector((0, 0, 1))
        for i, p in enumerate(points):
            a = points[max(i - 1, 0)]
            b = points[min(i + 1, len(points) - 1)]
            t = (b - a).normalized()
            side = t.cross(up)
            if side.length < 1e-4:
                side = t.cross(Vector((1, 0, 0)))
            side.normalize()
            normal = side.cross(t)
            rings.append([p + (side * math.cos(math.tau * k / sides) + normal * math.sin(math.tau * k / sides)) * radius
                          for k in range(sides)])
        bm = bmesh.new()
        verts = [[bm.verts.new(v) for v in ring] for ring in rings]
        for lo, hi in zip(verts, verts[1:]):
            for k in range(sides):
                j = (k + 1) % sides
                bm.faces.new((lo[k], lo[j], hi[j], hi[k]))
        bm.faces.new(list(reversed(verts[0])))
        bm.faces.new(verts[-1])
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        return self._add(bm, mat, smooth)

    def quad_strip(self, rows, mat, smooth=True, close=False):
        """Faces between consecutive rows of points (each row a list of Vectors)."""
        bm = bmesh.new()
        vrows = [[bm.verts.new(p) for p in row] for row in rows]
        for a, b in zip(vrows, vrows[1:]):
            n = len(a)
            for i in range(n if close else n - 1):
                j = (i + 1) % n
                bm.faces.new((a[i], a[j], b[j], b[i]))
        return self._add(bm, mat, smooth)

    def polygon(self, points, mat, thickness=0.0, smooth=False):
        """A flat face through points; with thickness, a thin slab along its normal."""
        bm = bmesh.new()
        verts = [bm.verts.new(p) for p in points]
        face = bm.faces.new(verts)
        if thickness > 0:
            face.normal_update()
            n = face.normal * thickness
            ext = bmesh.ops.extrude_face_region(bm, geom=[face])
            for v in [e for e in ext['geom'] if isinstance(e, bmesh.types.BMVert)]:
                v.co += n
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        return self._add(bm, mat, smooth)

    # ------------------------------------------------------------ output

    def build(self, col, parent=None, location=(0, 0, 0), name=None, weld=True):
        bm = self.bm
        smooth = [self.smooth.get(i, False) for i in range(len(bm.faces))]
        bm.faces.ensure_lookup_table()
        for face, s in zip(bm.faces, smooth):
            face.smooth = s
        if weld:
            bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
        data = bpy.data.meshes.new(name or self.name)
        bm.to_mesh(data)
        bm.free()
        for m in self.mats:
            data.materials.append(m)
        obj = bpy.data.objects.new(name or self.name, data)
        col.objects.link(obj)
        obj.parent = parent
        obj.location = location
        return obj


def euler(rot):
    return (Matrix.Rotation(rot[2], 4, 'Z') @ Matrix.Rotation(rot[1], 4, 'Y') @ Matrix.Rotation(rot[0], 4, 'X'))


def aim(a, b):
    """A matrix placing local +Z along a→b, origin at a."""
    a, b = Vector(a), Vector(b)
    axis = (b - a).normalized()
    rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
    return Matrix.Translation(a) @ rot


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)
