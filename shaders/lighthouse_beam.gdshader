shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength=0.0;
varying float along_beam;
void vertex(){along_beam=clamp((VERTEX.y+2.75)/5.5,0.0,1.0);}
void fragment(){
 ALBEDO=vec3(1.0,.79,.39);
 // Soft silhouette and distance falloff, with no opaque end cap.
 float edge=pow(abs(normalize(NORMAL).z),.7);
 ALPHA=strength*.04*pow(along_beam,1.5)*edge;
}
