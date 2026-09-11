shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color=vec4(.3,.5,.3,1.0);
uniform float flexibility=.01;
uniform float motion_speed=.65;
uniform bool soft_blades=false;
varying vec3 local_vertex;
void vertex(){
 local_vertex=VERTEX;
 float anchor=max(0.0,VERTEX.y-.24);
 float phase=TIME*motion_speed;
 VERTEX.x+=sin(phase+VERTEX.z*2.0)*anchor*flexibility*clamp(motion_speed,0.0,1.0);
}
void fragment(){
 if(!FRONT_FACING)NORMAL=-NORMAL;
 float variation=sin(local_vertex.x*23.0+local_vertex.z*17.0)*.035;
 ALBEDO=leaf_color.rgb*(1.0+variation);
 if(soft_blades){
  // Thin grass receives soft skylight on both faces instead of black cutouts.
  vec3 sky_normal=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
  NORMAL=normalize(mix(NORMAL,sky_normal,.45));
  BACKLIGHT=leaf_color.rgb*.18;
 }
 ROUGHNESS=.87;
 SPECULAR=.22;
}
