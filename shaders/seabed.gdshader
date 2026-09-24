shader_type spatial;
// The sea floor seen through the water: sand near the coast, weed and rock on
// the reef, dark silt in deep water, with sunlight caustics that fade with depth.
#include "res://shaders/sea_floor.gdshaderinc"
uniform float animation_time=0.0;
uniform float sun_strength=1.0;
uniform vec4 sand_color : source_color=vec4(.66,.63,.52,1.0);
uniform vec4 reef_color : source_color=vec4(.38,.45,.34,1.0);
uniform vec4 deep_color : source_color=vec4(.16,.22,.25,1.0);
varying vec2 bed_position;
varying float bed_depth;

float hash(vec2 p){
 vec3 p3=fract(vec3(p.xyx)*.1031);
 p3+=dot(p3,p3.yzx+33.33);
 return fract((p3.x+p3.y)*p3.z);
}
float noise(vec2 p){
 vec2 i=floor(p),f=fract(p);
 f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
float height(vec2 p){
 float shore=shore_distance(p);
 // Dunes on the shelf, lumpier rock further out.
 float rough=noise(p*.08)*1.6+noise(p*.23)*.6;
 return -(seabed_depth(shore)+rough*smoothstep(-2.0,10.0,shore));
}
// Bright lines where wavy light converges. A few rounds of swirling feed a
// point back into itself; where the swirl folds, light gathers into a web.
float caustics(vec2 uv,float time){
 vec2 p=mod(uv*6.2831853,6.2831853)-250.0;
 vec2 i=p;
 float c=1.0;
 for(int n=0;n<4;n++){
  float t=time*(1.0-3.5/float(n+1));
  i=p+vec2(cos(t-i.x)+sin(t+i.y),sin(t-i.y)+cos(t+i.x));
  c+=1.0/length(vec2(p.x/(sin(i.x+t)/.005),p.y/(cos(i.y+t)/.005)));
 }
 c=1.17-pow(c/4.0,1.4);
 return pow(abs(c),8.0);
}
void vertex(){
 bed_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
 float h=height(bed_position);
 float e=2.5;
 vec3 dx=vec3(2.0*e,height(bed_position+vec2(e,0))-height(bed_position-vec2(e,0)),0.0);
 vec3 dz=vec3(0.0,height(bed_position+vec2(0,e))-height(bed_position-vec2(0,e)),2.0*e);
 VERTEX.y=h;
 bed_depth=-h;
 NORMAL=normalize(cross(dz,dx));
}
void fragment(){
 vec2 p=bed_position;
 float grain=noise(p*.9)*.5+noise(p*3.1)*.5;
 float patches=smoothstep(.45,.7,noise(p*.05+3.1));
 vec3 color=mix(sand_color.rgb,reef_color.rgb,smoothstep(5.0,12.0,bed_depth)*(.55+.45*patches));
 color=mix(color,deep_color.rgb,smoothstep(14.0,34.0,bed_depth));
 color*=.86+grain*.24;
 // Ripple marks in shallow sand.
 float ripples=sin(dot(p,vec2(.9,.4))*1.7+noise(p*.2)*6.0);
 color*=1.0-.07*ripples*(1.0-smoothstep(4.0,9.0,bed_depth));
 ALBEDO=color;
 ROUGHNESS=.95;
 SPECULAR=.1;
 // One pattern tile spans 14 metres; the web softens and fades with depth.
 float light=smoothstep(.12,.75,caustics(p/14.0,animation_time*.35+23.0));
 EMISSION=vec3(.8,.93,.86)*light*sun_strength*1.5*exp(-bed_depth*.14);
}
