shader_type spatial;
uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
 vec2 uv=UV;
 float grain=dot(texture(albedo_map,uv).rgb,vec3(.333));
 float wet=1.0-smoothstep(-.19,-.08,local.y);
 ALBEDO=vec3(.34,.35,.30)*(.96+grain*.08)*(1.0-wet*.20);
 NORMAL_MAP=texture(normal_map,uv).rgb;
 NORMAL_MAP_DEPTH=.12;
 ROUGHNESS=mix(.86,.58,wet);
}
