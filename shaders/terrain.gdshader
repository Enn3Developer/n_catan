shader_type spatial;
uniform vec4 ground_color : source_color;
uniform sampler2D ground_noise : repeat_enable, filter_linear_mipmap;
uniform float terrain_kind=0.0;
varying vec3 local;
void vertex(){ local=VERTEX; }
void fragment(){
 vec2 uv=local.xz;
 float broad=texture(ground_noise,uv*1.8).r;
 float fine=texture(ground_noise,uv*22.0).r;
 float speck=texture(ground_noise,uv*61.0).r;
 vec3 c=ground_color.rgb*(0.72+broad*0.42+fine*0.18);
 if(terrain_kind==3.0){
  float furrow=smoothstep(0.12,0.3,abs(sin(uv.x*46.0)));
  c*=0.78+furrow*0.22;
 }
 ALBEDO=c;
 ROUGHNESS=0.93;
 NORMAL_MAP=vec3(0.5+(fine-0.5)*0.25,0.5+(speck-0.5)*0.25,1.0);
 NORMAL_MAP_DEPTH=0.3;
}
