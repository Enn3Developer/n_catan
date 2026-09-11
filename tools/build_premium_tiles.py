"""Build original sculpted miniature scenery in Blender. Run with Blender MCP or --background.
Large, closed forms and a shared matte palette stay legible at board distance.
"""
import bpy, bmesh, math, random, pathlib, json
from mathutils import Vector
from math import sin,cos,pi,sqrt
ROOT=pathlib.Path(__file__).resolve().parents[1]
LAYOUT=json.loads((ROOT/'assets/world/layout.json').read_text())
OUT=ROOT/'assets/premium';OUT.mkdir(parents=True,exist_ok=True)
scene=bpy.data.scenes.get('Catan_Sculpted_Miniatures') or bpy.data.scenes.new('Catan_Sculpted_Miniatures')
for collection in list(scene.collection.children):
 for obj in list(collection.objects):bpy.data.objects.remove(obj,do_unlink=True)
 bpy.data.collections.remove(collection)
bpy.context.window.scene=scene
PALETTE={'PBR_Bark':'74543c','PBR_Wood':'b39162','PBR_Rock':'83939d','PBR_Clay':'bd7655','ClayLight':'d08b63','ClayDark':'9b5e49','PineNeedles':'426e57','PineTips':'588568','OakLeaves':'749455','OakLight':'8ba766','Grass':'417638','DryGrass':'84603c','Wheat':'dab15e','Fern':'476b3e','Moss':'6b8660','FlowerWhite':'f0e2bd','FlowerGold':'dbaf60','FlowerViolet':'9c91ad','Wool':'e9dfc5','Skin':'5a5146','Iron':'54616b','Ore':'abc1c6','Brick':'ba7555','Roof':'657a85','Plaster':'dfcba3','Sandstone':'d0ac79','Cactus':'739575','Water':'67979b','Dark':'353f40','Rope':'bfa878'}
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
 def __init__(self,kind,seed):
  self.kind=kind;self.r=random.Random(seed);self.batches={};self.layout=LAYOUT['biomes'][kind];self.obstacles=[]
 def occupy(self,x,y,rx,ry=None):self.obstacles.append((x,y,rx,rx if ry is None else ry))
 def path_distance(self,x,y,a,b):
  dx,dy=b[0]-a[0],b[1]-a[1];t=max(0,min(1,((x-a[0])*dx+(y-a[1])*dy)/max(.000001,dx*dx+dy*dy)))
  return math.hypot(x-a[0]-dx*t,y-a[1]-dy*t)
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
 def ellipsoid(self,c,scale,material,rings=12,sides=20,rough=0,layer='Landmarks',smooth=True):
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
    self.face(pts,material,layer,smooth)
 def ground(self,x,y):
  edge=max(abs(x)/.866,abs(x*.5+y*.866)/.866,abs(-x*.5+y*.866)/.866)
  h=[.045,.07,.04,.018,.10,.065][self.kind];wave=.5+sin(x*6+self.kind)*cos(y*5)*.5
  z=.20+max(0,1-edge)**1.3*h*wave
  if self.kind==5:z+=max(0,1-edge)**1.5*(.018*sin(x*26+y*5)+.035*sin(x*8-y*6))
  return z
 def clear(self,x,y,radius=0):
  # Roads and city foundations need real clearance, not just point containment.
  edge=max(abs(x),abs(x*.5+y*.866),abs(-x*.5+y*.866))
  if edge+radius>.866-LAYOUT['edge_margin']:return False
  if any(math.hypot(x-cos(pi/6+i*pi/3),y-sin(pi/6+i*pi/3))<LAYOUT['city_clearance']+radius for i in range(6)):return False
  tx,ty,tr=LAYOUT['token']
  if math.hypot(x-tx,y-ty)<tr+radius:return False
  hut=self.layout['cottage']
  if hut and abs(x-hut[0])<.11*hut[2]+radius+.018 and abs(y-hut[1])<.11*hut[2]+radius+.018:return False
  for wx,wy in self.layout['workers']:
   # Sheep graze within the ground cover; only human work sites need a clearing.
   if self.kind!=2 and abs(x-wx)<.105+radius and wy-.215-radius<y<wy+.075+radius:return False
  for path in self.layout['paths']:
   for a,b in zip(path,path[1:]):
    if self.path_distance(x,y,a,b)<.055+radius:return False
  for ox,oy,rx,ry in self.obstacles:
   if ((x-ox)/(rx+radius))**2+((y-oy)/(ry+radius))**2<1:return False
  return True
 def rock(self,x,y,s,material='PBR_Rock',layer='Landmarks'):
  # Angular outcrops with a buried base, rather than smooth floating eggs.
  z=self.ground(x,y)
  self.ellipsoid((x,y,z+s*.16),(s,s*.74,s*.63),material,6,11,.24,layer,False)
  self.occupy(x,y,s*1.03,s*.80)
 def pine(self,x,y,h):
  z=self.ground(x,y);self.occupy(x,y,h*.24)
  self.tube((x,y,z-.008),(x,y,z+h*.98),.030*h,.004,'PBR_Bark',12)
  # One irregular crown with overlapping, drooping branch tips. No broad shelves.
  for tier in range(4):
   bottom=z+h*(.20+tier*.17);height=h*(.43-tier*.035);radius=h*(.25-tier*.049)
   sides=22;points=[];phase=tier*1.27
   for u,r in [(0,.55),(.12,.92),(.27,1),(.47,.72),(.73,.38),(1,.012)]:
    for i in range(sides):
     a=2*pi*i/sides;lobes=1+.17*sin(a*5+phase)+.08*cos(a*9-phase)
     points.append((x+cos(a)*radius*r*lobes,y+sin(a)*radius*r*lobes,bottom+u*height+.025*h*sin(a*5+phase)*(1-u)))
   for j in range(5):
    for i in range(sides):
     a=j*sides+i;b=j*sides+(i+1)%sides
     self.face([points[a],points[b],points[b+sides],points[a+sides]],'PineTips' if tier==3 else 'PineNeedles','Foliage',True)
   self.face(list(reversed(points[:sides])),'PineNeedles','Foliage')
   self.face(points[-sides:],'PineNeedles','Foliage')
   if tier<2:
    for j in range(5):
     a=j*2*pi/5+phase
     self.tube((x,y,bottom+.06*h),(x+cos(a)*radius*.82,y+sin(a)*radius*.82,bottom+.01*h),.008*h,.003,'PBR_Bark',8)
 def oak(self,x,y,h):
  z=self.ground(x,y);self.occupy(x,y,h*.34)
  self.tube((x,y,z-.005),(x,y,z+h*.73),.025,.012,'PBR_Bark',12)
  for i in range(5):
   a=i*2.399;r=h*.15 if i else 0;zz=z+h*(.73 if i else .88)
   center=(x+cos(a)*r,y+sin(a)*r,zz)
   self.tube((x,y,z+h*.43),center,.012,.004,'PBR_Bark',8)
   self.ellipsoid(center,(h*.22,h*.21,h*.22),'OakLight' if i==0 else 'OakLeaves',8,14,.14,'Foliage')
 def grass(self,count,material='Grass',region=None):
  # Overlapping, unequal growth patches leave irregular gaps instead of filling
  # every available square evenly and outlining every clearance like a stencil.
  patches=[(self.r.uniform(-.65,.65),self.r.uniform(-.65,.65),self.r.uniform(.09,.28),self.r.uniform(.07,.22),self.r.uniform(0,2*pi)) for _ in range(11)]
  for i in range(count*2):
   x=self.r.uniform(-.72,.72);y=self.r.uniform(-.72,.72)
   if not self.clear(x,y,.023) or (region and not region(x,y)):continue
   growth=0
   for px,py,rx,ry,angle in patches:
    dx=x-px;dy=y-py;u=(dx*cos(angle)+dy*sin(angle))/rx;v=(-dx*sin(angle)+dy*cos(angle))/ry
    growth=max(growth,math.exp(-(u*u+v*v)*1.6))
   # Thin unevenly near protected paths and structures; never enter them.
   edge=sum(self.clear(x+dx,y+dy,.023) for dx,dy in [(-.055,0),(.055,0),(0,-.055),(0,.055)])/4
   if self.r.random()>(.16+.84*growth)*(.25+.75*edge):continue
   z=self.ground(x,y)-.003;size=self.r.uniform(.60,1.0);phase=self.r.uniform(0,2*pi)
   for j in range(self.r.randint(4,8)):
    a=phase+j*2.1+self.r.random()
    h=(self.r.uniform(.028,.062) if material=='Grass' else self.r.uniform(.023,.047))*size
    w=(.006 if material=='Grass' else .0048)*size
    u=Vector((cos(a)*w,sin(a)*w,0));b=Vector((x,y,z));mid=b+Vector((sin(a)*.006*size,cos(a)*.006*size,h*.6));top=b+Vector((sin(a)*.018*size,cos(a)*.018*size,h))
    self.face([b-u,b+u,mid+u*.6,mid-u*.6],material,'GroundCover'+str(i%4))
    self.face([mid-u*.6,mid+u*.6,top],material,'GroundCover'+str(i%4))
 def flower(self,x,y,material):
  z=self.ground(x,y);h=self.r.uniform(.018,.028)
  self.tube((x,y,z-.002),(x,y,z+h),.0015,.001,'Grass',6,'GroundCover3')
  for i in range(5):
   a=i*2*pi/5
   self.ellipsoid((x+cos(a)*.005,y+sin(a)*.005,z+h),(.0045,.0045,.002),material,4,7,0,'GroundCover3')
  self.ellipsoid((x,y,z+h+.001),(.0025,.0025,.002),'FlowerGold',4,7,0,'GroundCover3')
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
  a,b=Vector(a),Vector(b);n=max(2,int((a-b).length/.13));points=[a.lerp(b,i/n) for i in range(n+1)]
  for p in points:
   z=self.ground(p.x,p.y);self.box((p.x,p.y,z+.043),(.017,.018,.095),'PBR_Wood',layer='SmallDetails',bevel=.003)
   self.occupy(p.x,p.y,.024)
  for start,end in zip(points,points[1:]):
   for h in [.032,.064]:self.tube((start.x,start.y,self.ground(start.x,start.y)+h),(end.x,end.y,self.ground(end.x,end.y)+h),.0045,.0045,'PBR_Wood',8,'SmallDetails')
 def mountain(self,x,y,h,rx,ry):
  self.occupy(x,y,rx*1.05,ry*1.08)
  sides=17;profile=[(0,1),(.12,.97),(.28,.82),(.46,.63),(.62,.52),(.80,.30),(1,.008)];pts=[]
  for j,(height,r) in enumerate(profile):
   for i in range(sides):
    a=i*2*pi/sides;wave=1+.13*sin(a*3+.7)+.09*cos(a*5+j*.22)
    xx=x+cos(a)*rx*r*wave+height*.045;yy=y+sin(a)*ry*r*wave-height*.025
    zz=self.ground(xx,yy)-.018+height*h+.026*sin(a*3+.5)*sin(height*pi)
    pts.append((xx,yy,zz))
  for j in range(len(profile)-1):
   for i in range(sides):
    a=j*sides+i;b=j*sides+(i+1)%sides
    self.face([pts[a],pts[b],pts[b+sides],pts[a+sides]],'PBR_Rock','Landmarks',False)
  self.face(pts[:sides][::-1],'PBR_Rock');self.face(pts[-sides:],'PBR_Rock')
 def generate(self):
  k=self.kind
  if k==0:
   for x,y,h in self.layout['trees']:self.pine(x,y,h*self.r.uniform(.96,1.04))
   for x,y,h in self.layout['oaks']:self.oak(x,y,h)
   # A small grounded stack beside the clearing, away from the axe arcs.
   for i in range(3):
    x=-.46+i*.031;y=.10;z=self.ground(x,y)
    self.tube((x,y-.047,z+.015),(x,y+.047,z+.015),.014,.014,'PBR_Bark',12,'SmallDetails')
    self.tube((x,y+.047,z+.015),(x,y+.049,z+.015),.011,.011,'PBR_Wood',12,'SmallDetails')
   self.occupy(-.43,.10,.064,.07);self.grass(1250)
  elif k==1:
   for x,y,sz in [(-.25,-.37,.21),(.035,-.35,.24),(.19,-.24,.11)]:self.rock(x,y,sz,'PBR_Clay')
   x,y=-.48,-.11;z=self.ground(x,y);self.occupy(x,y,.105)
   self.tube((x,y,z-.008),(x,y,z+.14),.078,.066,'Brick',24)
   self.tube((x,y,z+.14),(x,y,z+.245),.033,.026,'ClayDark',16)
   self.tube((x,y,z+.245),(x,y,z+.248),.021,.021,'Dark',16)
   self.box((x,y+.071,z+.046),(.043,.012,.076),'Dark',bevel=.005)
   # Thin masonry courses give the kiln a readable surface at close range.
   for row in range(4):
    for col in range(12):
     a=(col+(row%2)*.5)*2*pi/12;r=.076-row*.002
     self.box((x+cos(a)*r,y+sin(a)*r,z+.018+row*.029),(.030,.008,.021),'ClayLight' if (row+col)%4==0 else 'Brick',rot=a+pi/2,layer='SmallDetails',bevel=.002)
   for row in range(3):
    for col in range(3):self.box((-.18+col*.042,-.03,self.ground(-.14,-.03)+.012+row*.024),(.038,.064,.022),'Brick',layer='SmallDetails',bevel=.002)
   self.occupy(-.14,-.03,.075,.045);self.grass(320,'DryGrass')
  elif k==2:
   self.fence((-.44,-.48),(.40,-.48))
   self.fence((-.44,-.48),(-.52,-.21))
   # A shallow, rimmed trough sits on the terrain; no raised floating water disk.
   x,y=.36,.40;z=self.ground(x,y)
   self.box((x,y,z+.018),(.15,.094,.045),'PBR_Rock',bevel=.009)
   self.box((x,y,z+.042),(.118,.064,.005),'Dark',bevel=.006)
   self.box((x,y,z+.045),(.107,.055,.004),'Water',layer='SmallDetails',bevel=.004)
   self.occupy(x,y,.105,.075);self.grass(1800)
   for i in range(48):
    x=self.r.uniform(-.64,.64);y=self.r.uniform(-.53,.50)
    if self.clear(x,y,.012):self.flower(x,y,'FlowerWhite' if i%3 else 'FlowerViolet')
  elif k==3:
   for x in [-.43,-.325]:self.occupy(x,.37,.048)
   # Shorter stalks, slender grain heads and deliberate lanes around workers.
   for row in range(15):
    for col in range(15):
     x=-.61+row*.087+self.r.uniform(-.009,.009);y=-.58+col*.078+self.r.uniform(-.008,.008)
     if not self.clear(x,y,.018):continue
     for stalk in range(2):
      sx=x+(-.010 if stalk==0 else .010);sy=y+self.r.uniform(-.009,.009)
      z=self.ground(sx,sy);h=self.r.uniform(.075,.105);lean=self.r.uniform(-.010,.010)
      self.tube((sx,sy,z-.002),(sx+lean,sy,z+h+.036),.0022,.0009,'Wheat',6,'Foliage')
      for j in range(4):
       for side in [-1,1]:
        xx=sx+lean+side*.0045;zz=z+h+j*.008
        self.ellipsoid((xx,sy,zz),(.0047,.0035,.008),'Wheat',5,7,0,'Foliage')
        self.tube((xx,sy,zz+.004),(xx+side*.006,sy,zz+.020),.0006,.0002,'Wheat',5,'Micro')
   for i in range(2):
    x=-.43+i*.105;y=.37;z=self.ground(x,y)
    self.tube((x,y-.033,z+.035),(x,y+.033,z+.035),.035,.035,'Wheat',16,'SmallDetails')
    self.tube((x,y-.003,z+.035),(x,y+.003,z+.035),.036,.036,'Rope',16,'SmallDetails')
    self.occupy(x,y,.043)
   self.fence((-.56,-.20),(-.56,.11));self.grass(200,'DryGrass',lambda x,y:y>.30)
  elif k==4:
   self.mountain(-.29,-.28,.39,.18,.18);self.mountain(.015,-.32,.62,.23,.19);self.mountain(.30,-.24,.37,.17,.17)
   x,y=.03,.015;z=self.ground(x,y)
   self.occupy(x,y-.05,.12,.16)
   self.box((x,y-.075,z+.092),(.205,.19,.19),'PBR_Rock',bevel=.014)
   self.box((x,y,z+.069),(.138,.07,.15),'Dark',bevel=.009)
   for side in [-1,1]:self.box((x+side*.081,y+.043,z+.082),(.027,.050,.172),'PBR_Wood',bevel=.003)
   self.box((x,y+.043,z+.172),(.19,.051,.028),'PBR_Wood',bevel=.003)
   # Rails follow the slope and stop before the token; sleepers are fully seated.
   for i in range(3):
    yy=y+.09+i*.025;zz=self.ground(x,yy)
    self.box((x,yy,zz+.005),(.14,.018,.018),'PBR_Wood',layer='SmallDetails',bevel=.002)
   for side in [-1,1]:
    for i in range(2):
     yy=y+.09+i*.025;self.tube((x+side*.045,yy,self.ground(x,yy)+.018),(x+side*.045,yy+.025,self.ground(x,yy+.025)+.018),.0035,.0035,'Iron',8,'SmallDetails')
   self.occupy(x,.13,.085,.05)
   for i in range(30):
    xx=self.r.uniform(-.59,.59);yy=self.r.uniform(-.5,.45);sz=self.r.uniform(.018,.038)
    if self.clear(xx,yy,sz):self.rock(xx,yy,sz,'Ore','SmallDetails')
   self.grass(260,'DryGrass')
  else:
   for x,y,sz in [(-.32,-.34,.15),(.23,-.38,.18),(.49,-.01,.10)]:self.rock(x,y,sz,'Sandstone')
   for row in range(3):
    for col in range(4-row):
     x=-.52+col*.061;y=-.06+row*.012;z=self.ground(x,y)
     self.box((x,y,z+.018+row*.037),(.055,.075,.034),'Sandstone',bevel=.005)
   self.occupy(-.43,-.03,.15,.075)
   for x,y,h in [(-.43,.25,.23),(.43,.28,.18),(-.03,-.39,.16)]:
    z=self.ground(x,y);self.occupy(x,y,.082)
    self.tube((x,y,z-.004),(x,y,z+h),.019,.016,'Cactus',14)
    self.ellipsoid((x,y,z+h),(.016,.016,.014),'Cactus',7,12)
    for side in [-1,1]:
     a=(x,y,z+h*.46);b=(x+side*.044,y,z+h*.51);c=(b[0],y,z+h*.8)
     self.tube(a,b,.012,.010,'Cactus',12);self.ellipsoid(b,(.010,.010,.010),'Cactus',6,10);self.tube(b,c,.010,.008,'Cactus',12);self.ellipsoid(c,(.008,.008,.009),'Cactus',6,10)
   self.grass(100,'DryGrass')
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
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/source/sculpted-tiles.blend'))
print('SCULPTED_ASSETS_COMPLETE',flush=True)
