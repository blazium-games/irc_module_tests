extends AutoworkTest

var irc1: IRCClientNode
var irc2: IRCClientNode
var live_ok := false
var test_channel = "#blz_multi_" + str(randi() % 1000)
var nick1 = "bz_test_a_" + str(randi() % 1000)
var nick2 = "bz_test_b_" + str(randi() % 1000)

func _require_live() -> bool:
	if live_ok:
		return true
	pending("Requires live libera.chat (set IRC_LIVE_TESTS=1)")
	return false

func _before_all():
	if OS.get_environment("IRC_LIVE_TESTS") != "1":
		return
	irc1 = IRCClientNode.new()
	irc2 = IRCClientNode.new()
	
	# Optional: Test our newly injected C++ debug endpoints
	irc1.set_debug_enabled(true)
	irc2.set_debug_enabled(true)
	
	add_child(irc1)
	add_child(irc2)
	
	watch_signals(irc1.get_client())
	watch_signals(irc2.get_client())

	print_log("Connecting Client 1 to irc.libera.chat...")
	var err1 = irc1.connect_to_server("irc.libera.chat", 6697, true, nick1, "blazebot1", "Blazium Test Bot 1")
	assert_eq(err1, OK, "Client 1 should initiate connection without error")

	print_log("Connecting Client 2 to irc.libera.chat...")
	var err2 = irc2.connect_to_server("irc.libera.chat", 6697, true, nick2, "blazebot2", "Blazium Test Bot 2")
	assert_eq(err2, OK, "Client 2 should initiate connection without error")
	
	for i in 600: # Max 60 seconds
		if irc1.is_irc_connected() and irc2.is_irc_connected():
			break
		await get_tree().create_timer(0.1).timeout
	live_ok = irc1.is_irc_connected() and irc2.is_irc_connected()

func _after_all():
	if irc1 and is_instance_valid(irc1):
		if irc1.is_irc_connected():
			irc1.disconnect_from_server("Testing completed 1")
		irc1.queue_free()
		
	if irc2 and is_instance_valid(irc2):
		if irc2.is_irc_connected():
			irc2.disconnect_from_server("Testing completed 2")
		irc2.queue_free()

func test_001_connection_established():
	if not _require_live():
		return
	assert_true(irc1.is_irc_connected(), "Client 1 should completely connect and authenticate to the host")
	assert_true(irc2.is_irc_connected(), "Client 2 should completely connect and authenticate to the host")

func test_002_channel_join():
	if not _require_live():
		return
	print_log("Clients actively connecting against channel " + test_channel)
	var joined_state = { "irc1": false, "irc2": false }
	irc1.get_client().joined.connect(func(channel): if channel == test_channel: joined_state.irc1 = true)
	irc2.get_client().joined.connect(func(channel): if channel == test_channel: joined_state.irc2 = true)
	
	# Guarantee irc1 becomes the Operator (+o) by ensuring they genuinely join first
	irc1.join_channel(test_channel)
	for i in 100: # 10 seconds max
		if joined_state.irc1:
			break
		await get_tree().create_timer(0.1).timeout
		
	# Now allow irc2 to join as a standard user
	irc2.join_channel(test_channel)
	for i in 100: # 10 seconds max
		if joined_state.irc2:
			break
		await get_tree().create_timer(0.1).timeout
		
	assert_true(joined_state.irc1, "Client 1 successfully located and embedded inside target namespace")
	assert_true(joined_state.irc2, "Client 2 successfully located and embedded inside target namespace")
	
	# Provide the IRCd a moment to successfully synchronize channel rosters globally
	await get_tree().create_timer(3.0).timeout

func test_003_channel_broadcast():
	if not _require_live():
		return
	print_log("Client 1 broadcasting standard payload to channel")
	var channel_msg = "Hello Client 2, confirming network routing structure."
	irc1.send_privmsg(test_channel, channel_msg)
	
	await wait_for_signal(irc2.get_client().privmsg, 10.0)
	var ping1_args = get_signal_parameters(irc2.get_client(), "privmsg")
	assert_not_null(ping1_args, "Client 2 should receive the broadcast message payload")
	if ping1_args != null:
		assert_eq(ping1_args[0], nick1, "Sender mapped accurately against Client 1 identity")
		assert_eq(ping1_args[1], test_channel, "Target maps perfectly to the specific channel instance")
		assert_eq(ping1_args[2], channel_msg, "Message payload matches 1:1 explicitly")

func test_004_direct_message():
	if not _require_live():
		return
	print_log("Client 2 transmitting private message standard payload directly to Client 1")
	var dm_msg = "I copy you perfectly loud and clear Client 1!"
	irc2.send_privmsg(nick1, dm_msg)
	
	await wait_for_signal(irc1.get_client().privmsg, 10.0)
	var ping2_args = get_signal_parameters(irc1.get_client(), "privmsg")
	assert_not_null(ping2_args, "Client 1 should actively receive the directed DM payload")
	if ping2_args != null:
		assert_eq(ping2_args[0], nick2, "Sender mapped accurately against Client 2 identity")
		assert_eq(ping2_args[1], nick1, "Target mapped exclusively to Client 1's local identity tracking")
		assert_eq(ping2_args[2], dm_msg, "Message payload matches exact DM string variant")

