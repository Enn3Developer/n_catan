shader_type spatial;
uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform float terrain_kind=0.0;
uniform float variation=0.0;
uniform int footpath_count=0;
uniform vec4 footpaths[16];
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
 vec2 uv=UV*1.5+vec2(variation*.137,variation*.293);
 float grain=dot(texture(albedo_map,uv).rgb,vec3(.333));
 float broad=sin(local.x*5.1+variation)*sin(local.z*4.3+variation*.3)*.025;
 float edge=max(abs(local.x),max(abs(local.x*.5+local.z*.8660254),abs(-local.x*.5+local.z*.8660254)))/.8660254;
 float path=smoothstep(.82,.98,edge);
 float trail=0.0;
 for(int i=0;i<footpath_count;i++){
  vec2 a=footpaths[i].xy;vec2 delta=footpaths[i].zw-a;
  float t=clamp(dot(local.xz-a,delta)/max(dot(delta,delta),.00001),0.0,1.0);
  float distance_to_path=length(local.xz-a-delta*t);
  trail=max(trail,1.0-smoothstep(.025,.067,distance_to_path));
 }
 vec3 ground_color=mix(tint.rgb,tint.rgb*vec3(1.10,.94,.78),trail*.42);
 ALBEDO=ground_color*(.87+grain*.24+broad+path*.045);
 NORMAL_MAP=texture(normal_map,uv).rgb;
 NORMAL_MAP_DEPTH=.18;
 ROUGHNESS=.88;
 AO=mix(1.0,texture(orm_map,uv).r,.12);
}
