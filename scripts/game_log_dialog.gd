extends CatanDialog
## The latest entries of the shared game log.

func show_log(lines: Array):
	var template: Label=%Lines.get_node("LineTemplate")
	for line in lines.slice(maxi(0,lines.size()-30)):
		var entry: Label=template.duplicate()
		entry.text=CatanI18n.render(line)
		entry.show()
		%Lines.add_child(entry)
