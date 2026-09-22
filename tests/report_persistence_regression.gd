extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._prepare_session()
	main.set_physics_process(false)
	var directory := "res://build/network-test/report-persistence-%d" % OS.get_process_id()
	main.network_diagnostics.directory = directory
	var transfer = main.report_transfer
	var data := JSON.stringify({"build":"regression", "recent_events":[], "padding":"x".repeat(1000)}).to_utf8_buffer()
	var id: String = transfer._hash(data)
	var target := directory + "/received/" + id + ".json"
	# An empty directory occupying the target simulates a failed final write.
	DirAccess.make_dir_recursive_absolute(target)
	check(transfer.accept_chunk(10, id, data.size(), 0, data.slice(0, 800)) == 800, "First report chunk not accepted")
	await create_timer(0.06, true).timeout
	check(transfer.accept_chunk(10, id, data.size(), 800, data.slice(800)) == -1, "Failed report write acknowledged completion")
	await create_timer(0.06, true).timeout
	check(transfer.accept_chunk(10, id, data.size(), 800, data.slice(800)) == -1, "Retried final chunk falsely acknowledged unsaved report")
	check(not FileAccess.file_exists(target), "Failure fixture unexpectedly saved a report")
	DirAccess.remove_absolute(target) # Only the empty directory this test created.
	await create_timer(0.06, true).timeout
	check(transfer.accept_chunk(10, id, data.size(), 800, data.slice(800)) == data.size(), "Recovered storage did not persist the retained report")
	check(FileAccess.get_file_as_bytes(target) == data and not transfer.incoming.has(10), "Saved report differs or transfer remained stuck")
	await create_timer(0.06, true).timeout
	check(transfer.accept_chunk(10, id, data.size(), 800, data.slice(800)) == data.size(), "Lost final ACK should recover from the valid saved report")
	# A partially written existing target must not count as a completed report.
	var small := JSON.stringify({"build":"regression", "recent_events":["partial"]}).to_utf8_buffer()
	var small_id: String = transfer._hash(small)
	var small_target := directory + "/received/" + small_id + ".json"
	var partial := FileAccess.open(small_target, FileAccess.WRITE)
	partial.store_string("partial")
	partial.close()
	await create_timer(0.06, true).timeout
	check(transfer.accept_chunk(10, small_id, small.size(), 0, small) == small.size(), "Existing partial report was not repaired")
	check(FileAccess.get_file_as_bytes(small_target) == small, "A partial file was acknowledged without complete replacement")
	# Exercise the real inbox cap, not a stubbed failure branch.
	var full_directory := directory + "/full-inbox"
	DirAccess.make_dir_recursive_absolute(full_directory + "/received")
	var filler_path := full_directory + "/received/owned-quota-fixture.bin"
	var filler := FileAccess.open(filler_path, FileAccess.WRITE)
	filler.seek(transfer.INBOX_LIMIT - 1)
	filler.store_8(0)
	filler.close()
	main.network_diagnostics.directory = full_directory
	await create_timer(0.06, true).timeout
	check(transfer.accept_chunk(10, small_id, small.size(), 0, small) == -1, "Inbox cap was not enforced")
	await create_timer(0.06, true).timeout
	check(transfer.accept_chunk(10, small_id, small.size(), 0, small) == -1, "Full inbox retry falsely acknowledged a dropped report")
	DirAccess.remove_absolute(filler_path) # Exact quota fixture owned by this test.
	await create_timer(0.06, true).timeout
	check(transfer.accept_chunk(10, small_id, small.size(), 0, small) == small.size(), "Report did not recover after the host cleared its full inbox")
	# A client session flag must never send an RPC to an offline peer (which
	# reports connected with local ID 1), or consume its pending transfer.
	main.session_mode = &"client"
	main.local_slot = 1
	transfer.payload = small
	transfer.digest = small_id
	transfer.offset = 0
	transfer.timer = 0.0
	transfer._process(0.5)
	check(transfer.timer == 0.0 and transfer.payload == small and transfer.offset == 0, "Offline client attempted a report RPC or lost its pending transfer")
	main._prepare_session()
	main.queue_free()
	await process_frame
	print("REPORT_PERSISTENCE failures=", failures)
	quit(1 if failures else 0)
