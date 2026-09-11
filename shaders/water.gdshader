shader_type spatial;
// A matte miniature sea: direct sun specular is deliberately excluded.
render_mode cull_disabled, specular_disabled;
uniform vec4 deep_color : source_color=vec4(.055,.235,.285,1.0);
uniform vec4 shallow_color : source_color=vec4(.235,.49,.455,1.0);
uniform float motion_speed=.65;
uniform int water_quality=2;
uniform int tile_count=0;
uniform vec2 tile_centers[30];
uniform float tile_radius=10.0;
uniform int boat_count=0;
uniform vec4 boat_sources[16]; // world X/Z, longitudinal direction X/Z
varying vec2 sea_position;
float hash(vec2 p){
 vec3 p3=fract(vec3(p.xyx)*.1031);
 p3+=dot(p3,p3.yzx+33.33);
 return fract((p3.x+p3.y)*p3.z);
}
float noise(vec2 p){
 vec2 i=floor(p),f=fract(p);
 f=f*f*f*(f*(f*6.0-15.0)+10.0);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
vec2 rotate_domain(vec2 p){return vec2(p.x*.8-p.y*.6,p.x*.6+p.y*.8);}
float painted_noise(vec2 p){
 return .62*noise(rotate_domain(p))+.26*noise(rotate_domain(p*2.07)+17.3)+.12*noise(rotate_domain(p*4.13)-9.1);
}
float shore_distance(vec2 p){
 float d=10000.0;
 for(int i=0;i<30;i++){
  if(i>=tile_count)break;
  vec2 q=p-tile_centers[i];
  float e=max(abs(q.x),max(abs(q.x*.5+q.y*.8660254),abs(-q.x*.5+q.y*.8660254)))-tile_radius*.8660254;
  d=min(d,e);
 }
 return d;
}
void vertex(){
 sea_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
 float t=TIME*motion_speed;
 // Wavelengths exceed even the Low mesh spacing; no undersampled short waves.
 VERTEX.y+=(sin(dot(sea_position,vec2(.014,.010))+t*.19)*.032+
             sin(dot(sea_position,vec2(-.008,.017))-t*.16)*.018)*min(motion_speed,1.0);
}
void fragment(){
 vec2 p=sea_position;
 float t=TIME*motion_speed;
 float shore=max(shore_distance(p),0.0);
 vec2 drift=vec2(t*.045,-t*.032);
 float pigment=painted_noise(p*.085+drift*.4);
 vec2 warp=vec2(pigment,painted_noise(p*.072+11.7-drift*.3))-.5;
 float grain=painted_noise(p*.38+warp*.7+drift);
 float shallow=exp(-shore*.22);
 // Analytic normals are continuous across triangles and independent of mesh UV axes.
 vec2 slope=cos(dot(p,vec2(.19,.13))+t*.37)*vec2(.19,.13)*.12;
 slope+=cos(dot(p,vec2(-.11,.24))-t*.29)*vec2(-.11,.24)*.08;
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 if(water_quality>0){
  float detail=1.0-smoothstep(.4,1.8,footprint);
  slope+=cos(dot(p,vec2(.68,-.41))+grain*.45+t*.51)*vec2(.68,-.41)*.016*detail;
 }
 NORMAL=normalize((VIEW_MATRIX*vec4(-slope.x,1.0,-slope.y,0.0)).xyz);
 float coast_noise=painted_noise(p*.72+drift*.7);
 float wash=shore+(coast_noise-.5)*.40;
 float edge=1.0-smoothstep(.06,.58,wash);
 float lace=smoothstep(.29,.72,coast_noise);
 float foam=edge*(.23+.40*lace);
 if(water_quality>0){
  // Broken little wavelets wash toward shore; no axis-aligned sine caustics.
  float phase=wash*3.2-t*.58+coast_noise*1.8;
  float width=max(fwidth(phase),.08);
  float wavelet=1.0-smoothstep(.12,.12+width,abs(sin(phase)));
  foam+=wavelet*exp(-shore*.60)*smoothstep(.42,.66,grain)*.22;
 }
 float rings=0.0;
 if(water_quality>1){
  for(int i=0;i<16;i++){
   if(i>=boat_count)break;
   vec2 q=p-boat_sources[i].xy;
   if(dot(q,q)>64.0)continue;
   vec2 axis=boat_sources[i].zw;
   float radius=length(vec2(dot(q,vec2(axis.y,-axis.x)),dot(q,axis)*.55));
   float phase=radius*4.2-t*.85+float(i);
   float width=max(fwidth(phase),.32);
   rings+=(1.0-smoothstep(.15,.15+width,abs(sin(phase))))*
           smoothstep(.7,1.4,radius)*(1.0-smoothstep(2.0,4.6,radius))*.045*
           smoothstep(.22,.70,noise(rotate_domain(q*.85)+drift));
  }
 }
 vec3 color=mix(deep_color.rgb,shallow_color.rgb,shallow*.78);
 color*=.90+pigment*.17+grain*.045;
 if(water_quality>1){
  float filigree=1.0-smoothstep(.035,.095,abs(grain-.52));
  color+=vec3(.008,.014,.009)*filigree*shallow*(1.0-smoothstep(.35,1.2,footprint));
 }
 if(water_quality>2){
  float flecks=smoothstep(.69,.80,grain)*(1.0-smoothstep(.4,1.5,footprint));
  foam+=flecks*.065*(1.0-shallow*.5);
 }
 float fresnel=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
 color=mix(color,vec3(.28,.43,.46),fresnel*.10);
 ALBEDO=mix(color,vec3(.66,.77,.70),clamp(foam+rings,0.0,.64));
 ROUGHNESS=.82;
 METALLIC=0.0;
 SPECULAR=0.0;
}
