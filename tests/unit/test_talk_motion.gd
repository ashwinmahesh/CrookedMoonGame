extends TestCase
## Talking figures (world/look/talk_motion.gd, tools/art/build_portrait_busts.py): a figure's head nods with the voice
## and settles when the line ends, and the companions and the people of the place have their portraits as busts, each
## shown as drawn on its usual side.


func _figure(id: String) -> ModelFigure:
	var fig := DirectionalSprite.create(DirectionalSprite.frames_for(id), CombatToken.height_for(id)) as ModelFigure
	add_child(fig)
	return fig


func test_the_head_nods_while_talking_and_settles_after() -> void:
	var fig := _figure("the_vagrant")
	var skel := fig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var nod := TalkMotion.HeadNod.new()
	nod.head = TalkMotion.HeadNod.bone_named(skel, "Head")
	nod.neck = TalkMotion.HeadNod.bone_named(skel, "Neck")
	assert_true(nod.head >= 0 and nod.neck >= 0, "the Mixamo rig's head and neck are found under their prefix")
	skel.add_child(nod)
	var rest := skel.get_bone_pose_rotation(nod.head)
	nod.talking = true
	for i in 10:
		nod.loudness = float(i % 2)
		skel.set_bone_pose_rotation(nod.head, rest)
		nod._process_modification_with_delta(0.05)
	assert_true(skel.get_bone_pose_rotation(nod.head).angle_to(rest) > deg_to_rad(0.5), "the head moves while the line is said")
	nod.talking = false
	for i in 20:
		skel.set_bone_pose_rotation(nod.head, rest)
		nod._process_modification_with_delta(0.05)
	assert_true(skel.get_bone_pose_rotation(nod.head).angle_to(rest) < 0.0001, "and is left as the clip has it once the line ends")
	fig.free()


func test_a_head_with_a_jaw_opens_its_mouth_with_the_voice() -> void:
	for id: String in ["rook_coldwake", "delphine_ravelle", "the_vagrant", "tobin_hayward"]:
		var ch := Character.new()
		ch.name = id
		var tok := CombatToken.create(Combatant.new(ch, &"party", Vector2i.ZERO), id)
		add_child(tok)
		var jaw := TalkMotion.jaw_of(tok)
		assert_true(jaw != null, "%s: the head's own skeleton has a Jaw" % id)
		var skel := jaw.get_skeleton()
		var rest := skel.get_bone_pose_rotation(jaw.jaw)
		var rest_at := skel.get_bone_pose_position(jaw.jaw)
		jaw.talking = true
		jaw.loudness = 1.0
		for i in 10:
			skel.set_bone_pose_rotation(jaw.jaw, rest)
			skel.set_bone_pose_position(jaw.jaw, rest_at)
			jaw._process_modification_with_delta(0.05)
		assert_true(jaw.openness() > 0.9, "%s: open on a loud syllable" % id)
		assert_between(skel.get_bone_pose_rotation(jaw.jaw).angle_to(rest), deg_to_rad(8.0), deg_to_rad(11.0), "%s: the jaw dropped" % id)
		# It glides forward as it drops, so the lower lip falls straight down rather than tucking back into a pout.
		var glide := skel.get_bone_pose_position(jaw.jaw) - rest_at
		assert_gt(glide.dot(jaw.forward_in_parent(skel)), 0.009, "%s: the jaw glides forward as it opens" % id)
		jaw.talking = false
		for i in 20:
			skel.set_bone_pose_rotation(jaw.jaw, rest)
			skel.set_bone_pose_position(jaw.jaw, rest_at)
			jaw._process_modification_with_delta(0.05)
		assert_true(jaw.openness() < 0.01, "%s: shut once the line ends" % id)
		tok.free()
	assert_eq(TalkMotion.jaw_of(null), null, "nobody, no jaw")


func test_a_sprite_has_no_nod() -> void:
	assert_eq(TalkMotion.nod_of(null), null, "nobody, no nod")


func test_the_leads_and_people_have_busts_shown_as_drawn() -> void:
	for id: String in ["rook_coldwake", "silas_vane", "cordelia_skein", "delphine_ravelle", "lucan_houndstooth", "tobin_hayward"]:
		var path := DialogueBusts.path_for(id)
		assert_true(path != "", "%s has a bust" % id)
		assert_false(DialogueBusts.mirrored(path, true, false), "%s shows on the left as drawn" % id)
	for id: String in ["the_vagrant", "phillip_druskenvald", "adela_druskenvald", "alda_farnum"]:
		var path := DialogueBusts.path_for(id)
		assert_true(path != "", "%s has a bust" % id)
		assert_false(DialogueBusts.mirrored(path, false, false), "%s shows on the right as drawn" % id)
	assert_eq(DialogueBusts.path_for("godrick_pendlebrook"), "", "the old game's drawn heroes have none")
