shader_type spatial;
render_mode diffuse_toon, depth_draw_opaque, cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;

group_uniforms CellShading;
uniform vec4 shadow_color : source_color;
uniform int bands : hint_range(1, 10) = 5;
uniform float shadow_intensity : hint_range(-1.0, 0.5, 0.05) = 0.0;
uniform bool use_ambient_light = true;
uniform vec3 ambient_light : source_color = vec3(0.447, 0.490, 0.620);
uniform float ambient_energy : hint_range(0.0, 2.0, 0.05) = 1.0;
uniform vec3 sun_direction = vec3(0.5, -0.707, -0.5);
uniform vec3 sun_color : source_color = vec3(1.0);
group_uniforms;

varying vec3 world_normal;

void vertex() {
	world_normal = (MODEL_NORMAL_MATRIX * NORMAL);
}

vec3 apply_cel_lighting(vec3 base, vec3 n) {
	vec3 l = normalize(sun_direction);
	float ndotl = clamp(dot(normalize(n), l), 0.0, 1.0);
	float stepped = ceil(ndotl * float(bands)) / float(bands);
	float toon_light = mix(shadow_intensity, 0.3, stepped);
	vec3 direct = mix(shadow_color.rgb, sun_color, toon_light);
	vec3 ambient = use_ambient_light ? base * ambient_light * ambient_energy : vec3(0.0);
	return base * direct + ambient;
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo_tex.rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = apply_cel_lighting(ALBEDO, world_normal);
#else
	if (use_ambient_light) {
		EMISSION = ALBEDO * ambient_light * ambient_energy;
	}
#endif
}

void light() {
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
	float NdotL = dot(NORMAL, LIGHT);
	NdotL = clamp(NdotL, 0.0, 1.0);

	float stepped = ceil(NdotL * float(bands)) / float(bands);
	float toon_light = mix(shadow_intensity, 0.3, stepped);

	toon_light *= ATTENUATION;

	vec3 light_color = mix(shadow_color.rgb, LIGHT_COLOR.rgb, toon_light);

	DIFFUSE_LIGHT += light_color;
#endif
}