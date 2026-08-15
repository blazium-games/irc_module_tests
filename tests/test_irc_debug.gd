extends AutoworkTest

func test_001_debug_disabled():
	if OS.get_environment("IRC_LIVE_TESTS") != "1":
		pending("Requires live libera.chat (set IRC_LIVE_TESTS=1)")
		return
	print_log("Spawning isolated headless engine process to execute connection sequence with DEBUG = FALSE")
	var output = []
	var exe_path = OS.get_executable_path()
	
	var script_code = """extends SceneTree
func _init():
	var irc = IRCClientNode.new()
	irc.set_debug_enabled(false) # DEFAULT STATE
	irc.connect_to_server("irc.libera.chat", 6667, false, "bz_dummy", "dummy", "dummy")
	for i in 30: # 3.0 seconds
		OS.delay_msec(100)
		irc.get_client().poll()
	quit()
"""
	var file = FileAccess.open("res://tests/temp_debug_off.gd", FileAccess.WRITE)
	file.store_string(script_code)
	file.close()
	
	OS.execute(exe_path, ["--headless", "-s", "res://tests/temp_debug_off.gd"], output)
	DirAccess.remove_absolute("res://tests/temp_debug_off.gd")
	
	assert_true(output.size() > 0, "Engine output should be captured")
	if output.size() > 0:
		assert_false(output[0].contains("IRC SEND:"), "Output must remain fully devoid of ANY raw IRC payload string outputs when debug is strictly false natively")

func test_002_debug_enabled():
	if OS.get_environment("IRC_LIVE_TESTS") != "1":
		pending("Requires live libera.chat (set IRC_LIVE_TESTS=1)")
		return
	print_log("Spawning isolated headless engine process to execute connection sequence with DEBUG = TRUE")
	var output = []
	var exe_path = OS.get_executable_path()
	
	var script_code = """extends SceneTree
func _init():
	var irc = IRCClientNode.new()
	irc.set_debug_enabled(true) # OVERRIDDEN STATE
	irc.connect_to_server("irc.libera.chat", 6667, false, "bz_dummy", "dummy", "dummy")
	for i in 30: # 3.0 seconds
		OS.delay_msec(100)
		irc.get_client().poll()
	quit()
"""
	var file = FileAccess.open("res://tests/temp_debug_on.gd", FileAccess.WRITE)
	file.store_string(script_code)
	file.close()
	
	OS.execute(exe_path, ["--headless", "-s", "res://tests/temp_debug_on.gd"], output)
	DirAccess.remove_absolute("res://tests/temp_debug_on.gd")
	
	assert_true(output.size() > 0, "Engine output should be captured")
	if output.size() > 0:
		assert_true(output[0].contains("IRC SEND:"), "Output must explicitly dump raw TCP payload string identifiers safely mapping raw C++ overrides effectively")
