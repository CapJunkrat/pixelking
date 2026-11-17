class_name TestActiveRunSave
extends SceneTreeTestCase

const TEST_PATH = "user://pixelking_active_run_test.save"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sandbox: TestSaveSandbox = TestSaveSandbox.new().add(TEST_PATH)
	sandbox.cleanup()
	var state: RunState = RunState.new()
	state.initialize_new(700000000000000001, RunState.MODE_STANDARD)
	state.allocate_piece("king", true)
	state.gold = 88
	var service: ActiveRunSaveService = ActiveRunSaveService.new(TEST_PATH)
	var registry: ContentRegistry = DefaultContent.registry()

	expect(not service.exists(), "test begins without an active Run save")
	expect(service.save(state) == OK, "active Run saves atomically")
	var current_envelope: Dictionary = _read_envelope()
	expect(StringName(str(current_envelope.get("content_catalog_id", ""))) == registry.catalog.catalog_id, "save writes current content catalog ID")
	expect(int(current_envelope.get("content_version", 0)) == registry.catalog.content_version, "save writes current content version")
	var loaded: RunState = service.load_run()
	expect(loaded != null and loaded.run_seed == 700000000000000001 and loaded.gold == 88, "active Run round-trip preserves Run data and 64-bit seed")

	_write_envelope(state, &"", 0)
	var legacy_loaded: RunState = service.load_run()
	expect(legacy_loaded != null, "legacy envelope without content metadata remains compatible")
	expect(service.save(legacy_loaded) == OK, "legacy envelope can be rewritten using current metadata")
	var migrated_envelope: Dictionary = _read_envelope()
	expect(StringName(str(migrated_envelope.get("content_catalog_id", ""))) == registry.catalog.catalog_id and int(migrated_envelope.get("content_version", 0)) == registry.catalog.content_version, "rewriting legacy save upgrades its content envelope")

	var older_version: int = maxi(1, registry.catalog.content_version - 1)
	_write_envelope(state, registry.catalog.catalog_id, older_version)
	expect(service.load_run() != null, "older compatible content version loads")
	_write_envelope(state, &"other.catalog", registry.catalog.content_version)
	expect(service.load_run() == null and service.last_error == ERR_FILE_UNRECOGNIZED, "unknown content catalog ID is rejected")
	_write_envelope(state, registry.catalog.catalog_id, registry.catalog.content_version + 1)
	expect(service.load_run() == null and service.last_error == ERR_FILE_UNRECOGNIZED, "future content version is rejected")

	var broken_file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	broken_file.store_buffer(PackedByteArray([1, 2, 3, 4]))
	broken_file.close()
	expect(service.load_run() == null, "corrupt active Run fails safely")
	expect(service.save(state) == OK, "valid save can replace corrupt data")
	expect(service.delete() == OK and not service.exists(), "active Run save and transaction artifacts can be deleted")
	sandbox.cleanup()
	finish_test("Active Run save test")

func _write_envelope(state: RunState, catalog_id: StringName, content_version: int) -> void:
	var envelope: Dictionary = {
		"format_id": ActiveRunSaveService.FORMAT_ID,
		"save_format_version": ActiveRunSaveService.SAVE_FORMAT_VERSION,
		"content_catalog_id": String(catalog_id),
		"content_version": content_version,
		"run_state": state.to_dictionary(),
	}
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_buffer(ActiveRunSaveService.SAVE_MAGIC.to_ascii_buffer())
	file.store_var(envelope, false)
	file.close()

func _read_envelope() -> Dictionary:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.READ)
	file.get_buffer(ActiveRunSaveService.SAVE_MAGIC.length())
	var value: Variant = file.get_var(false)
	file.close()
	return value as Dictionary if value is Dictionary else {}
