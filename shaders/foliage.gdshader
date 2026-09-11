shader_type spatial;
uniform vec4 leaf_color : source_color=vec4(0.2,0.4,0.2,1.0);
uniform float motion_speed=1.0;
varying vec3 local;
void vertex(){
 local=VERTEX;
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(TIME*motion_speed*1.4+world.x*2.0+world.z)*max(VERTEX.y,0.0)*0.06;
}
void fragment(){
 ALBEDO=leaf_color.rgb*(0.92+local.y*0.12);
 ROUGHNESS=0.95;
}
