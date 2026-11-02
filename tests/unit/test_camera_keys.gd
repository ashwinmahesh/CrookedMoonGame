extends TestCase
## The Crooked Moon's keys (data/campaign.json "keys", Ashwin 2026-11-02): WASD works the camera (A and D turn it, W and
## S tilt it) and the arrows walk; Q and E still turn it.


func test_wasd_works_the_camera_and_the_arrows_walk() -> void:
	assert_eq(InputActions.keys_default(&"move_forward"), [KEY_UP, KEY_NONE] as Array[int], "up walks forward")
	assert_eq(InputActions.keys_default(&"move_left"), [KEY_LEFT, KEY_NONE] as Array[int], "left walks left")
	assert_eq(InputActions.keys_default(&"camera_rotate_left"), [KEY_A, KEY_Q] as Array[int], "A or Q turns left")
	assert_eq(InputActions.keys_default(&"camera_rotate_right"), [KEY_D, KEY_E] as Array[int], "D or E turns right")
	assert_eq(InputActions.keys_default(&"camera_tilt_up"), [KEY_W, KEY_PAGEUP] as Array[int], "W tilts up")
	assert_eq(InputActions.keys_default(&"camera_tilt_down"), [KEY_S, KEY_PAGEDOWN] as Array[int], "S tilts down")
	# No two commands that can be used together share a default key.
	for c: Array in InputActions.COMMANDS:
		var a := c[0] as StringName
		for other: StringName in InputActions.clashing(a):
			for k in InputActions.keys_default(a):
				if k != KEY_NONE:
					assert_false(k in InputActions.keys_default(other), "%s and %s both have %s" % [a, other, InputActions.key_name(k)])
