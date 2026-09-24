shader_type spatial;
// Fish in a MultiMesh. The nose points along +Z; the body bends in a wave
// that grows towards the tail. INSTANCE_CUSTOM.r is each fish's phase and
// .g its stroke rate, which speeds up when it swims faster.
render_mode cull_disabled;
uniform float animation_time=0.0;
uniform vec4 back_color : source_color=vec4(.2,.32,.42,1.0);
uniform vec4 belly_color : source_color=vec4(.82,.86,.88,1.0);
uniform vec4 stripe_color : source_color=vec4(.2,.32,.42,1.0);
// Stripes per metre along the body, 0 for none.
uniform float stripes=0.0;
uniform float shine=.35;
varying float up;
varying float length_pos;

void vertex(){
 float phase=INSTANCE_CUSTOM.r*6.2831853+animation_time*INSTANCE_CUSTOM.g;
 float tail=smoothstep(.35,-.6,VERTEX.z);
 VERTEX.x+=sin(phase-VERTEX.z*5.0)*.11*tail+sin(phase)*.015;
 up=VERTEX.y;
 length_pos=VERTEX.z;
}

void fragment(){
 vec3 color=mix(belly_color.rgb,back_color.rgb,smoothstep(-.02,.07,up));
 if(stripes>0.0){
  float band=smoothstep(.35,.5,abs(fract(length_pos*stripes)-.5));
  color=mix(color,stripe_color.rgb,band*.7);
 }
 ALBEDO=color;
 METALLIC=shine;
 ROUGHNESS=.35;
}
