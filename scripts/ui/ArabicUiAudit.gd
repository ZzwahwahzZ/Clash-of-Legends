extends RefCounted
class_name ArabicUiAudit

static func audit_tree(root: Node) -> Dictionary:
	var result := {"controls":0,"rtl_controls":0,"arabic_text_controls":0,"bad_direction":[]}
	_walk(root, result)
	return result

static func _walk(node: Node, result: Dictionary) -> void:
	if node is Control:
		result["controls"] += 1
		var control := node as Control
		if control.layout_direction == Control.LAYOUT_DIRECTION_RTL and control.text_direction == Control.TEXT_DIRECTION_RTL:
			result["rtl_controls"] += 1
		var visible_text := ""
		if control is Label:
			visible_text = (control as Label).text
		elif control is Button:
			visible_text = (control as Button).text
		elif control is LineEdit:
			visible_text = (control as LineEdit).text
		elif control is RichTextLabel:
			visible_text = (control as RichTextLabel).text
		if _contains_arabic(visible_text):
			result["arabic_text_controls"] += 1
			if control.text_direction != Control.TEXT_DIRECTION_RTL:
				result["bad_direction"].append(str(control.get_path()))
	for child in node.get_children():
		_walk(child, result)

static func _contains_arabic(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if (code >= 0x0600 and code <= 0x06FF) or (code >= 0x0750 and code <= 0x077F) or (code >= 0x08A0 and code <= 0x08FF):
			return true
	return false
