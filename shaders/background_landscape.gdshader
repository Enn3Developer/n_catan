shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec4 haze_color : source_color=vec4(.53,.65,.65,1.0);
void fragment(){
 // Opaque terrain writes depth normally. World fog alone supplies distance
 // haze; camera-facing alpha used to expose water through mountains/trees.
 ALBEDO=mix(COLOR.rgb,haze_color.rgb,.025);
 ROUGHNESS=1.0;
}
