shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.85, 0.75, 0.25, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 3.5;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.5;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float roughness : hint_range(0.0, 1.0) = 0.3;
uniform float metallic : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	ALBEDO = base_color.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	
	// Dynamic glow oscillation for high-tier Conquer Online-style glowing weaponry
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_intensity;
	EMISSION = glow_color.rgb * (emission_energy * pulse);
}
