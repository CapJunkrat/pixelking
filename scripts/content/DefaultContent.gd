class_name DefaultContent
extends RefCounted

const ContentRegistryType = preload("res://scripts/content/ContentRegistry.gd")
const ContentCatalogType = preload("res://scripts/content/ContentCatalog.gd")
const CATALOG_PATH: String = "res://resources/content/default_catalog.tres"

static var _registry: ContentRegistryType = null

static func registry() -> ContentRegistryType:
	if _registry == null:
		var loaded_catalog: ContentCatalogType = load(CATALOG_PATH) as ContentCatalogType
		if loaded_catalog == null:
			push_error("Unable to load default content catalog: %s" % CATALOG_PATH)
			return null
		var candidate: ContentRegistryType = ContentRegistryType.new(loaded_catalog)
		if not candidate.is_valid():
			push_error("Default content catalog is invalid: %s" % candidate.validation_errors)
			return null
		_registry = candidate
	return _registry

static func reset_for_tests() -> void:
	_registry = null
