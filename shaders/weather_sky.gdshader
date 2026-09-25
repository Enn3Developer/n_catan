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
// Where the current strike is; its glow is brightest on that side of the sky.
uniform vec3 flash_direction = vec3(0,.35,-1);
// Rain thickens the air near the horizon into a grey veil.
uniform float rain_haze = 0.0;
uniform vec3 sun_direction = vec3(0,1,0);
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
float clouds(vec2 p){
 return texture(cloud_noise,p*.035).r*.62+texture(cloud_noise,p*.079+vec2(.31,.67)).r*.26+texture(cloud_noise,p*.21+vec2(.73,.12)).r*.12;
}
void sky(){
 vec3 dir=normalize(EYEDIR);
 float elevation=max(dir.y,0.0);
 vec3 color=mix(sky_horizon_color.rgb,sky_top_color.rgb,pow(elevation,.45));
 float toward_sun=max(dot(dir,sun_direction),0.0);
 float sun=pow(toward_sun,1600.0);
 color+=vec3(1.0,.82,.56)*sun*daylight*sun_visibility*2.0;
 // A soft halo around the sun, warmer when it is low.
 color+=vec3(1.0,.74,.48)*pow(toward_sun,24.0)*.18*daylight*sun_visibility;
 float glow=flash*(.35+.65*pow(max(dot(dir,normalize(flash_direction)),0.0),3.0));
 if(dir.y>0.0){
  vec2 wind=vec2(animation_time*.014,animation_time*.004)*(1.0+storm_strength*1.5);
  // Thin, fast-drifting high cloud that shows even on fair days.
  vec2 high=dir.xz/(dir.y+.12)*1.1+wind*1.8;
  float wisps=smoothstep(.55,.9,texture(cloud_noise,high*vec2(.02,.06)).r)*(1.0-smoothstep(.55,.95,cloud_cover));
  vec3 wisp_color=mix(vec3(1.0,.93,.86),vec3(1.0),daylight)*mix(.18,1.0,daylight);
  color=mix(color,wisp_color,wisps*.35*smoothstep(0.0,.12,dir.y));
  if(cloud_cover>.01){
   // A kilometre-high layer projected into the sky, with wind across its whole extent.
   vec2 p=dir.xz/(dir.y+.06)*2.2+wind;
   float body=clouds(p);
   float threshold=mix(.78,.2,cloud_cover);
   float density=smoothstep(threshold,threshold+.26,body);
   // Thick cloud is darker underneath; sunlit edges catch a silver rim.
   float thickness=smoothstep(threshold,threshold+.5,body);
   float light_edge=clamp((body-clouds(p+sun_direction.xz*.25))*3.0+.55,0.0,1.0);
   vec3 underside=mix(vec3(.5,.57,.63),vec3(.18,.22,.28),storm_strength);
   vec3 lit=mix(vec3(.97,.96,.91),vec3(.52,.57,.61),storm_strength);
   vec3 cloud_color=mix(underside,lit,light_edge*(1.0-thickness*.55));
   cloud_color+=vec3(1.0,.85,.6)*pow(toward_sun,6.0)*(1.0-thickness)*.35*sun_visibility*daylight;
   cloud_color*=mix(.13,1.0,daylight);
   cloud_color+=vec3(.52,.62,.85)*glow*(.6+thickness);
   color=mix(color,cloud_color,density*smoothstep(0.0,.07,dir.y));
  }
 }
 color+=vec3(.42,.5,.72)*glow*.25;
 vec3 veil=mix(vec3(.2,.24,.29),vec3(.62,.67,.71),daylight);
 color=mix(color,veil,rain_haze*.7*(1.0-smoothstep(0.0,.35,elevation)));
 if(dir.y<0.0){color=mix(sky_horizon_color.rgb,vec3(.055,.13,.16)*mix(.2,1.0,daylight),smoothstep(0.0,.4,-dir.y));}
 COLOR=color;
}
