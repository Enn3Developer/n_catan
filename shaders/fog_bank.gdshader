shader_type spatial;
// The fog bank over a hidden hex. Puffs are shaded by height, grey-blue
// underneath and bright on top, with a soft rim where they meet the sky.
// Each vertex drifts a little so the bank seems to breathe.
render_mode cull_back;
uniform float animation_time=0.0;
uniform vec4 low_color : source_color=vec4(.38,.43,.5,1.0);
uniform vec4 high_color : source_color=vec4(.8,.83,.86,1.0);
varying float height;

void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float drift=sin(animation_time*.35+world.x*.21+world.z*.17)+.6*sin(animation_time*.23-world.z*.31);
 VERTEX+=NORMAL*drift*.018;
 VERTEX.x+=sin(animation_time*.12+world.z*.05)*.02;
 height=VERTEX.y;
}

void fragment(){
 float up=smoothstep(.12,.5,height);
 // Crevices between puffs face sideways; darken them so each puff reads.
 float facing_up=clamp((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).y,0.0,1.0);
 ALBEDO=mix(low_color.rgb,high_color.rgb,up)*mix(.72,1.0,facing_up);
 float rim=pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),3.0);
 EMISSION=high_color.rgb*rim*.05;
 ROUGHNESS=1.0;
 SPECULAR=0.0;
 BACKLIGHT=vec3(.2);
}
