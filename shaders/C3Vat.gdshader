shader_type spatial;
render_mode cull_disabled;

uniform sampler2D vat_texture : filter_nearest, repeat_disable;
uniform sampler2D albedo_texture : source_color, filter_linear, repeat_disable;
uniform float vat_frame = 0.0;
uniform float vat_width = 1.0;
uniform float vat_height = 1.0;

void vertex() {
	float frame_a = floor(clamp(vat_frame, 0.0, vat_height - 1.0));
	float frame_b = min(frame_a + 1.0, vat_height - 1.0);
	float blend = fract(clamp(vat_frame, 0.0, vat_height - 1.0));
	float vertex_u = (float(VERTEX_ID) + 0.5) / vat_width;
	vec3 position_a = textureLod(vat_texture, vec2(vertex_u, (frame_a + 0.5) / vat_height), 0.0).xyz;
	vec3 position_b = textureLod(vat_texture, vec2(vertex_u, (frame_b + 0.5) / vat_height), 0.0).xyz;
	VERTEX = mix(position_a, position_b, blend);
}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb;
	ALPHA = texture(albedo_texture, UV).a;
}
