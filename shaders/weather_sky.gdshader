shader_type sky;
render_mode disable_fog;
uniform vec4 sky_top_color : source_color = vec4(.153,.502,.812,1);
uniform vec4 sky_horizon_color : source_color = vec4(.643,.835,.957,1);
uniform float cloud_cover = 0.0;
uniform float sun_visibility = 1.0;
uniform float storm_strength = 0.0;
uniform float daylight = 1.0;
uniform float animation_time = 0.0;
uniform float flash = 0.0;
uniform vec3 sun_direction = vec3(0,1,0);
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
float clouds(vec2 p){
 return texture(cloud_noise,p*.035).r*.82+texture(cloud_noise,p*.079+vec2(.31,.67)).r*.18;
}
void sky(){
 vec3 dir=normalize(EYEDIR);
 float elevation=max(dir.y,0.0);
 vec3 color=mix(sky_horizon_color.rgb,sky_top_color.rgb,pow(elevation,.45));
 float sun=pow(max(dot(dir,sun_direction),0.0),1600.0);
 color+=vec3(1.0,.82,.56)*sun*daylight*sun_visibility*2.0;
 if(dir.y>0.0 && cloud_cover>.01){
  // A kilometre-high layer projected into the sky, with wind across its whole extent.
  vec2 p=dir.xz/(dir.y+.06)*2.2+vec2(animation_time*.014,animation_time*.004);
  float body=clouds(p);
  float threshold=mix(.78,.22,cloud_cover);
  float density=smoothstep(threshold,threshold+.23,body);
  float light_edge=clamp((body-clouds(p+sun_direction.xz*.25))*3.0+.55,0.0,1.0);
  vec3 underside=mix(vec3(.47,.55,.61),vec3(.22,.28,.34),storm_strength);
  vec3 lit=mix(vec3(.96,.96,.90),vec3(.56,.61,.64),storm_strength);
  vec3 cloud_color=mix(underside,lit,light_edge)*mix(.13,1.0,daylight);
  cloud_color+=vec3(.52,.62,.85)*flash;
  color=mix(color,cloud_color,density*smoothstep(0.0,.07,dir.y));
 }
 if(dir.y<0.0){color=mix(sky_horizon_color.rgb,vec3(.055,.13,.16)*mix(.2,1.0,daylight),smoothstep(0.0,.4,-dir.y));}
 COLOR=color;
}
