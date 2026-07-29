extends Node

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "en"
const LOCALES := {
	"en": {
		"label": "English",
		"enabled": true,
		"title_path": "res://assets/ui/titles/pixel_king_en.png",
		"strings": {
			"MENU_NEW_GAME": "New Journey",
			"MENU_CONTINUE": "Continue",
			"MENU_SETTINGS": "Settings",
			"MENU_QUIT": "Quit Game",
			"SETTINGS_TITLE": "Settings",
			"SETTINGS_LANGUAGE": "Language",
			"SETTINGS_PIECE_SKIN": "Piece Skin",
			"SETTINGS_SKIN_PREVIEW": "Preview",
			"SETTINGS_MUSIC": "Music Volume",
			"SETTINGS_SOUND": "SFX Volume",
			"COMMON_BACK": "Back",
			"JOURNEY_TITLE": "The Journey Awaits",
			"JOURNEY_DESCRIPTION": "The 5 x 5 battle board arrives in the next P2 milestone.",
			"JOURNEY_BACK": "Back to Main Menu",
		},
	},
	"zh_CN": {
		"label": "\u7b80\u4f53\u4e2d\u6587 - Coming Soon",
		"enabled": false,
		"title_path": "",
		"strings": {},
	},
}

var current_locale: String = DEFAULT_LOCALE

func _ready() -> void:
	TranslationServer.set_locale(DEFAULT_LOCALE)

func set_locale(locale: String) -> bool:
	if not LOCALES.has(locale) or not LOCALES[locale].get("enabled", false):
		return false
	current_locale = locale
	TranslationServer.set_locale(locale)
	locale_changed.emit(locale)
	return true

func text(key: String) -> String:
	var strings: Dictionary = LOCALES[current_locale].get("strings", {})
	return strings.get(key, key)

func title_texture() -> Texture2D:
	var path: String = LOCALES[current_locale].get("title_path", "")
	if path.is_empty():
		path = LOCALES[DEFAULT_LOCALE].get("title_path", "")
	return load(path) as Texture2D

func locale_codes() -> Array:
	return LOCALES.keys()

func locale_info(locale: String) -> Dictionary:
	return LOCALES.get(locale, {})
