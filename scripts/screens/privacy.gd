extends Screen
## App information page about privacy. Not a substitute for the Google UMP
## consent form, which M3 opens from "Privacy options" where applicable.


func build() -> void:
	content.add_child(Ui.top_bar("PRIVACY_TITLE", "PRIVACY_SUBTITLE", Game.back))
	content.add_child(Ui.spacer(Palette.SPACE * 2))
	for key in ["PRIVACY_OFFLINE", "PRIVACY_NO_ACCOUNT", "PRIVACY_ADS"]:
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		card.add_child(Ui.label(key, "", HORIZONTAL_ALIGNMENT_LEFT))
		content.add_child(card)
	content.add_child(Ui.spacer(0, true))
	content.add_child(Ui.button("CONTINUE", Game.leave, true, "PrivacyContinue"))
