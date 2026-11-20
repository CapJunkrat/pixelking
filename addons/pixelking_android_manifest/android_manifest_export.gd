@tool
extends EditorExportPlugin

## The game locks the screen to portrait, and Google Play reads that lock as "this app
## needs a portrait screen" (android.hardware.screen.portrait, required). That hides the
## game from devices Play thinks have no portrait screen (some tablets, Chromebooks, PC,
## XR). The game still asks for portrait; it just doesn't require the hardware for it.
const PORTRAIT_OPTIONAL := "<uses-feature android:name=\"android.hardware.screen.portrait\" android:required=\"false\" />"

func _get_name() -> String:
	return "PixelKingAndroidManifest"

func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid

func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	return PORTRAIT_OPTIONAL
