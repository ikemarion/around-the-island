extends SceneTree

var assertion_executed := false

func _assertion_sentinel() -> bool:
	assertion_executed = true
	return true

func _initialize() -> void:
	# Release templates compile assert() out. Such an executable must never be
	# allowed to report passing assertion-based regression tests.
	if not OS.is_debug_build():
		push_error("TEST_EXPORT_ENVIRONMENT requires a debug engine/template; release exports disable assertions")
		quit(1)
		return
	assert(_assertion_sentinel())
	if not assertion_executed:
		push_error("TEST_EXPORT_ENVIRONMENT assertions were stripped from this test pack")
		quit(1)
		return
	print("TEST_EXPORT_ENVIRONMENT PASS: debug assertions enabled")
	quit()
