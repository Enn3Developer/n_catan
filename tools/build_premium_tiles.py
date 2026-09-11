"""Build original sculpted miniature scenery in Blender. Run with Blender MCP or --background.
Large, closed forms and a shared matte palette stay legible at board distance.
"""
import bpy, bmesh, math, random, pathlib, json
from mathutils import Vector
from math import sin,cos,pi,sqrt
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/premium';OUT.mkdir(parents=True,exist_ok=True)
scene=bpy.data.scenes.get('Catan_Sculpted_Miniatures') or bpy.data.scenes.new('Catan_Sculpted_Miniatures')
for collection in list(scene.collection.children):
 for obj in list(collection.objects):bpy.data.objects.remove(obj,do_unlink=True)
 bpy.data.collections.remove(collection)
bpy.context.window.scene=scene
PALETTE={'PBR_Bark':'74543c','PBR_Wood':'b39162','PBR_Rock':'83939d','PBR_Clay':'bd7655','ClayLight':'d08b63','ClayDark':'9b5e49','PineNeedles':'426e57','PineTips':'588568','OakLeaves':'749455','OakLight':'8ba766','Grass':'85a766','DryGrass':'b69c63','Wheat':'dab15e','Fern':'659060','Moss':'6b8660','FlowerWhite':'f0e2bd','FlowerGold':'dbaf60','FlowerViolet':'9c91ad','Wool':'e9dfc5','Skin':'5a5146','Iron':'54616b','Ore':'abc1c6','Brick':'ba7555','Roof':'657a85','Plaster':'dfcba3','Sandstone':'d0ac79','Cactus':'739575','Water':'67979b','Dark':'353f40','Rope':'bfa878'}
materials={}
def mat(name):
 if name not in materials:
  m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.diffuse_color=tuple(int(PALETTE[name][i:i+2],16)/255 for i in [0,2,4])+(1,);m.use_nodes=True
  c=m.diffuse_color
  m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in c[:3])+(1,)
  m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.82
  materials[name]=m
 return materials[name]
