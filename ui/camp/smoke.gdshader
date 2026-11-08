shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform sampler2D smoke_mask : source_color, filter_linear;
varying vec4 particle_tint;
void vertex() {
	particle_tint = COLOR;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
}
void fragment() {
	vec4 sample_mask = texture(smoke_mask, UV);
	float density = dot(sample_mask.rgb, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = particle_tint.rgb;
	ALPHA = density * sample_mask.a * particle_tint.a;
}
