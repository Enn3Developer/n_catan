class_name CatanScreen
extends Control
## A full-window screen hosted by main.gd. Screens fit themselves to the window
## and report the part of it the board camera should frame.

## Emitted when the screen's content size changes and it needs to be arranged again.
signal layout_changed

## Top edge of the notification column while this screen is shown.
var notifications_top:=72.0
## Gap between the window's bottom edge and the toast.
var toast_bottom:=20.0

func arrange(viewport: Vector2,_overlay_bottom: float) -> Rect2:
	return Rect2(Vector2.ZERO,viewport)

## Where overlays such as the tutorial lesson may sit. Only the left, top and width are used.
func overlay_area(viewport: Vector2) -> Rect2:
	return Rect2(24,132,viewport.x-48,0)
