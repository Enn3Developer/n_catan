shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength=0.0;
varying float along_beam;
void vertex(){along_beam=clamp((VERTEX.y+2.75)/5.5,0.0,1.0);}
void fragment(){
 ALBEDO=vec3(1.0,.79,.39);
 // Ordinary transparency avoids additive HDR halos at the cone rim.
 // Fade both ends so the open mesh never reads as a luminous ring.
 float edge=pow(abs(normalize(NORMAL).z),.7);
 float ends=smoothstep(0.0,.22,along_beam)*(1.0-smoothstep(.85,1.0,along_beam));
 ALPHA=strength*.055*ends*edge;
}
