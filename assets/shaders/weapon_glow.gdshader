shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.85, 0.75, 0.25, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 3.5;
uniform float glow_intensity : hint_range(0.0, 16.0) = 2.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.5;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float roughness : hint_range(0.0, 1.0) = 0.3;
uniform float metallic : hint_range(0.0, 1.0) = 0.8;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float rim_intensity : hint_range(0.0, 8.0) = 1.8;
uniform float sweep_speed : hint_range(0.0, 8.0) = 1.4;
uniform float sweep_intensity : hint_range(0.0, 4.0) = 0.7;
uniform float refine_tier : hint_range(0.0, 12.0) = 1.0;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float fresnel = pow(clamp(1.0 - max(dot(n, v), 0.0), 0.0, 1.0), rim_power);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_intensity;
	float tier_gain = 1.0 + clamp(refine_tier, 0.0, 12.0) * 0.12;
	float sweep_phase = fract(TIME * sweep_speed + UV.y * 0.65);
	float sweep = pow(1.0 - abs(sweep_phase * 2.0 - 1.0), 12.0);

	ALBEDO = base_color.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = glow_color.rgb * (
		emission_energy * glow_intensity * tier_gain * pulse
		+ fresnel * rim_intensity
		+ sweep * sweep_intensity
	);
}
