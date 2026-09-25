shader_type spatial;
// Beaches and rock shelves along the coast. Vertex color carries the share of
// sand (r), shingle (g) and rock (b); the waterline darkens and wets them.
render_mode cull_disabled;
uniform float water_level=-.675;
uniform vec4 sand_color : source_color=vec4(.86,.77,.58,1.0);
uniform vec4 pebble_light : source_color=vec4(.74,.71,.66,1.0);
uniform vec4 pebble_dark : source_color=vec4(.45,.43,.41,1.0);
uniform vec4 rock_color : source_color=vec4(.52,.49,.45,1.0);
uniform vec4 lichen_color : source_color=vec4(.83,.66,.28,1.0);
uniform vec4 weed_color : source_color=vec4(.26,.3,.17,1.0);
varying vec3 world;
varying vec3 share;

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
// Rounded pebbles: the nearest cell point gives each stone its own shade,
// and the gap to the second nearest draws the crevices between them.
vec3 pebbles(vec2 p){
 vec2 cell=floor(p),f=fract(p);
 float first=8.0,second=8.0;
 vec2 owner=vec2(0.0);
 for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
  vec2 o=vec2(float(x),float(y));
  vec2 point=o+.15+.7*vec2(hash(cell+o),hash(cell+o+7.7));
  float d=length(point-f);
  if(d<first){second=first;first=d;owner=cell+o;}else if(d<second){second=d;}
 }
 return vec3(hash(owner*1.3),smoothstep(0.0,.18,second-first),hash(owner+3.1));
}
void vertex(){
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 share=COLOR.rgb;
}
void fragment(){
 vec2 p=world.xz;
 float above=world.y-water_level;
 float grain=noise(p*4.0)*.6+noise(p*17.0)*.4;
 vec3 sand=sand_color.rgb*(.9+grain*.18)*(1.0-.06*smoothstep(.55,.8,noise(p*.45)));
 vec3 stone=pebbles(p*3.2);
 vec3 shingle=mix(pebble_dark.rgb,pebble_light.rgb,stone.x)*mix(.55,1.0,stone.y);
 shingle=mix(shingle,vec3(.78,.62,.45),step(.86,stone.z)*.5);
 float strata=sin(world.y*5.0+noise(p*.5)*4.0)*.5+.5;
 vec3 rock=rock_color.rgb*(.8+strata*.15+grain*.15);
 rock=mix(rock,lichen_color.rgb,smoothstep(.72,.9,noise(p*1.3+11.0))*smoothstep(.9,1.6,above)*.6);
 vec3 color=sand*share.r+shingle*share.g+rock*share.b;
 // A dark band of weed along rocky waterlines.
 color=mix(color,weed_color.rgb,(1.0-smoothstep(.1,.55,abs(above-.1)))*share.b*.7*smoothstep(.35,.6,noise(p*2.0)));
 // Wet ground below the swash line, which wanders a little along the coast.
 float wet=1.0-smoothstep(.2,.55,above-(noise(p*.3)-.5)*.3);
 ALBEDO=color*mix(1.0,.62,wet);
 ROUGHNESS=mix(.92,.28,wet);
 SPECULAR=mix(.2,.5,wet);
}
