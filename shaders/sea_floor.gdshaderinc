// Shared by the water surface and the sea bed: where the island tiles are,
// and how deep the bed lies at a given distance from their shore.
uniform int tile_count=0;
uniform vec2 tile_centers[48];
uniform float tile_radius=10.0;

float shore_distance(vec2 p){
 float d=10000.0;
 for(int i=0;i<48;i++){
  if(i>=tile_count)break;
  vec2 q=p-tile_centers[i];
  float e=max(abs(q.x),max(abs(q.x*.5+q.y*.8660254),abs(-q.x*.5+q.y*.8660254)))-tile_radius*.8660254;
  d=min(d,e);
 }
 return d;
}

// Metres below the waterline. A sandy shelf hugs each coast, drops over a
// step to a sloping reef, then falls away to deep water between islands.
float seabed_depth(float shore){
 float s=max(shore,0.0);
 float depth=mix(2.6,6.0,smoothstep(0.0,18.0,s));
 depth+=8.0*smoothstep(17.0,27.0,s);
 depth+=12.0*smoothstep(27.0,60.0,s);
 depth+=20.0*smoothstep(60.0,140.0,s);
 return depth;
}

float bed_hash(vec2 p){
 vec3 p3=fract(vec3(p.xyx)*.1031);
 p3+=dot(p3,p3.yzx+33.33);
 return fract((p3.x+p3.y)*p3.z);
}
float bed_noise(vec2 p){
 vec2 i=floor(p),f=fract(p);
 f=f*f*(3.0-2.0*f);
 return mix(mix(bed_hash(i),bed_hash(i+vec2(1,0)),f.x),mix(bed_hash(i+vec2(0,1)),bed_hash(i+vec2(1)),f.x),f.y);
}
// Height of the bed below the waterline at a world point, with dunes on the
// shelf and lumpier rock further out. Plants read it to stand on the bed.
float bed_height(vec2 p){
 float shore=shore_distance(p);
 float rough=bed_noise(p*.08)*1.6+bed_noise(p*.23)*.6;
 return -(seabed_depth(shore)+rough*smoothstep(-2.0,10.0,shore));
}
