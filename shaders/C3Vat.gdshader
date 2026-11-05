shader_type spatial;
render_mode cull_disabled;

uniform sampler2D vat_texture : filter_nearest, repeat_disable;
uniform sampler2D vat_normal_texture : filter_nearest, repeat_disable;
uniform sampler2D albedo_texture : source_color, filter_linear, repeat_disable;
uniform float vat_frame = 0.0;
uniform float vat_width = 1.0;
uniform float vat_height = 1.0;

void vertex() {
	float frame_a = floor(clamp(vat_frame, 0.0, vat_height - 1.0));
	float frame_b = min(frame_a + 1.0, vat_height - 1.0);
	float blend = fract(clamp(vat_frame, 0.0, vat_height - 1.0));
	float vertex_u = UV2.x;
	vec3 position_a = textureLod(vat_texture, vec2(vertex_u, (frame_a + 0.5) / vat_height), 0.0).xyz;
	vec3 position_b = textureLod(vat_texture, vec2(vertex_u, (frame_b + 0.5) / vat_height), 0.0).xyz;
	VERTEX = mix(position_a, position_b, blend);
	vec3 normal_a = textureLod(vat_normal_texture, vec2(vertex_u, (frame_a + 0.5) / vat_height), 0.0).xyz * 2.0 - 1.0;
	vec3 normal_b = textureLod(vat_normal_texture, vec2(vertex_u, (frame_b + 0.5) / vat_height), 0.0).xyz * 2.0 - 1.0;
	NORMAL = normalize(mix(normal_a, normal_b, blend));
}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb;
}
