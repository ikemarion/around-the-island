extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._prepare_session()
	var host := "--report-host" in OS.get_cmdline_user_args()
	var dir := OS.get_environment("TEMP").path_join("ati-transfer-"+str(OS.get_process_id()))
	main.network_diagnostics.directory = dir
	if host:
		assert(main.report_transfer.accept_chunk(10,"../bad",4,0,PackedByteArray([1])) == -1)
		main.session_mode = &"hosting"
		main.peer_to_slot = {1:0}
		main.network_session.host_room(27993,false)
	else:
		main.network_diagnostics.export_report("test_previous_session")
		main.code_input.text = "127.0.0.1:27993"
		main._join_online()
	var deadline := Time.get_ticks_msec()+30000
	var passed := false
	while Time.get_ticks_msec()<deadline:
		await create_timer(0.2,true).timeout
		if host:
			if DirAccess.dir_exists_absolute(dir+"/received") and DirAccess.get_files_at(dir+"/received").size()>0:
				var files := DirAccess.get_files_at(dir+"/received")
				var report = JSON.parse_string(FileAccess.get_file_as_string((dir+"/received").path_join(files[0])))
				assert(report.reason == "test_previous_session")
				passed = true
				await create_timer(2,true).timeout
				break
		elif main.report_transfer.payload.is_empty() and DirAccess.dir_exists_absolute(dir+"/sent"):
			assert(DirAccess.get_files_at(dir+"/sent").size()>0)
			main.report_transfer.begin()
			assert(main.report_transfer.payload.is_empty())
			passed = true
			break
	if not passed:
		push_error("REPORT_TRANSFER timed out")
		quit(1)
		return
	print("REPORT_TRANSFER PASS ","host saved valid report" if host else "client ACK persisted and duplicate skipped")
	main._prepare_session()
	quit()
