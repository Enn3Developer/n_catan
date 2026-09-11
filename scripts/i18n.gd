class_name CatanI18n
extends RefCounted

# Wire messages carry keys and typed arguments. Names are never translated.
const PREFIX="@catan:"
static func message(key: String,args: Array=[]) -> String:
	return PREFIX+JSON.stringify({"key":key,"args":args})

static func term(key: String) -> Dictionary:
	return {"key":key}

static func render(value: Variant) -> String:
	if value is Dictionary:
		if value.has("list"):
			var parts=PackedStringArray()
			for part in value.list:parts.append(render(part))
			return ", ".join(parts)
		var result=TranslationServer.translate(str(value.get("key","")))
		var args=[]
		for arg in value.get("args",[]):args.append(render(arg) if arg is Dictionary else arg)
		return result % args if not args.is_empty() else result
	var source=str(value)
	if source.begins_with(PREFIX):
		var parsed=JSON.parse_string(source.trim_prefix(PREFIX))
		if parsed is Dictionary:return render(parsed)
	return TranslationServer.translate(source)

static func apply(language: int):
	TranslationServer.set_locale("it" if language==1 else "en")

static func update_message(data: Dictionary) -> String:
	var source=str(data.get("message",""))
	match str(data.get("state","")):
		"available":return TranslationServer.translate("Update %s is available.") % str(data.get("version",""))
		"ready":return TranslationServer.translate("Update %s is ready to install.") % str(data.get("version",""))
		"downloading":return TranslationServer.translate("Downloading update…")
		"preparing":return TranslationServer.translate("Verifying and preparing update…")
		"error":
			var translated=TranslationServer.translate(source)
			if translated!=source or TranslationServer.get_locale().begins_with("en"):return translated
			return TranslationServer.translate("The update could not finish. Check your connection, free disk space and folder permissions, then try again.")
	return render(source)
