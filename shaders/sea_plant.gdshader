shader_type spatial;
// Kelp, seagrass, corals, fans, sponges and starfish drawn as MultiMeshes.
// Instances are placed at the waterline; each one sinks to the sea bed height
// under its origin, so plants never float above or sink into the dunes.
render_mode cull_disabled;
#include "res://shaders/sea_floor.gdshaderinc"
uniform float water_level=-.675;
uniform float animation_time=0.0;
// Model height in metres before instance scale; the color runs base to tip.
uniform float model_height=1.0;
// How far the tip drifts in the swell, in model units.
uniform float sway=0.0;
uniform vec4 base_color : source_color=vec4(.2,.35,.18,1.0);
uniform vec4 tip_color : source_color=vec4(.45,.62,.3,1.0);
// A second tip color some instances take, like yellow sea fans among purple.
uniform vec4 variant_color : source_color=vec4(.45,.62,.3,1.0);
uniform float variant_share=0.0;
varying float along;
varying float tint;

void vertex(){
 vec3 origin=MODEL_MATRIX[3].xyz;
 float scale=max(length(MODEL_MATRIX[1].xyz),.001);
 float bed=water_level+bed_height(origin.xz);
 along=clamp(VERTEX.y/model_height,0.0,1.0);
 tint=bed_hash(floor(origin.xz*3.1)+.5);
 float bend=pow(along,1.6)*sway;
 vec2 phase=origin.xz*.13;
 VERTEX.x+=(sin(animation_time*1.1+phase.x)+.3*sin(animation_time*2.3+phase.y))*bend;
 VERTEX.z+=cos(animation_time*.8+phase.y)*bend*.6;
 // Sink a little into the bed so no gap shows under the base.
 VERTEX.y+=(bed-origin.y)/scale-.06/scale;
}

void fragment(){
 vec3 tip=mix(tip_color.rgb,variant_color.rgb,step(1.0-variant_share,tint));
 ALBEDO=mix(base_color.rgb,tip,along)*(.85+.3*tint);
 ROUGHNESS=.8;
 SPECULAR=.2;
}
