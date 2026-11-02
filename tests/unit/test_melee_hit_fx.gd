extends TestCase
## Melee hit effects (MeleeHitFx, Ashwin's picks 2026-11-02): each kind of blow gets its own look in place of the
## engine's crescent, in moonlight unless the blow has a flavour of its own, and lands on the swing's hit frame.


func after_each() -> void:
	MeleeHitFx.use({})


func test_the_picks_per_kind() -> void:
	assert_eq(MeleeHitFx.style_for("blade"), "cut", "a blade: a clean cut")
	assert_eq(MeleeHitFx.style_for("point"), "ring", "a point: a pierce ring")
	assert_eq(MeleeHitFx.style_for("blunt"), "shock", "a club or hammer: a shock ring")
	assert_eq(MeleeHitFx.style_for("unarmed"), "ripple", "a fist: a ripple")
	assert_eq(MeleeHitFx.style_for("shot"), "", "a shot keeps the engine's look")


func test_the_game_lands_blows_on_the_hit_frame_without_ink() -> void:
	GameFeel.use(null)
	assert_true(GameFeel.flag("strike_on_hit_frame"), "effects land on the hit frame")
	assert_false(GameFeel.flag("kill_splash"), "no ink splash on a kill")
	assert_eq(GameFeel.num("impact_frame"), 0.0, "no ink-and-paper frame")


func test_colours_are_moonlight_unless_the_blow_has_its_own() -> void:
	var steel := MeleeHitFx.colours({"flavour": "steel", "colours": {"core": Color.RED}})
	assert_eq(steel["core"], Look.color("frost"), "a steel blow in frost")
	assert_eq(steel["glow"], Look.color("moonlight"), "and moonlight")
	var fire := MeleeHitFx.colours({"flavour": "fire", "colours": {"core": Color.RED, "glow": Color.ORANGE}})
	assert_eq(fire["core"], Color.RED, "a fiery claw keeps its fire")


func test_each_kind_draws_and_ends() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 4, 6)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	var fx := SpellFx.new()
	add_child(fx)
	var hero := Character.new()
	hero.id = "test_melee_fx_hero"
	hero.name = "Test Hero"
	var foe := Character.new()
	foe.id = "test_melee_fx_foe"
	foe.name = "Test Foe"
	var a := CombatToken.create(Combatant.new(hero, &"party", Vector2i.ZERO), "test_melee_fx_look")
	var d := CombatToken.create(Combatant.new(foe, &"enemy", Vector2i(1, 0)), "test_melee_fx_look")
	fx.add_child(a)
	fx.add_child(d)
	d.position = Vector3(1, 0, 0)
	var cue := {"family": "slash", "flavour": "steel", "colours": SpellFx.colours("steel")}
	for kind: String in ["blade", "point", "blunt", "unarmed"]:
		for crit: bool in [false, true]:
			assert_true(CampaignLook.current().melee_hit(fx, cue, a, d, crit, kind), "%s drawn by the game" % kind)
			var n := fx.get_child(fx.get_child_count() - 1)
			for c in fx.get_children():
				if c is MeleeHitFx and not (c as Node).is_queued_for_deletion():
					n = c
			assert_true(n is MeleeHitFx, "%s: the effect is in place" % kind)
			var m := n as MeleeHitFx
			m._draw(0.04)
			var mesh := m._face.mesh as ImmediateMesh
			assert_true(mesh.get_surface_count() > 0, "%s: something drawn on the blow" % kind)
			m._draw(5.0)
			assert_eq(mesh.get_surface_count(), 0, "%s: nothing left once it is over" % kind)
			m.free()
	assert_false(CampaignLook.current().melee_hit(fx, cue, a, d, false, "shot"), "a kind with no pick is the engine's")
	for t: CombatToken in [a, d]:
		CombatToken._looks.erase(t.combatant.id)
	fx.free()
	cam.free()
