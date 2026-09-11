shader_type spatial;
uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform float texture_scale=2.0;
uniform float texture_strength=.10;
uniform float metallic=0.0;
uniform float roughness=.82;
varying vec3 position_local;
varying vec3 normal_local;
void vertex(){position_local=VERTEX;normal_local=NORMAL;}
void fragment(){
 vec3 blend=pow(abs(normal_local),vec3(4.0));blend/=max(dot(blend,vec3(1.0)),.0001);
 vec3 p=position_local*texture_scale;
 vec3 c=texture(albedo_map,p.zy).rgb*blend.x+texture(albedo_map,p.xz).rgb*blend.y+texture(albedo_map,p.xy).rgb*blend.z;
 float grain=dot(c,vec3(.333));
 ALBEDO=tint.rgb*(1.0+(grain-.5)*texture_strength);
 ROUGHNESS=roughness;
 METALLIC=metallic;
 // Preserve the sculpted surface normal. Mixing triplanar tangent normals
 // without reorientation creates false seams and unrelated lighting facets.
}
