shader_type spatial;
// Gerstner swells plus independently moving, filtered capillary ripples.
// The surface is see-through: light fades with the path it travels in the
// water, so the sea bed shows in the shallows and deep water turns dark blue.
render_mode cull_disabled,depth_draw_always;
#include "res://shaders/sea_floor.gdshaderinc"
uniform sampler2D depth_texture : hint_depth_texture,filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture,filter_linear_mipmap;
// Fraction of red, green and blue light the water absorbs per metre.
uniform vec3 absorption=vec3(.22,.07,.032);
uniform float clarity=1.0;
uniform float sun_strength=1.0;
uniform vec3 sun_direction=vec3(0,1,0);
uniform float animation_time=0.0;
uniform vec4 waves[4];
uniform float storm_strength=0.0;
uniform float rain_strength=0.0;
uniform vec4 deep_color : source_color=vec4(.055,.235,.285,1.0);
uniform vec4 shallow_color : source_color=vec4(.235,.49,.455,1.0);
uniform float motion_speed=.65;
uniform int water_quality=2;
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
vec2 noise_gradient(vec2 p){
 vec2 i=floor(p),f=fract(p);
 vec2 u=f*f*f*(f*(f*6.0-15.0)+10.0);
 vec2 du=30.0*f*f*(f-1.0)*(f-1.0);
 float a=hash(i),b=hash(i+vec2(1,0)),c=hash(i+vec2(0,1)),d=hash(i+vec2(1));
 return du*(vec2(b-a,c-a)+(a-b-c+d)*u.yx);
}
vec2 rotate_domain(vec2 p){return vec2(p.x*.8-p.y*.6,p.x*.6+p.y*.8);}
float painted_noise(vec2 p){
 return .62*noise(rotate_domain(p))+.26*noise(rotate_domain(p*2.07)+17.3)+.12*noise(rotate_domain(p*4.13)-9.1);
}
// World position of whatever the depth buffer holds at a screen point.
vec3 scene_point(vec2 uv,mat4 inv_projection,mat4 inv_view){
 float depth=texture(depth_texture,uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc=vec3(uv,depth)*2.0-1.0;
#else
 vec3 ndc=vec3(uv*2.0-1.0,depth);
#endif
 vec4 view=inv_projection*vec4(ndc,1.0);
 return (inv_view*vec4(view.xyz/view.w,1.0)).xyz;
}
// Concentrate the existing mesh around the island; stretch only the distant ocean.
vec2 ocean_grid(vec2 p){
 vec2 u=p/3500.0;
 return u*450.0+sign(u)*pow(max((abs(u)-.8)/.2,vec2(0.0)),vec2(2.0))*3050.0;
}
vec3 swell(vec2 p,float t,inout vec3 tangent,inout vec3 binormal){
 vec3 offset=vec3(0.0);
 float shore=smoothstep(2.0,22.0,shore_distance(p));
 float spacing=900.0/(water_quality==0?65.0:(water_quality==1?129.0:(water_quality==2?225.0:321.0)));
 float distant=1.0-smoothstep(350.0,650.0,max(abs(p.x),abs(p.y)));
 for(int i=0;i<4;i++){
  vec2 d=normalize(waves[i].xy);
  float k=6.2831853/waves[i].w;
  float f=k*dot(d,p)-sqrt(9.81*k)*t;
  float a=waves[i].z*(1.0+storm_strength*1.8)*shore*distant*smoothstep(spacing*2.0,spacing*5.0,waves[i].w);
  float c=cos(f),s=sin(f);
  offset+=vec3(d.x*c*.7,s,d.y*c*.7)*a;
  tangent+=vec3(-d.x*d.x*k*a*s*.7,d.x*k*a*c,-d.x*d.y*k*a*s*.7);
  binormal+=vec3(-d.x*d.y*k*a*s*.7,d.y*k*a*c,-d.y*d.y*k*a*s*.7);
 }
 return offset;
}
void vertex(){
 VERTEX.xz=ocean_grid(VERTEX.xz);
 sea_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
 vec3 tangent=vec3(1,0,0),binormal=vec3(0,0,1);
 VERTEX+=swell(sea_position,animation_time*motion_speed,tangent,binormal);
 NORMAL=normalize(cross(binormal,tangent));
}
void fragment(){
 vec2 p=sea_position;
 float t=animation_time*motion_speed;
 float shore=max(shore_distance(p),0.0);
 vec2 drift=vec2(t*.045,-t*.032);
 float pigment=painted_noise(p*.085+drift*.4);
 vec2 warp=vec2(pigment,painted_noise(p*.072+11.7-drift*.3))-.5;
 float grain=painted_noise(p*.38+warp*.7+drift);
 float shallow=exp(-shore*.22);
 vec3 tangent=vec3(1,0,0),binormal=vec3(0,0,1);
 vec3 displacement=swell(p,t,tangent,binormal);
 vec3 wave_normal=normalize(cross(binormal,tangent));
 vec2 slope=-wave_normal.xz/wave_normal.y;
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 // Short waves affect reflection, not geometry. Filter them out before they alias.
 float detail=1.0-smoothstep(.5,2.5,footprint);
 vec2 ripple_p=rotate_domain(p)*1.2+vec2(-t*.7,t*.23);
 vec2 micro=noise_gradient(ripple_p)*.10;
 micro+=noise_gradient(ripple_p*2.13+vec2(t*.31,-t*.48)+9.7)*.047;
 if(water_quality>0){
  micro+=noise_gradient(ripple_p*4.17+vec2(-t*.62,-t*.13)-7.3)*.024*(1.0-smoothstep(.2,.9,footprint));
 }
 slope+=vec2(micro.x*.8+micro.y*.6,-micro.x*.6+micro.y*.8)*detail*(1.0+storm_strength*.5);
 if(water_quality>0 && rain_strength>.01){
  vec2 cell=floor(p*.65);
  vec2 local=fract(p*.65)-vec2(hash(cell),hash(cell+19.3));
  float age=fract(t*1.1+hash(cell+3.7));
  float radius=length(local);
  float ripple=sin((radius-age*.6)*42.0)*exp(-abs(radius-age*.6)*18.0)*(1.0-age);
  slope+=normalize(local+vec2(.0001))*ripple*.04*rain_strength*(1.0-smoothstep(.6,2.0,footprint));
 }
 NORMAL=normalize((VIEW_MATRIX*vec4(-slope.x,1.0,-slope.y,0.0)).xyz);
 // How far light travels underwater before reaching what lies below. Waves
 // bend the view a little; a bent sample that lands above the water is dropped.
 vec3 surface=(INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
 vec2 bend=slope*.035*clamp(-VERTEX.z*.004,.2,1.0);
 vec2 uv=SCREEN_UV+bend;
 vec3 below=scene_point(uv,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
 if(below.y>surface.y-.05){uv=SCREEN_UV;below=scene_point(uv,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);}
 float drop=max(surface.y-below.y,0.0);
 float coast_noise=painted_noise(p*.72+drift*.7);
 // Beaches reach about 3 metres out from the cliffs before they meet the sea.
 float wash=shore-3.0+(coast_noise-.5)*.40;
 // Foam gathers wherever the water is shallow over something: beaches,
 // boulders, piers and hulls alike.
 float edge=1.0-smoothstep(.04,.75,drop+(coast_noise-.5)*.3);
 float lace=smoothstep(.29,.72,coast_noise);
 float foam=edge*(.23+.40*lace);
 if(water_quality>0){
  // Broken little wavelets wash toward shore; no axis-aligned sine caustics.
  float phase=wash*3.2-t*.58+coast_noise*1.8;
  float width=max(fwidth(phase),.08);
  float wavelet=1.0-smoothstep(.12,.12+width,abs(sin(phase)));
  foam+=wavelet*exp(-max(wash,0.0)*.60)*smoothstep(.42,.66,grain)*.22;
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
 // The bed now shows the shallows, so the painted tint stays light.
 vec3 color=mix(deep_color.rgb,shallow_color.rgb,shallow*.35);
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
 float path=clamp(length(below-surface),0.0,400.0);
 // Mostly the vertical depth, so a grazing view does not fog the shallows.
 float optical=mix(drop,path,.35)/clarity;
 vec3 transmit=exp(-absorption*optical)*(1.0-smoothstep(12.0,40.0,optical));
 float opacity=1.0-dot(transmit,vec3(.3,.4,.3));
 float cover=clamp(foam+rings,0.0,.64);
 ALBEDO=mix(color*opacity*opacity,vec3(.66,.77,.70),cover);
 vec3 seen=textureLod(screen_texture,uv,0.0).rgb;
 EMISSION=seen*transmit*(1.0-cover)*(1.0-fresnel*.6);
 // Keep the sun confined to wave facets reflecting its direction toward the camera.
 // Limit peak brightness so individual glints stay distinct.
 vec3 light_view=normalize((VIEW_MATRIX*vec4(sun_direction,0.0)).xyz);
 float alignment=max(dot(reflect(-light_view,NORMAL),normalize(VIEW)),0.0);
 float glitter=pow(alignment,300.0);
 EMISSION+=vec3(1.0,.86,.63)*glitter*sun_strength*1.4*(1.0-clamp(foam,0.0,1.0));
 ROUGHNESS=mix(.16,.26,storm_strength);
 METALLIC=0.0;
 SPECULAR=0.0;
}
