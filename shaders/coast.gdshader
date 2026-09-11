shader_type spatial;
uniform sampler2D stone_noise : repeat_enable, filter_linear_mipmap;
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
 float n=texture(stone_noise,local.xz*3.0+local.y*0.5).r;
 float grain=texture(stone_noise,local.xz*25.0+local.y*10.0).r;
 float strata=sin(local.y*54.0+n*3.0)*0.035;
 vec3 stone=mix(vec3(0.19,0.23,0.20),vec3(0.43,0.36,0.23),smoothstep(-0.14,0.24,local.y));
 ALBEDO=stone*(0.84+n*0.3+grain*0.07+strata);
 ROUGHNESS=0.95;
}
