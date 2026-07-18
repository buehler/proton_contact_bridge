build_runner task="build":
	dart run build_runner {{task}}

launcher_icons:
	dart run flutter_launcher_icons

native_logs:
	xcrun simctl spawn booted log stream \
		--level debug \
		--predicate 'subsystem == "ch.cbue.protonContactBridge"'
