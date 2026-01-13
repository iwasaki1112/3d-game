shader_type spatial;
render_mode unshaded, cull_front;

// Inverted hull outline with silhouette fade
uniform vec4 outline_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float outline_width : hint_range(0.001, 0.1) = 0.02;
uniform float emission_energy : hint_range(0.0, 10.0) = 4.0;
uniform float edge_sharpness : hint_range(1.0, 10.0) = 3.0;

varying vec3 world_normal;

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
	world_normal = NORMAL;
}

void fragment() {
	// Only show outline at silhouette edges (where normal is perpendicular to view)
	float edge = 1.0 - abs(dot(normalize(world_normal), VIEW));
	edge = pow(edge, edge_sharpness);

	if (edge < 0.3) {
		discard;
	}

	ALBEDO = outline_color.rgb;
	EMISSION = outline_color.rgb * emission_energy * edge;
}