class Art:
 def __init__(self,kind,seed):self.kind=kind;self.r=random.Random(seed);self.batches={}
 def face(self,pts,material,layer='Landmarks',smooth=False):
  key=(layer,material)
  if key not in self.batches:self.batches[key]=[[],[],[]]
  v,f,n=self.batches[key];start=len(v);v.extend(tuple(p) for p in pts);f.append(tuple(range(start,len(v))));n.append(smooth)
 def tube(self,a,b,r1,r2,material,sides=16,layer='Landmarks'):
  a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)))
  if u.length<.01:u=axis.cross(Vector((1,0,0)))
  u.normalize();v=axis.cross(u)
  lo=[a+(u*cos(i*2*pi/sides)+v*sin(i*2*pi/sides))*r1 for i in range(sides)]
  hi=[b+(u*cos(i*2*pi/sides)+v*sin(i*2*pi/sides))*r2 for i in range(sides)]
  for i in range(sides):j=(i+1)%sides;self.face([lo[i],lo[j],hi[j],hi[i]],material,layer,True)
  self.face(list(reversed(lo)),material,layer);self.face(hi,material,layer)
 def box(self,c,size,material,rot=0,layer='Landmarks',bevel=.008):
  center=Vector(c);half=Vector(size)*.5;r=min(bevel,min(half)*.35);core=half-Vector((r,r,r))
  def point(p):
   p=Vector(p);return center+Vector((p.x*cos(rot)-p.y*sin(rot),p.x*sin(rot)+p.y*cos(rot),p.z))
  def face(points):
   normal=(Vector(points[1])-Vector(points[0])).cross(Vector(points[2])-Vector(points[0]));mid=sum((Vector(p) for p in points),Vector())/len(points)
   if normal.dot(mid)<0:points.reverse()
   self.face([point(p) for p in points],material,layer)
  for axis in range(3):
   u=(axis+1)%3;v=(axis+2)%3
   for side in [-1,1]:
    pts=[]
    for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]:
     p=[0,0,0];p[axis]=side*half[axis];p[u]=a*core[u];p[v]=b*core[v];pts.append(p)
    face(pts)
  for axis in range(3):
   u=(axis+1)%3;v=(axis+2)%3
   for a in [-1,1]:
    for b in [-1,1]:
     pts=[]
     for sign,outer in [(-1,u),(1,u),(1,v),(-1,v)]:
      p=[0,0,0];p[axis]=sign*core[axis];p[u]=a*(half[u] if outer==u else core[u]);p[v]=b*(half[v] if outer==v else core[v]);pts.append(p)
     face(pts)
  for x in [-1,1]:
   for y in [-1,1]:
    for z in [-1,1]:
     signs=[x,y,z];pts=[]
     for axis in range(3):pts.append([signs[j]*(half[j] if j==axis else core[j]) for j in range(3)])
     face(pts)
 def ellipsoid(self,c,scale,material,rings=12,sides=20,rough=0,layer='Landmarks'):
  center=Vector(c);points=[];phase=self.r.random()*pi
  for j in range(rings+1):
   lat=pi*j/rings
   for i in range(sides):
    lon=2*pi*i/sides;d=Vector((sin(lat)*cos(lon),sin(lat)*sin(lon),cos(lat)))
    perturb=1+rough*sin(lon*3+phase)*sin(lat*2)
    points.append(center+Vector((d.x*scale[0],d.y*scale[1],d.z*scale[2]))*perturb)
  for j in range(rings):
   for i in range(sides):
    k=j*sides+i;l=j*sides+(i+1)%sides
    pts=[points[k],points[k+sides],points[l+sides],points[l]]
    if j==0:pts=pts[:3]
    if j==rings-1:pts=[pts[0],pts[1],pts[3]]
    self.face(pts,material,layer,True)
 def ground(self,x,y):
  edge=max(abs(x)/.866,abs(x*.5+y*.866)/.866,abs(-x*.5+y*.866)/.866)
  h=[.045,.07,.04,.018,.10,.065][self.kind];wave=.5+sin(x*6+self.kind)*cos(y*5)*.5
  z=.20+max(0,1-edge)**1.3*h*wave
  if self.kind==5:z+=max(0,1-edge)**1.5*(.018*sin(x*26+y*5)+.035*sin(x*8-y*6))
  return z
 def clear(self,x,y):return max(abs(x)/.866,abs(x*.5+y*.866)/.866,abs(-x*.5+y*.866)/.866)<.79 and not (abs(x)<.29 and y>.28)
 def rock(self,x,y,s,material='PBR_Rock',layer='Landmarks'):
  self.ellipsoid((x,y,self.ground(x,y)+s*.3),(s,s*.76,s*.57),material,10,16,.15,layer)
 def pine(self,x,y,h):
  z=self.ground(x,y);self.tube((x,y,z),(x,y,z+h*.96),.034*h,.011,'PBR_Bark')
  for tier in range(5):
   radius=h*(.28-tier*.044);bottom=z+h*(.22+tier*.14);height=h*.34
   profile=[(0,.72),(.025,.92),(.08,1),(.20,.96),(.43,.75),(.68,.46),(.87,.19),(1,.02)]
   sides=28;points=[]
   for u,r in profile:
    for i in range(sides):
     a=2*pi*i/sides;w=1+.045*sin(a*5+tier);points.append((x+cos(a)*radius*r*w,y+sin(a)*radius*r*w,bottom+u*height+.009*sin(a*5)*(1-u)))
   for j in range(len(profile)-1):
    for i in range(sides):a=j*sides+i;b=j*sides+(i+1)%sides;self.face([points[a],points[b],points[b+sides],points[a+sides]],'PineTips' if tier%3==1 else 'PineNeedles','Foliage',True)
   self.face(list(reversed(points[:sides])),'PineNeedles','Foliage')
   self.face(points[-sides:],'PineNeedles','Foliage')
 def oak(self,x,y,h):
  z=self.ground(x,y);self.tube((x,y,z),(x,y,z+h*.75),.04,.018,'PBR_Bark')
  for i in range(7):
   a=i*2.399;r=h*.21 if i else 0;zz=z+h*(.76 if i else .90)
   center=(x+cos(a)*r,y+sin(a)*r,zz)
   self.tube((x,y,z+h*.48),center,.018,.007,'PBR_Bark')
   self.ellipsoid(center,(h*.23,h*.22,h*.25),'OakLight' if i%3==0 else 'OakLeaves',12,18,.065,'Foliage')
 def grass(self,count,material='Grass',region=None):
  for i in range(count):
   x=self.r.uniform(-.72,.72);y=self.r.uniform(-.72,.72)
   if not self.clear(x,y) or (region and not region(x,y)):continue
   z=self.ground(x,y)
   for j in range(3):
    a=j*2.1+self.r.random();h=self.r.uniform(.025,.058);w=.012;u=Vector((cos(a)*w,sin(a)*w,0));b=Vector((x,y,z));top=b+Vector((sin(a)*.018,cos(a)*.018,h))
    self.face([b-u,b+u,top],material,'GroundCover'+str(i%4))
 def sheep(self,x,y,size=1,angle=0):
  z=self.ground(x,y)
  def p(c):return (x+(c[0]*cos(angle)-c[1]*sin(angle))*size,y+(c[0]*sin(angle)+c[1]*cos(angle))*size,z+c[2]*size)
  for dx in [-.05,.05]:
   for dy in [-.03,.03]:self.tube(p((dx,dy,.008)),p((dx,dy,.075)),.010*size,.009*size,'Skin',12)
  self.ellipsoid(p((0,0,.091)),(.093*size,.059*size,.059*size),'Wool',14,24,.02)
  for i in range(8):
   a=i*2.399;self.ellipsoid(p((cos(a)*.066,sin(a)*.037,.118)),(.032*size,.030*size,.030*size),'Wool',8,12,0,'SmallDetails')
  self.ellipsoid(p((.091,0,.102)),(.035*size,.026*size,.037*size),'Skin')
  self.ellipsoid(p((.083,0,.132)),(.033*size,.026*size,.019*size),'Wool')
  for side in [-1,1]:
   self.ellipsoid(p((.078,side*.033,.121)),(.020*size,.013*size,.006*size),'Skin',8,12)
   self.ellipsoid(p((.113,side*.018,.114)),(.004*size,.003*size,.004*size),'Dark',6,10,0,'SmallDetails')
 def building(self,x,y,w=.26,d=.24,h=.20):
  z=self.ground(x,y);self.box((x,y,z+h*.5),(w,d,h),'Plaster')
  for xx in [-1,1]:
   for yy in [-1,1]:self.box((x+xx*w*.47,y+yy*d*.47,z+h*.5),(.024,.023,h),'PBR_Wood',bevel=.003)
  peak=z+h+.10;eave=z+h-.008
  # Two solid roof slabs: both gables and undersides are closed.
  for side in [-1,1]:
   points=[(x-w*.59,y,peak),(x+w*.59,y,peak),(x+w*.59,y+side*d*.65,eave),(x-w*.59,y+side*d*.65,eave)]
   lower=[(a,b,c-.017) for a,b,c in points]
   self.face(points,'Roof');self.face(lower[::-1],'Roof')
   for i in range(4):j=(i+1)%4;self.face([points[i],lower[i],lower[j],points[j]],'Roof')
   for row in range(1,4):
    yy=y+side*d*.65*row/4;zz=peak-(peak-eave)*row/4+.004
    self.tube((x-w*.6,yy,zz),(x+w*.6,yy,zz),.004,.004,'Roof',8,'SmallDetails')
  for side in [-1,1]:self.face([(x+side*w*.5,y-d*.5,z+h-.001),(x+side*w*.5,y+d*.5,z+h-.001),(x+side*w*.5,y,peak-.015)],'Plaster')
  self.box((x,y+d*.51,z+.06),(.055,.018,.115),'PBR_Wood',bevel=.005)
  for side in [-1,1]:
   self.box((x+side*w*.32,y+d*.53,z+.12),(.038,.018,.042),'Dark',bevel=.004)
   self.box((x+side*w*.32,y+d*.55,z+.117),(.028,.006,.028),'FlowerGold',layer='SmallDetails',bevel=.001)
  self.box((x-w*.23,y-d*.15,z+h+.06),(.038,.045,.15),'Brick',bevel=.004)
 def fence(self,a,b):
  a,b=Vector(a),Vector(b);n=max(2,int((a-b).length/.16))
  for i in range(n+1):
   p=a.lerp(b,i/n);z=self.ground(p.x,p.y);self.box((p.x,p.y,z+.065),(.024,.024,.14),'PBR_Wood',layer='SmallDetails',bevel=.004)
  for h in [.05,.10]:self.tube((a.x,a.y,self.ground(a.x,a.y)+h),(b.x,b.y,self.ground(b.x,b.y)+h),.009,.009,'PBR_Wood',10,'SmallDetails')
 def mountain(self,x,y,h,rx,ry):
  sides=18;profile=[(0,1),(.12,.98),(.34,.77),(.57,.61),(.76,.4),(.91,.20),(1,.015)];pts=[]
  for j,(height,r) in enumerate(profile):
   for i in range(sides):
    a=i*2*pi/sides;wave=1+.16*sin(a*3+.7)+.06*cos(a*5+.4)
    pts.append((x+cos(a)*rx*r*wave+height*.04,y+sin(a)*ry*r*wave-height*.055,.20+height*h+.015*sin(a*3)*sin(height*pi)))
  for j in range(len(profile)-1):
   for i in range(sides):a=j*sides+i;b=j*sides+(i+1)%sides;self.face([pts[a],pts[b],pts[b+sides],pts[a+sides]],'PBR_Rock','Landmarks',True)
  self.face(pts[:sides][::-1],'PBR_Rock');self.face(pts[-sides:],'PBR_Rock')
 def generate(self):
  k=self.kind;shift=self.r.uniform(-.03,.03)
  if k==0:
   for x,y,h in [(-.44,-.34,.70),(-.05,-.45,.85),(.36,-.34,.70),(-.40,.13,.62),(.08,.03,.74),(.48,.16,.50)]:self.pine(x+shift,y,h*self.r.uniform(.93,1.07))
   self.oak(-.42,.42,.43);self.oak(.41,.43,.40);self.grass(210)
   for i in range(3):self.tube((-.32+i*.05,.23,.26),(-.10+i*.05,.23,.26),.026,.026,'PBR_Bark',16,'SmallDetails')
  elif k==1:
   for i in range(3):
    self.ellipsoid((.14,-.18,.24+i*.095),(.43-i*.09,.29-i*.05,.12),'ClayLight' if i%2==0 else 'PBR_Clay',10,24,.055)
   x,y=-.45,-.20;z=self.ground(x,y);self.tube((x,y,z),(x,y,z+.18),.108,.08,'Brick',24)
   self.tube((x,y,z+.17),(x,y,z+.37),.043,.033,'ClayDark',24)
   self.box((x,y+.095,z+.07),(.060,.023,.10),'Dark',bevel=.012)
   for stack in range(3):
    for row in range(3):
     for col in range(3):self.box((-.44+col*.054,.13+stack*.10,.222+row*.031),(.051,.082,.029),'Brick' if (row+col)%2 else 'ClayLight',layer='SmallDetails',bevel=.004)
   self.grass(65,'DryGrass',lambda x,y:x>.35 or y<-.40)
  elif k==2:
   self.grass(320)
   self.fence((-.6,-.36),(-.3,-.57));self.fence((-.3,-.57),(.30,-.54))
   for x,y,a,size in [(-.40,.08,.2,1),(-.12,-.27,2.3,.85),(.30,-.20,1.2,1),(.44,.17,-.2,.9),(-.46,.40,.4,.7)]:self.sheep(x,y,size,a)
   # Raised inset basin avoids coincident water/ground faces.
   self.ellipsoid((.37,.40,self.ground(.37,.4)+.006),(.16,.105,.02),'PBR_Rock',8,24)
   self.ellipsoid((.37,.40,self.ground(.37,.4)+.022),(.142,.087,.006),'Water',8,32)
   for i in range(14):
    x=self.r.uniform(-.6,.6);y=self.r.uniform(-.5,.5)
    if self.clear(x,y):self.ellipsoid((x,y,self.ground(x,y)+.035),(.018,.018,.008),'FlowerWhite' if i%2 else 'FlowerGold',6,10,0,'GroundCover3')
  elif k==3:
   self.building(.44,-.36,.25,.25,.19)
   for row in range(11):
    for col in range(13):
     x=-.60+row*.107;y=-.59+col*.083
     if not self.clear(x,y) or (x>.23 and y<-.17) or abs(y+.01)<.055:continue
     x+=self.r.uniform(-.012,.012);y+=self.r.uniform(-.012,.012);z=self.ground(x,y);h=self.r.uniform(.11,.17)
     self.tube((x,y,z),(x+.015,y,z+h),.004,.003,'Wheat',8,'Foliage')
     for j in range(3):
      for side in [-1,1]:self.ellipsoid((x+.015+side*.008,y,z+h+j*.016),(.012,.008,.017),'Wheat',6,10,0,'Foliage')
   for i in range(2):
    x=-.46+i*.16;y=.42;z=self.ground(x,y)
    self.tube((x,y-.054,z+.063),(x,y+.054,z+.063),.065,.065,'Wheat',24,'SmallDetails')
    self.tube((x,y-.005,z+.063),(x,y+.005,z+.063),.067,.067,'Rope',24,'SmallDetails')
   self.fence((-.64,-.4),(-.64,.15));self.grass(55,'DryGrass',lambda x,y:y>.3)
  elif k==4:
   self.mountain(-.28,-.23,.56,.32,.30);self.mountain(.10,-.29,.84,.33,.30);self.mountain(.43,-.14,.43,.22,.23)
   for x,y,sz in [(-.50,.07,.15),(-.31,.24,.105),(.33,.13,.13),(.53,.33,.075)]:self.rock(x,y,sz)
   x,y=.04,.12;z=self.ground(x,y)
   self.box((x,y,z+.065),(.14,.05,.145),'Dark')
   for side in [-1,1]:self.box((x+side*.078,y+.027,z+.078),(.025,.055,.175),'PBR_Wood',bevel=.004)
   self.box((x,y+.027,z+.16),(.19,.057,.028),'PBR_Wood',bevel=.004)
   for i in range(5):self.box((x,y+.07+i*.057,z+.006),(.16,.02,.018),'PBR_Wood',layer='SmallDetails',bevel=.003)
   for side in [-1,1]:self.tube((x+side*.051,y+.06,z+.021),(x+side*.051,y+.34,z+.021),.005,.005,'Iron',10,'SmallDetails')
   for i in range(8):
    x=self.r.uniform(-.53,.52);y=self.r.uniform(-.5,.4)
    if self.clear(x,y):self.rock(x,y,self.r.uniform(.025,.06),'Ore','SmallDetails')
   self.grass(36,'DryGrass')
  else:
   for x,y,sz in [(-.3,-.3,.23),(.3,-.36,.25),(.47,.08,.13)]:self.rock(x,y,sz,'Sandstone')
   for row in range(3):
    for col in range(4-row):self.box((-.52+col*.09,-.2+row*.025,.233+row*.049),(.083,.10,.045),'Sandstone',bevel=.007)
   for x,y,h in [(-.41,.28,.29),(.4,.29,.22),(.02,-.4,.19)]:
    z=self.ground(x,y);self.tube((x,y,z),(x,y,z+h),.026,.022,'Cactus',20)
    self.ellipsoid((x,y,z+h),(.022,.022,.019),'Cactus',10,16)
    for side in [-1,1]:
     a=(x,y,z+h*.46);b=(x+side*.062,y,z+h*.51);c=(b[0],y,z+h*.8)
     self.tube(a,b,.016,.014,'Cactus',16);self.ellipsoid(b,(.014,.014,.014),'Cactus',8,12);self.tube(b,c,.014,.012,'Cactus',16);self.ellipsoid(c,(.012,.012,.012),'Cactus',8,12)
   self.grass(28,'DryGrass')
 def export(self,name):
  collection=bpy.data.collections.new(name);scene.collection.children.link(collection);objects=[]
  for (layer,material),(verts,faces,smooths) in self.batches.items():
   mesh=bpy.data.meshes.new(name+'_'+layer+'_'+material)
   mesh.from_pydata([(x,-y,z) for x,y,z in verts],[],[tuple(reversed(f)) for f in faces]);mesh.update()
   for face,smooth in zip(mesh.polygons,smooths):face.use_smooth=smooth
   # Weld shared boundaries and recalculate outward normals on closed islands.
   bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
   uv=mesh.uv_layers.new(name='UVMap')
   for loop in mesh.loops:
    p=mesh.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(p.x,p.y+p.z*.5)
   obj=bpy.data.objects.new(layer+'__'+material,mesh);collection.objects.link(obj);mesh.materials.append(mat(material));objects.append(obj)
  bpy.ops.object.select_all(action='DESELECT')
  for obj in objects:obj.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]
  bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_materials='EXPORT',export_yup=True)
  counts={'name':name,'objects':len(objects),'vertices':sum(len(o.data.vertices) for o in objects),'polygons':sum(len(o.data.polygons) for o in objects)}
  for obj in objects:obj.hide_set(True)
  print('SCULPTED_TILE',counts,flush=True);return counts
reports=[]
for kind,name in enumerate(['forest','hills','pasture','fields','mountains','desert']):
 for variant in range(2):
  art=Art(kind,951+kind*193+variant*811);art.generate();reports.append(art.export(name+'_'+str(variant)))
(OUT/'manifest.json').write_text(json.dumps(reports,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/source/sculpted-tiles.blend'))
print('SCULPTED_ASSETS_COMPLETE',flush=True)
