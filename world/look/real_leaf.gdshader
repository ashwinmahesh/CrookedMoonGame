// The leaves and ground plants of the realistic trees and plants (RealPlants, world/look/real_plants.gd): the glTF's own
// leaf picture with a hard alpha edge (so they stay in the opaque pass and cast shadows through their gaps), both sides
// drawn, swaying in the wind of the engine's own include (wind.gdshaderinc, the same code Flora's painted plants run:
// a plant bends from its foot more the higher a point stands, and its cards flutter by UV2: x how free, y a phase).
// Vertex alpha is how much light reaches that part of a plant (the inside of a crown is darker); the instance colour
// darkens or warms a whole plant (the land darkens the ones further out). The wind and the figures among the plants
// are copied from Flora's own materials every frame (RealPlants.sync), so a place's weather moves these as well.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;
#include "res://addons/dnd_core/shaders/atmosphere/wind.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
// One tree's own shade, set per instance by the Woods (groves a little warmer or cooler); 1 leaves it be.
instance uniform vec3 hue = vec3(1.0);
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform float shade_floor : hint_range(0.0, 1.0) = 0.55;
uniform float backlight : hint_range(0.0, 1.0) = 0.3;
uniform float roughness : hint_range(0.1, 1.0) = 0.8;
// Leaves this close to the camera thin away (world units), so a camera tilted down near the trees sees past them.
uniform float near_fade = 5.0;

varying vec3 wpos;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	VERTEX += wind_offset(root, VERTEX - root, UV2.x, UV2.y, TIME);
	wpos = VERTEX;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	// Mipmaps average the gaps into the leaves and thin the alpha out; give it back as the picture gets smaller on
	// screen, so far trees keep their mass.
	vec2 px = UV * vec2(textureSize(albedo_tex, 0));
	vec2 dx = dFdx(px);
	vec2 dy = dFdy(px);
	float mip = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	ALPHA = clamp(t.a * (1.0 + mip * 0.22), 0.0, 1.0) * smoothstep(near_fade * 0.55, near_fade, distance(wpos, CAMERA_POSITION_WORLD));
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 c = t.rgb * tint * hue * COLOR.rgb * mix(shade_floor, 1.0, COLOR.a);
	ALBEDO = c;
	// The back of a leaf keeps the crown's outward normal (Godot flips it for back faces).
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	// Never below 0.1: the screen pass reads near-zero roughness as water.
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
	BACKLIGHT = c * backlight;
}
