extends Control

signal resume

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	UIEvents.open_terminal_menu.connect(reset)
	UIEvents.terminal_result_ready.connect(_on_terminal_result_ready)
	UIEvents.ui_cancel_pressed.connect(_resume)
	UIEvents.ui_accept_pressed.connect(_handle_accept)
	ExhibitFetcher.search_complete.connect(_show_page_result)
	ExhibitFetcher.random_complete.connect(_show_page_result)
	reset()

func _resume() -> void:
	resume.emit()

func reset() -> void:
	$MarginContainer/StartPage/RandomExhibit.disabled = false
	$MarginContainer/SearchPage/SearchExhibit.disabled = false
	_switch_to_page("StartPage")
	$MarginContainer/StartPage/EnterExhibit.grab_focus()

func _switch_to_page(page: String) -> void:
	for vbox in $MarginContainer.get_children():
		vbox.visible = false
	get_node("MarginContainer/" + page).visible = true

func _go_to_search_page() -> void:
	_switch_to_page("SearchPage")
	UIEvents.emit_reset_custom_door()
	$MarginContainer/SearchPage/ExhibitTitle.grab_focus()

func _get_random_page() -> void:
	$MarginContainer/StartPage/RandomExhibit.disabled = true
	UIEvents.emit_reset_custom_door()
	ExhibitFetcher.fetch_random(null)

func _handle_accept() -> void:
	if $MarginContainer/SearchPage/ExhibitTitle.has_focus():
		_search_exhibit()

func _search_exhibit() -> void:
	var search_text = $MarginContainer/SearchPage/ExhibitTitle.text
	if len(search_text) > 0:
		$MarginContainer/SearchPage/SearchExhibit.disabled = true
		ExhibitFetcher.fetch_search($MarginContainer/SearchPage/ExhibitTitle.text, null)

func _show_page_result(page: Variant, _ctx: Variant) -> void:
	$MarginContainer/SearchPage/ExhibitTitle.text = ""
	_on_terminal_result_ready(not page, page)

func _on_terminal_result_ready(error: bool, page: String) -> void:
	if error:
		_switch_to_page("ErrorPage")
		$MarginContainer/ErrorPage/Reset.grab_focus()
	else:
		_switch_to_page("ResultPage")
		UIEvents.emit_set_custom_door(page)
		$MarginContainer/ResultPage/ResultLabel.text = "Exhibit Found: \"%s\"" % page
		$MarginContainer/ResultPage/Reset.grab_focus()

func _on_reset_pressed() -> void:
	reset()
	_resume()
