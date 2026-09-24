extends SceneTree
## Renders the resource icons for harbor signboards: 256 px, with a cream
## sticker outline so each reads against the sign's dark paint. Run with
## godot --headless --path . --script tools/build_sign_icons.gd

const SIZE=256
const OUTLINE=9
const CREAM=Color("f3e6c4")

func _init():
	for key in CatanIcons.RESOURCES:
		var art=Image.new()
		# Draw the vector icon inside the outline's margin.
		art.load_svg_from_string(FileAccess.get_file_as_string("res://assets/icons/%s.svg" % key),float(SIZE-2*OUTLINE)/64.0)
		var sticker=Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
		for y in SIZE:
			for x in SIZE:
				var cover=0.0
				for dy in range(-OUTLINE,OUTLINE+1,2):
					for dx in range(-OUTLINE,OUTLINE+1,2):
						if dx*dx+dy*dy>OUTLINE*OUTLINE:continue
						var sx=x-OUTLINE+dx;var sy=y-OUTLINE+dy
						if sx<0 or sy<0 or sx>=art.get_width() or sy>=art.get_height():continue
						cover=maxf(cover,art.get_pixel(sx,sy).a)
						if cover>=1.0:break
					if cover>=1.0:break
				sticker.set_pixel(x,y,Color(CREAM,cover))
		sticker.blend_rect(art,Rect2i(Vector2i.ZERO,art.get_size()),Vector2i(OUTLINE,OUTLINE))
		sticker.save_png("res://assets/icons/sign/%s.png" % key)
		print("sign icon ",key)
	quit()
