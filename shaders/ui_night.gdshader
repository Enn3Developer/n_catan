shader_type canvas_item;
// Fades interface textures toward the night palette. Accents, selected wood,
// icons and ink symbols keep tones of their own so they still stand out.
// Paired textures fade to hand-drawn night art of the same shape instead.
render_mode unshaded;
uniform float night = 0.0;
uniform bool accent = false;
uniform bool selected = false;
uniform bool icon = false;
uniform bool symbol = false;
uniform bool paired = false;
uniform float lift = 0.0;
uniform sampler2D night_texture : filter_linear;
void fragment() {
	vec4 day = texture(TEXTURE, UV);
	float value = dot(day.rgb, vec3(0.299, 0.587, 0.114));
	vec3 dark = mix(vec3(0.055, 0.085, 0.13), vec3(0.23, 0.30, 0.39), value);
	if (accent) dark = mix(vec3(0.08, 0.14, 0.11), vec3(0.37, 0.48, 0.31), value);
	if (selected) dark = mix(vec3(0.16, 0.13, 0.08), vec3(0.52, 0.41, 0.22), value);
	if (icon) dark = mix(vec3(0.51, 0.56, 0.62), vec3(0.90, 0.79, 0.56), value);
	dark += lift;
	if (symbol) day.rgb *= vec3(0.286, 0.208, 0.129);
	COLOR = vec4(mix(day.rgb, dark, night), day.a);
	if (paired) COLOR = mix(day, texture(night_texture, UV), night);
}
