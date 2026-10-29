shader_type spatial;
// Firedamp (DESIGN.md §4): only a faint shimmer, like hot air, a little greenish where the lamp
// light catches it. Bends what is behind it with slow noise; fades out towards the edge.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 0.05) = 0.012;
uniform vec4 tint : source_color = vec4(0.75, 0.9, 0.7, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.08;

float wave(vec3 p, float t) {
	return sin(p.x * 3.1 + t * 1.3) * sin(p.y * 2.3 - t * 0.9) + sin(p.z * 2.7 + t * 1.1) * 0.5;
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	vec2 offset = vec2(wave(world, t), wave(world.zxy, t + 3.0)) * strength;
	// The sphere's rim is where you look through little of it: fade out there.
	float facing = abs(dot(normalize(NORMAL), normalize(-VERTEX)));
	float body = smoothstep(0.05, 0.6, facing);
	vec3 behind = textureLod(screen_texture, SCREEN_UV + offset * body, 0.0).rgb;
	ALBEDO = mix(behind, behind * tint.rgb * 1.4, tint_amount * body);
	ALPHA = body * 0.9;
}
