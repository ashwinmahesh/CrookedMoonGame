// The trunks and boughs of the realistic trees (RealPlants, world/look/real_plants.gd): the glTF's own bark colour,
// normal and ambient-occlusion pictures, bending in the engine's wind (wind.gdshaderinc) as Flora's painted bark does,
// so the leaves and the wood move together. The instance colour darkens a whole tree.
shader_type spatial;
render_mode world_vertex_coords, diffuse_burley, specular_schlick_ggx;
#include "res://addons/dnd_core/shaders/atmosphere/wind.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float normal_depth = 1.0;
uniform float shade_floor : hint_range(0.0, 1.0) = 0.5;
// Wood this close to the camera is cut away (world units), with the leaves round it.
uniform float near_fade = 5.0;

varying vec3 wpos;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	VERTEX += wind_offset(root, VERTEX - root, 0.0, 0.0, TIME);
	wpos = VERTEX;
}

void fragment() {
	// Written so the instance's transparency (SeeThrough's fade) reaches it, as it does the engine's bark.
	ALPHA = step(near_fade * 0.75, distance(wpos, CAMERA_POSITION_WORLD));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	float ao = texture(ao_tex, UV).r;
	ALBEDO = texture(albedo_tex, UV).rgb * tint * COLOR.rgb * mix(shade_floor, 1.0, COLOR.a);
	NORMAL_MAP = texture(normal_tex, UV).xyz;
	NORMAL_MAP_DEPTH = normal_depth;
	AO = ao;
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
