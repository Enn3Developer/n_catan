shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color=vec4(.3,.5,.3,1.0);
uniform float flexibility=.01;
uniform float motion_speed=.65;
void vertex(){
 float anchor=max(0.0,VERTEX.y-.24);
 float phase=TIME*motion_speed;
 VERTEX.x+=sin(phase+VERTEX.z*2.0)*anchor*flexibility*clamp(motion_speed,0.0,1.0);
}
void fragment(){
 if(!FRONT_FACING)NORMAL=-NORMAL;
 ALBEDO=leaf_color.rgb;
 ROUGHNESS=.87;
 SPECULAR=.22;
}
