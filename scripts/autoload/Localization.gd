extends Node

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "en"
const LOCALES := {
	"en": {
		"label": "English",
		"enabled": true,
		"title_path": "res://assets/ui/titles/pixel_king_en.png",
		"strings": {
			"COLOR_WHITE": "White",
			"COLOR_BLACK": "Black",
			"PIECE_PAWN": "Pawn",
			"PIECE_KNIGHT": "Knight",
			"PIECE_BISHOP": "Bishop",
			"PIECE_ROOK": "Rook",
			"PIECE_QUEEN": "Queen",
			"PIECE_KING": "King",
			"MENU_NEW_GAME": "New Journey",
			"MENU_CONTINUE": "Continue",
			"MENU_SETTINGS": "Settings",
			"MENU_QUIT": "Quit Game",
			"MENU_OVERWRITE_TITLE": "Start a New Journey?",
			"MENU_OVERWRITE_MESSAGE": "Your current journey will be replaced only after the new Run is safely saved.",
			"RUN_SEED_TITLE": "Choose a Run Seed",
			"RUN_SEED_PROMPT": "Enter a signed integer, or leave it blank for a random journey.",
			"RUN_SEED_PLACEHOLDER": "Random seed",
			"RUN_SEED_RANDOM": "Random",
			"RUN_SEED_INVALID": "Please enter a valid integer seed.",
			"COMMON_CONFIRM": "Confirm",
			"COMMON_CANCEL": "Cancel",
			"DRAFT_TITLE": "Opening Draft",
			"DRAFT_ROUND": "Choice %d / %d",
			"DRAFT_INSTRUCTION": "Choose one piece. Every offer includes a Rare contender.",
			"DRAFT_POWER": "Base value: %d",
			"DRAFT_SELECTED": "ROSTER",
			"DRAFT_SEED": "Seed: %d",
			"DRAFT_COMPLETE": "Draft Complete",
			"DRAFT_COMPLETE_DETAIL": "Your opening roster is ready. The path map arrives in the next milestone.",
			"DRAFT_PROTOTYPE_BATTLE": "Enter Prototype Battle",
			"DRAFT_RETURN_MENU": "Return to Main Menu",
			"DRAFT_NO_ACTIVE_RUN": "No active journey was found.",
			"RARITY_COMMON": "Common",
			"RARITY_RARE": "Rare",
			"RARITY_EPIC": "Epic",
			"RARITY_LEGENDARY": "Legendary",
			"SAVE_ERROR": "The journey could not be saved. Your previous state is still safe.",
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
			"BATTLE_TITLE": "Royal Trial",
			"BATTLE_TURN": "%s Turn",
			"BATTLE_SELECTED": "%s selected",
			"BATTLE_CHECK": "%s is in check",
			"BATTLE_BACK": "Return to Hall",
			"BATTLE_YOUR_TURN": "YOUR TURN",
			"BATTLE_ENEMY_TURN": "ENEMY TURN",
			"BATTLE_ENEMY": "BOSS",
			"BATTLE_CHALLENGER": "ITEMS",
			"BATTLE_SETTINGS_RESUME": "Resume",
			"BATTLE_SETTINGS_MAIN_MENU": "Return to Main Menu",
			"BATTLE_SETTINGS_CONFIRM": "Leave this battle and return to the main menu?",
			"BATTLE_EMPTY_SLOT": "Empty challenger slot",
			"BATTLE_VICTORY": "VICTORY",
			"BATTLE_DEFEAT": "DEFEAT",
			"BATTLE_DRAW": "DRAW",
			"BATTLE_VICTORY_DETAIL": "The enemy king has fallen.",
			"BATTLE_DEFEAT_DETAIL": "Your king has fallen.",
			"BATTLE_DRAW_DETAIL": "Neither side can continue the battle.",
			"BATTLE_RETRY": "Retry Battle",
			"BATTLE_RESULT_MAIN_MENU": "Return to Main Menu",
		},
	},
	"zh_CN": {
		"label": "简体中文 - Coming Soon",
		"enabled": false,
		"title_path": "",
		"strings": {},
	},
}

var current_locale: String = DEFAULT_LOCALE

func _ready() -> void:
	call_deferred("_restore_saved_locale")

func _restore_saved_locale() -> void:
	var settings_manager: AppSettingsManager = get_node("/root/SettingsManager") as AppSettingsManager
	var saved_locale: String = settings_manager.locale
	if not set_locale(saved_locale, false):
		set_locale(DEFAULT_LOCALE, true)

func set_locale(locale: String, should_persist: bool = true) -> bool:
	if not LOCALES.has(locale) or not bool(LOCALES[locale].get("enabled", false)):
		return false
	current_locale = locale
	TranslationServer.set_locale(locale)
	if should_persist:
		var settings_manager: AppSettingsManager = get_node("/root/SettingsManager") as AppSettingsManager
		settings_manager.set_locale(locale)
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