func test_005_ctcp_action():
	if not _require_live():
		return
	print_log("Client 1 executing CTCP action wrapper ping")
	var action_msg = "waves securely to the entire channel!"
	irc1.send_action(test_channel, action_msg)
	
	await wait_for_signal(irc2.get_client().privmsg, 10.0)
	var action_args = get_signal_parameters(irc2.get_client(), "privmsg")
	assert_not_null(action_args, "Client 2 should receive the external CTCP wrapper payload sequence")
	if action_args != null:
		assert_eq(action_args[0], nick1, "Sender matches Client 1 definitively")
		assert_true(action_args[2].contains(action_msg), "Should reliably contain the CTCP action message parameters")

func test_006_send_notice():
	if not _require_live():
		return
	print_log("Client 1 transmitting notice securely to Client 2")
	var dm_msg = "This is a strictly non-automated notice."
	irc1.send_notice(nick2, dm_msg)
	
	await wait_for_signal(irc2.get_client().notice, 10.0)
	var args = get_signal_parameters(irc2.get_client(), "notice")
	assert_not_null(args, "Client 2 should actively receive the directed Notice payload")
	if args != null:
		assert_eq(args[0], nick1, "Sender matches")
		assert_eq(args[1], nick2, "Target matches")
		assert_eq(args[2], dm_msg, "Message payload matches")

func test_007_set_topic():
	if not _require_live():
		return
	print_log("Client 1 modifying the general room topic")
	var new_topic = "Blazium Automated Headless Testing Room"
	irc1.set_topic(test_channel, new_topic)
	
	await wait_for_signal(irc2.get_client().topic_changed, 10.0)
	var args = get_signal_parameters(irc2.get_client(), "topic_changed")
	assert_not_null(args, "Client 2 should receive the updated topic signal")
	if args != null:
		assert_eq(args[0], test_channel, "Target channel matches")
		assert_eq(args[1], new_topic, "New topic string matches exactly")

func test_008_set_mode():
	if not _require_live():
		return
	print_log("Client 1 modifying Client 2's specific channel mode (+v)")
	# irc1 has operator status because they joined first to an empty channel!
	irc1.get_client().voice_user(test_channel, nick2)
	
	await wait_for_signal(irc2.get_client().mode_changed, 10.0)
	var args = get_signal_parameters(irc2.get_client(), "mode_changed")
	assert_not_null(args, "Client 2 should map the newly assigned mode signal")
	if args != null:
		assert_eq(args[0], test_channel, "Target channel matches")
		assert_true(args[1].contains("+v"), "Mode modification matched +v natively")
		assert_true(args[2].has(nick2), "Mode targets Client 2 exclusively")

func test_009_set_nick():
	if not _require_live():
		return
	print_log("Client 1 executes local identity change")
	var new_nick1 = "bz_test_x_" + str(randi() % 1000)
	irc1.set_nick(new_nick1)
	
	await wait_for_signal(irc2.get_client().nick_changed, 10.0)
	var args = get_signal_parameters(irc2.get_client(), "nick_changed")
	assert_not_null(args, "Client 2 should receive the identity update")
	if args != null:
		assert_eq(args[0], nick1, "Old nick matches explicitly")
		assert_eq(args[1], new_nick1, "New nick mapped effectively")
		
	nick1 = new_nick1 # Update state for test_011

func test_010_kick_user():
	if not _require_live():
		return
	print_log("Client 1 kicks Client 2 aggressively")
	var reason = "Testing bounds"
	irc1.get_client().kick_user(test_channel, nick2, reason)
	
	# Wait for kicked on Client 2 (it receives its own kicked from channel event natively)
	await wait_for_signal(irc2.get_client().kicked, 10.0)
	var args = get_signal_parameters(irc2.get_client(), "kicked")
	assert_not_null(args, "Client 2 maps self-kick signal execution properly")
	if args != null:
		assert_eq(args[0], test_channel, "Target channel matches")
		assert_true(args[1].contains(nick1), "Kicker maps against active Client 1")
		assert_eq(args[2], reason, "Reason explicitly verified matches")

func test_011_channel_part():
	if not _require_live():
		return
	print_log("Client 1 executing strict parting procedure")
	irc1.part_channel(test_channel)
	await wait_for_signal(irc1.get_client().parted, 10.0)
	var part1_args = get_signal_parameters(irc1.get_client(), "parted")
	assert_not_null(part1_args, "Client 1 should execute complete channel disconnection")
	
	# Client 2 was heavily kicked out so they do not execute part.
