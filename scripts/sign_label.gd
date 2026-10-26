extends Label3D
## A world sign that reads in the player's language (tools/build_assets.py World.label, localize=True): its text is
## an English message id that the Label3D translates by itself (locale/es.po), and each language gets the size that
## fits its board: `ems` = {language: em in metres}, measured by the generator; the font raster (font_size) stays.
## English keeps the size it always had. tests/signs_test.gd checks every sign on its board in both languages.

@export var ems := {}


func _ready() -> void:
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_fit()


func _fit() -> void:
	var lang := TranslationServer.get_locale().substr(0, 2)
	if ems.has(lang) or ems.has("en"):
		pixel_size = float(ems.get(lang, ems["en"])) / font_size
