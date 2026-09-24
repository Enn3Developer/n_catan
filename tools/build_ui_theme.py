"""Build the game's reusable, nine-slice storybook interface surfaces.

Every surface is drawn in day colors. At night `scripts/ui_day_night.gd` remaps
flat colors through its palette and runs textures through the night shader, so
flat styles here may only use colors that palette knows.

Nine-slice textures stretch their middle, so decoration stays inside the
margins: a stroke that crosses the middle smears into a bar across the panel.
"""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/ui';OUT.mkdir(exist_ok=True)
def svg(name,body,w=96,h=48):
 (OUT/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n')

# Framed parchment: dark rim, carved wooden frame, brass studs and plain paper.
svg('parchment-panel','''<defs><linearGradient id="paper" x2="0" y2="1"><stop stop-color="#f8e9c6"/><stop offset="1" stop-color="#ecd3a4"/></linearGradient></defs>
<path d="M12 3 Q6 3 4 11 L3 80 Q3 91 14 93 L82 92 Q92 92 93 81 L92 13 Q92 4 81 3 Z" fill="#513723"/>
<rect x="6" y="6" width="84" height="84" rx="9" fill="#ac7846" stroke="#d2a060" stroke-width="2"/>
<rect x="11" y="11" width="74" height="74" rx="6" fill="url(#paper)" stroke="#704a2b" stroke-width="2"/>
<g fill="#e9bc67" stroke="#654225" stroke-width="1"><circle cx="8" cy="8" r="2"/><circle cx="88" cy="8" r="2"/><circle cx="8" cy="88" r="2"/><circle cx="88" cy="88" r="2"/></g>''',96,96)

# Wooden buttons stand on a darker lip; pressed and selected ones sink into it.
# The face brightens toward its top edge; a gradient has no line to stretch into a bar.
def raised(fill,edge,shine,low):
 face=f'f{fill[1:]}'
 return f'<defs><linearGradient id="{face}" x2="0" y2="1"><stop stop-color="{shine}"/><stop offset=".45" stop-color="{fill}"/></linearGradient></defs><rect x="2" y="3" width="92" height="43" rx="9" fill="{low}" stroke="{edge}" stroke-width="2"/><rect x="3" y="3" width="90" height="37" rx="8" fill="url(#{face})"/>'
# Pressed and selected planks drop their lip: one flat piece of wood with a soft
# glow along the bottom edge instead of a shadow line.
def sunken(fill,edge,glow):
 return f'<rect x="2" y="3" width="92" height="43" rx="9" fill="{fill}" stroke="{edge}" stroke-width="2"/><path d="M12 42 H84" stroke="{glow}" stroke-width="2" stroke-opacity=".6" fill="none"/>'
for name,body in [
 ('button',raised('#e4c18c','#785334','#ffedc3','#bb8d55')),
 ('button-hover',raised('#f2d4a0','#85542c','#fff3d3','#c29354')),
 ('button-selected',sunken('#e9bf73','#85542c','#fbe3a8')),
 ('button-primary',raised('#5f794f','#314831','#a3b782','#435b3e')),
 ('button-primary-hover',raised('#748c5c','#314831','#bfd298','#506b42')),
 ('button-primary-pressed',sunken('#526747','#2f4532','#8fa26d')),
 ('button-disabled',f'<rect x="2" y="3" width="92" height="43" rx="9" fill="#bbab8d" stroke="#a29478" stroke-width="2"/><rect x="3" y="3" width="90" height="37" rx="8" fill="#d4c4a5"/>')]:
 svg(name,body)
# Knobs are plain brass buttons; grip lines on them read as a pause symbol.
svg('slider-knob','<circle cx="10" cy="10" r="8" fill="#d4a355" stroke="#694729" stroke-width="2"/><circle cx="10" cy="9" r="5" fill="#f2d48b"/><circle cx="8.5" cy="7.5" r="1.6" fill="#fff3d3"/>',20,20)
svg('arrow-down','<path d="M3 5 L9 11 L15 5" fill="none" stroke="#68472b" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>',18,16)
svg('arrow-up','<path d="M3 11 L9 5 L15 11" fill="none" stroke="#68472b" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>',18,16)
for state,on in [('checked',True),('unchecked',False)]:
 fill='#617f50' if on else '#beac8a';x=30 if on else 12
 svg('switch-'+state,f'<rect x="2" y="6" width="38" height="18" rx="9" fill="{fill}" stroke="#6b5135" stroke-width="2"/><circle cx="{x}" cy="15" r="10" fill="#f3d89c" stroke="#795330" stroke-width="2"/><circle cx="{x-3}" cy="12" r="2" fill="#fff3d3"/>',44,30)
 tick='<path d="M6 12.5 L10 16.5 L18 7.5" fill="none" stroke="#f6e7c4" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>' if on else ''
 svg('checkbox-'+state,f'<rect x="2" y="2" width="20" height="20" rx="5" fill="{"#617f50" if on else "#fff1d3"}" stroke="#6b5135" stroke-width="2"/>{tick}',24,24)
 dot='<circle cx="12" cy="12" r="4.5" fill="#f6e7c4"/>' if on else ''
 svg('radio-'+state,f'<circle cx="12" cy="12" r="10" fill="{"#617f50" if on else "#fff1d3"}" stroke="#6b5135" stroke-width="2"/>{dot}',24,24)

def color(h,a=1):
 vals=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 return 'Color('+', '.join(f'{v:.4f}' for v in vals)+f', {a})'
TEXTURES=['parchment-panel','button','button-hover','button-selected','button-primary','button-primary-hover','button-primary-pressed','button-disabled','slider-knob','arrow-down','arrow-up','switch-checked','switch-unchecked','checkbox-checked','checkbox-unchecked','radio-checked','radio-unchecked']
lines=['[gd_resource type="Theme" format=3 uid="uid://cr50xu8k1vr3e"]','',
 '[ext_resource type="FontFile" path="res://assets/fonts/FiraSans-Regular.ttf" id="body"]',
 '[ext_resource type="FontFile" path="res://assets/fonts/FiraSans-Medium.ttf" id="button-font"]',
 '[ext_resource type="FontFile" path="res://assets/fonts/NotoSerif-Medium.ttf" id="heading-font"]']
for name in TEXTURES:
 lines.append(f'[ext_resource type="Texture2D" path="res://assets/ui/{name}.svg" id="{name}"]')
def texture_style(name,texture,margin=10,padx=16,pady=9):
 lines.extend(['',f'[sub_resource type="StyleBoxTexture" id="{name}"]',f'texture = ExtResource("{texture}")'])
 for edge in ['left','top','right','bottom']:
  lines.append(f'texture_margin_{edge} = {margin}.0')
  lines.append(f'content_margin_{edge} = {padx if edge in ["left","right"] else pady}.0')
# The carved frame is 14 px deep, so content starts well inside it.
texture_style('Panel','parchment-panel',14,28,24)
# HUD bars sit over the board and keep a slimmer inset.
texture_style('Bar','parchment-panel',14,24,16)
BUTTONS=['button','button-hover','button-selected','button-primary','button-primary-hover','button-primary-pressed','button-disabled']
for name in BUTTONS:
 texture_style(name,name)
 # Icon-only buttons share the wood but keep their glyph close to the frame.
 texture_style(name+'-icon',name,10,9,8)
def flat(name,fill,border=None,width=1,radius=8,padx=12,pady=8,alpha=1):
 lines.extend(['',f'[sub_resource type="StyleBoxFlat" id="{name}"]',f'bg_color = {color(fill,alpha)}'])
 if border:lines.append(f'border_color = {color(border)}')
 for side in ['left','top','right','bottom']:
  if border:lines.append(f'border_width_{side} = {width}')
  lines.append(f'content_margin_{side} = {padx if side in ["left","right"] else pady}.0')
 for corner in ['top_left','top_right','bottom_left','bottom_right']:lines.append(f'corner_radius_{corner} = {radius}')
def shadow():lines.extend(['shadow_color = Color(0.18, 0.1, 0.04, 0.18)','shadow_size = 3','shadow_offset = Vector2(0, 2)'])
flat('Input','fff1d3','b49668',1)
flat('InputFocus','fff5df','6b834f',2)
flat('InputReadOnly','eedab0','b49668',1)
flat('Popup','f4e2bb','795635',2,8,12,8)
flat('Track','b5a07b','91734d',1,3,2,2)
flat('Fill','6d8958','496340',1,3,2,2)
flat('ScrollTrack','eedab0',None,1,5,5,5)
flat('ScrollGrabber','ac8654',None,1,5,5,5)
flat('ScrollGrabberHover','8c522d',None,1,5,5,5)
flat('Focus','fff1d3','b77633',2,9,0,0,0)
flat('Empty','fff1d3',None,1,0,4,4,0)
# Cards are raised tiles inside a panel; rows are flat bands in a list.
flat('Card','f6e4be','ac8654',1,10,16,12);shadow()
flat('Row','eedab0',None,1,8,16,10)
flat('RowPlain','eedab0',None,1,8,16,10,0)
flat('Separator','ac8654',None,1,0,0,4,.45)
lines.extend(['','[resource]','default_font = ExtResource("body")','default_font_size = 16'])
def prop(key,value):lines.append(key+' = '+value)
INK,INK_HOVER,MUTED,DISABLED,LIGHT='493521','392818','796347','8b7b63','fff1d2'
def text_colors(typ,pressed):
 for key,h in [('font_color',INK),('font_hover_color',INK_HOVER),('font_pressed_color',pressed),('font_hover_pressed_color',pressed),('font_focus_color',INK),('font_disabled_color',DISABLED)]:prop(f'{typ}/colors/{key}',color(h))
 for key,h in [('icon_normal_color',INK),('icon_hover_color',INK_HOVER),('icon_pressed_color',pressed),('icon_hover_pressed_color',pressed),('icon_focus_color',INK),('icon_disabled_color',DISABLED)]:prop(f'{typ}/colors/{key}',color(h))
def button_styles(typ,normal,hover,pressed,suffix=''):
 for state,style in [('normal',normal),('hover',hover),('pressed',pressed),('hover_pressed',pressed),('disabled','button-disabled')]:prop(f'{typ}/styles/{state}',f'SubResource("{style}{suffix}")')
 prop(f'{typ}/styles/focus','SubResource("Focus")')
# Pressed and toggled buttons sink into honey wood; green is kept for the one primary action.
for typ in ['Button','OptionButton']:
 text_colors(typ,INK)
 prop(f'{typ}/fonts/font','ExtResource("button-font")')
 button_styles(typ,'button','button-hover','button-selected')
 prop(f'{typ}/constants/h_separation','8')
prop('PrimaryButton/base_type','&"Button"')
for key in ['font_color','font_hover_color','font_pressed_color','font_hover_pressed_color','font_focus_color','icon_normal_color','icon_hover_color','icon_pressed_color','icon_hover_pressed_color','icon_focus_color']:prop('PrimaryButton/colors/'+key,color(LIGHT))
button_styles('PrimaryButton','button-primary','button-primary-hover','button-primary-pressed')
prop('IconButton/base_type','&"Button"')
button_styles('IconButton','button','button-hover','button-selected','-icon')
prop('IconButton/constants/icon_max_width','20')
# List rows: bare until hovered, honey when chosen.
prop('ListButton/base_type','&"Button"')
for state,style in [('normal','RowPlain'),('hover','Row'),('pressed','button-selected'),('hover_pressed','button-selected'),('disabled','RowPlain'),('focus','Focus')]:prop('ListButton/styles/'+state,f'SubResource("{style}")')
prop('ListButton/fonts/font','ExtResource("body")')
# Switches and checkboxes draw only their own glyph and label, never a button frame.
for typ in ['CheckButton','CheckBox']:
 text_colors(typ,INK)
 for state in ['normal','hover','pressed','hover_pressed','disabled']:prop(f'{typ}/styles/{state}','SubResource("Empty")')
 prop(f'{typ}/styles/focus','SubResource("Focus")')
 prop(f'{typ}/constants/h_separation','10')
for state in ['checked','unchecked']:
 for variant in [state,state+'_disabled']:
  prop('CheckButton/icons/'+variant,f'ExtResource("switch-{state}")')
  prop('CheckBox/icons/'+variant,f'ExtResource("checkbox-{state}")')
  prop('CheckBox/icons/radio_'+variant,f'ExtResource("radio-{state}")')
prop('Label/colors/font_color',color(INK))
prop('HeadingLabel/base_type','&"Label"')
prop('HeadingLabel/fonts/font','ExtResource("heading-font")')
prop('SectionLabel/base_type','&"Label"')
prop('SectionLabel/fonts/font','ExtResource("button-font")')
prop('SectionLabel/font_sizes/font_size','14')
prop('SectionLabel/colors/font_color',color('8c522d'))
prop('MutedLabel/base_type','&"Label"')
prop('MutedLabel/font_sizes/font_size','14')
prop('MutedLabel/colors/font_color',color(MUTED))
prop('ErrorLabel/base_type','&"Label"');prop('ErrorLabel/colors/font_color',color('a8402f'))
# Toasts are one-line cards over the board.
prop('ToastLabel/base_type','&"Label"');prop('ToastLabel/styles/normal','SubResource("Card")');prop('ToastLabel/colors/font_color',color('8c522d'))
for key,h in [('font_color',INK),('font_uneditable_color',INK),('font_placeholder_color','8a775c'),('caret_color','526747'),('selection_color','b4c696'),('clear_button_color',MUTED),('clear_button_color_pressed',INK)]:prop('LineEdit/colors/'+key,color(h))
prop('LineEdit/styles/normal','SubResource("Input")');prop('LineEdit/styles/focus','SubResource("InputFocus")');prop('LineEdit/styles/read_only','SubResource("InputReadOnly")')
prop('PanelContainer/styles/panel','SubResource("Panel")')
prop('BarPanel/base_type','&"PanelContainer"');prop('BarPanel/styles/panel','SubResource("Bar")')
prop('Card/base_type','&"PanelContainer"');prop('Card/styles/panel','SubResource("Card")')
prop('Row/base_type','&"PanelContainer"');prop('Row/styles/panel','SubResource("Row")')
prop('PlainRow/base_type','&"PanelContainer"');prop('PlainRow/styles/panel','SubResource("RowPlain")')
prop('PopupPanel/styles/panel','SubResource("Popup")')
prop('PopupMenu/styles/panel','SubResource("Popup")');prop('PopupMenu/styles/hover','SubResource("Row")')
prop('PopupMenu/styles/separator','SubResource("Separator")')
prop('PopupMenu/constants/v_separation','10');prop('PopupMenu/constants/item_start_padding','10');prop('PopupMenu/constants/item_end_padding','10')
for key,h in [('font_color',INK),('font_hover_color',INK_HOVER),('font_disabled_color',DISABLED),('font_separator_color',MUTED)]:prop('PopupMenu/colors/'+key,color(h))
for icon in ['checked','unchecked','radio_checked','radio_unchecked']:
 prop('PopupMenu/icons/'+icon,f'ExtResource("{"radio" if icon.startswith("radio") else "checkbox"}-{icon.replace("radio_","")}")')
prop('OptionButton/icons/arrow','ExtResource("arrow-down")')
prop('OptionButton/constants/arrow_margin','10')
# Number steppers reuse the dropdown chevrons.
for direction in ['up','down']:
 for state in ['', '_hover', '_pressed', '_disabled']:
  prop('SpinBox/icons/'+direction+state, f'ExtResource("arrow-{direction}")')
  prop('SpinBox/colors/'+direction+state+'_icon_modulate','Color(1, 1, 1, 0.45)' if state=='_disabled' else 'Color(1, 1, 1, 1)')
prop('SpinBox/constants/buttons_width','28')
prop('SpinBox/constants/field_and_buttons_separation','4')
for typ in ['HSlider','VSlider']:
 for key in ['grabber','grabber_highlight','grabber_disabled']:prop(typ+'/icons/'+key,'ExtResource("slider-knob")')
 for state,style in [('slider','Track'),('grabber_area','Fill'),('grabber_area_highlight','Fill')]:prop(typ+'/styles/'+state,f'SubResource("{style}")')
for typ in ['HScrollBar','VScrollBar']:
 for state,style in [('scroll','ScrollTrack'),('scroll_focus','ScrollTrack'),('grabber','ScrollGrabber'),('grabber_highlight','ScrollGrabberHover'),('grabber_pressed','ScrollGrabberHover')]:prop(typ+'/styles/'+state,f'SubResource("{style}")')
for typ in ['HSeparator','VSeparator']:
 prop(typ+'/styles/separator','SubResource("Separator")');prop(typ+'/constants/separation','12')
prop('ProgressBar/styles/background','SubResource("Track")');prop('ProgressBar/styles/fill','SubResource("Fill")')
prop('TooltipPanel/styles/panel','SubResource("Popup")');prop('TooltipLabel/colors/font_color',color(INK))
prop('HBoxContainer/constants/separation','8');prop('VBoxContainer/constants/separation','8')
# Even gaps everywhere, and room between scrolled content and its scrollbar.
prop('GridContainer/constants/h_separation','12');prop('GridContainer/constants/v_separation','10')
for typ in ['HFlowContainer','VFlowContainer']:prop(typ+'/constants/h_separation','8');prop(typ+'/constants/v_separation','8')
prop('ScrollContainer/constants/scrollbar_h_separation','10');prop('ScrollContainer/constants/scrollbar_v_separation','10')
# Resource identifiers accept underscores; asset filenames keep their hyphens.
text='\n'.join(lines)+'\n'
text=re.sub(r'(id="|(?:ExtResource|SubResource)\(")([^"]+)',lambda m:m[1]+m[2].replace('-','_'),text)
(ROOT/'assets/ui_theme.tres').write_text(text)
