// made for kay lousberg's kaykit models (kaylousberg.com)
// UV -> swatch -> settings

shader_type spatial;

uniform sampler2D palette_texture : source_color, filter_nearest;

uniform int columns = 8;
uniform int rows = 4;

uniform float base_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.5;

const int MAX_SLOTS = 64;

uniform vec4 color_changes[MAX_SLOTS];   // hue, saturation, contrast, brightness
uniform vec4 surface_changes[MAX_SLOTS]; // metallic, roughness, emission, -
uniform vec4 emission_colors[MAX_SLOTS] : source_color;


// -1 if past MAX_SLOTS
int slot_at(vec2 uv) {
	uv = clamp(uv, vec2(0.0), vec2(0.9999));
	int column = int(uv.x * float(columns));
	int row = int(uv.y * float(rows));
	int slot = row * columns + column;
	return slot < MAX_SLOTS ? slot : -1;
}


// sam hocevar
vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}


vec3 apply_color_changes(vec3 color, vec4 changes) {
	float hue_shift = changes.x;
	float saturation = changes.y;
	float contrast = changes.z;
	float brightness = changes.w;

	vec3 hsv = rgb_to_hsv(color);
	hsv.x = fract(hsv.x + hue_shift);
	hsv.y = clamp(hsv.y * (1.0 + saturation), 0.0, 1.0);
	color = hsv_to_rgb(hsv);

	color = (color - 0.5) * (1.0 + contrast) + 0.5;
	color *= 1.0 + brightness;
	return clamp(color, 0.0, 1.0);
}


void fragment() {
	vec3 color = texture(palette_texture, UV).rgb;
	float metallic = base_metallic;
	float roughness = base_roughness;
	vec3 emission = vec3(0.0);

	int slot = slot_at(UV);
	if (slot >= 0) {
		if (color_changes[slot] != vec4(0.0)) {
			color = apply_color_changes(color, color_changes[slot]);
		}
		vec4 surface = surface_changes[slot];
		metallic += surface.x;
		roughness += surface.y;
		emission = color * emission_colors[slot].rgb * surface.z;
	}

	ALBEDO = color;
	METALLIC = clamp(metallic, 0.0, 1.0);
	ROUGHNESS = clamp(roughness, 0.0, 1.0);
	EMISSION = emission;
}
