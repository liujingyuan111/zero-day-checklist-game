// Adapted from "Hit flash effect", sakurap3, credit triangledevv (CC0).
shader_type canvas_item;

uniform bool active = false;
uniform vec4 tint : source_color = vec4(1.0, 0.88, 0.61, 1.0);

void fragment() {
	if (active) {
		COLOR.rgb = tint.rgb;
	}
}
