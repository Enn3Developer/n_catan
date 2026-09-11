shader_type spatial;
uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform float terrain_kind=0.0;
uniform float variation=0.0;
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
 vec2 uv=UV*1.5+vec2(variation*.137,variation*.293);
 float grain=dot(texture(albedo_map,uv).rgb,vec3(.333));
 float broad=sin(local.x*5.1+variation)*sin(local.z*4.3+variation*.3)*.025;
 float edge=max(abs(local.x),max(abs(local.x*.5+local.z*.8660254),abs(-local.x*.5+local.z*.8660254)))/.8660254;
 float path=smoothstep(.82,.98,edge);
 ALBEDO=tint.rgb*(.94+grain*.10+broad+path*.045);
 NORMAL_MAP=texture(normal_map,uv).rgb;
 NORMAL_MAP_DEPTH=.10;
 ROUGHNESS=.88;
 AO=mix(1.0,texture(orm_map,uv).r,.12);
}
