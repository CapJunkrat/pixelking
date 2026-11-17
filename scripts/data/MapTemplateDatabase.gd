class_name MapTemplateDatabase
extends RefCounted

const STANDARD_TEMPLATE_ID: StringName = &"standard_region"

## Compatibility query facade. Formal map-template content is owned by ContentCatalog.
static func get_def(id: StringName) -> MapTemplateDef:
	var registry: ContentRegistry = DefaultContent.registry()
	return registry.map_template(id) if registry != null else null

static func standard() -> MapTemplateDef:
	return get_def(STANDARD_TEMPLATE_ID)
