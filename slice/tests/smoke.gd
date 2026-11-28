extends SceneTree
func _init() -> void:
	var s := GameState.new(42)
	print("hero negotiation ", s.skill("hero", "negotiation"))
	print(Act0.blocker(s, Act0.activity("bulk_run")))
	Act0.start_week(s)
	print(Act0.book(s, "bulk_run"), " food ", s.led("food"))
	print(Act0.bedrock(s))
	print(s.fill("{partner.name} said {partner.they} would call {elder.them}."))
	var d := GameState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	print("roundtrip ", d.led("food"), " ", d.members["partner"]["name"])
	quit()
