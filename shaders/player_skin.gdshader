shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 fallback_color : source_color = vec4(0.2, 0.5, 0.8, 1.0);
uniform bool has_texture = false;

varying vec3 model_pos;

void vertex() {
	// Pass model-space vertex position to fragment shader
	model_pos = VERTEX;
}

void fragment() {
	// Cylindrical UV mapping for capsule using model-space position
	// Angle around the Y axis for U coordinate
	float u = atan(model_pos.x, model_pos.z) / (2.0 * PI) + 0.5;
	// Height for V coordinate (normalized to capsule height, centered at origin)
	// Capsule mesh is 1.4 units tall, ranging from -0.7 to 0.7
	float v = (model_pos.y + 0.7) / 1.4;

	vec2 cylindrical_uv = vec2(u, 1.0 - v);

	if (has_texture) {
		ALBEDO = texture(texture_albedo, cylindrical_uv).rgb;
	} else {
		ALBEDO = fallback_color.rgb;
	}

	ROUGHNESS = 0.8;
	METALLIC = 0.0;
}
