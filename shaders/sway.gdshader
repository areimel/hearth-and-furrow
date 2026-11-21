shader_type canvas_item;
// Gentle wind sway for crop sprites. The top of the sprite leans, the root stays put.
// The offset is rounded to whole pixels so the pixel art stays crisp.

uniform float strength = 0.7;
uniform float speed = 2.0;

void vertex() {
	float lean = 1.0 - UV.y;
	float phase = MODEL_MATRIX[3].x * 0.35 + MODEL_MATRIX[3].y * 0.2;
	float wave = sin(TIME * speed + phase) + 0.4 * sin(TIME * speed * 2.3 + phase * 1.7);
	VERTEX.x += floor(wave * strength * lean * lean + 0.5);
}
