shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, specular_disabled;
uniform vec4 haze_color : source_color=vec4(.53,.65,.65,1.0);
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float facing=dot(normalize(world_position.xz),normalize(CAMERA_POSITION_WORLD.xz));
 // Keep the near side open as the camera orbits, with a broad, gradual fade.
 ALPHA=1.0-smoothstep(-.05,.40,facing);
 float haze=clamp((length(world_position.xz)-95.0)/400.0,.12,.48);
 ALBEDO=mix(COLOR.rgb,haze_color.rgb,haze);
 ROUGHNESS=1.0;
}
