"""Build the game's reusable, nine-slice storybook interface surfaces."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/ui';OUT.mkdir(exist_ok=True)
def svg(name,body,w=96,h=48):
 (OUT/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n')
svg('parchment-panel','''<defs><linearGradient id="paper" x2="0" y2="1"><stop stop-color="#f8e9c6"/><stop offset="1" stop-color="#ecd3a4"/></linearGradient></defs>
<path d="M12 3 Q6 3 4 11 L3 80 Q3 91 14 93 L82 92 Q92 92 93 81 L92 13 Q92 4 81 3 Z" fill="#513723"/>
<rect x="6" y="6" width="84" height="84" rx="9" fill="#ac7846" stroke="#d2a060" stroke-width="2"/>
<rect x="11" y="11" width="74" height="74" rx="6" fill="url(#paper)" stroke="#704a2b" stroke-width="2"/>
<path d="M18 15 H78 M15 20 V75 M18 82 H76" stroke="#fff4d8" stroke-opacity=".7" fill="none"/>
<path d="M28 33 H49 M44 59 H72 M22 72 H39" stroke="#b2925f" stroke-opacity=".10"/>
<g fill="#e9bc67" stroke="#654225" stroke-width="1"><circle cx="8" cy="8" r="2"/><circle cx="88" cy="8" r="2"/><circle cx="8" cy="88" r="2"/><circle cx="88" cy="88" r="2"/></g>''',96,96)
for name,fill,edge,shine,low in [
 ('button','#e4c18c','#785334','#ffedc3','#bb8d55'),
 ('button-hover','#f2d4a0','#85542c','#fff3d3','#c29354'),
 ('button-pressed','#526747','#2f4532','#8fa26d','#3b5138'),
 ('button-primary','#5f794f','#314831','#a3b782','#435b3e'),
 ('button-primary-hover','#748c5c','#314831','#bfd298','#506b42'),
 ('button-disabled','#d4c4a5','#a29478','#e7dcc5','#bbab8d')]:
 svg(name,f'<rect x="2" y="3" width="92" height="43" rx="9" fill="{low}" stroke="{edge}" stroke-width="2"/><rect x="3" y="3" width="90" height="37" rx="8" fill="{fill}"/><path d="M12 6 H84 Q90 6 90 12" stroke="{shine}" stroke-width="2" fill="none"/><path d="M9 37 Q16 39 23 37 M74 38 H86" stroke="{low}" fill="none"/>')
svg('slider-knob','<circle cx="10" cy="10" r="8" fill="#d4a355" stroke="#694729" stroke-width="2"/><circle cx="10" cy="9" r="5" fill="#f2d48b"/><path d="M8 6 V12 M11 6 V12" stroke="#ad7c3e"/>',20,20)
svg('arrow-down','<path d="M3 5 L9 11 L15 5" fill="none" stroke="#68472b" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>',18,16)
svg('arrow-up','<path d="M3 11 L9 5 L15 11" fill="none" stroke="#68472b" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>',18,16)
for state,on in [('checked',True),('unchecked',False)]:
 fill='#617f50' if on else '#beac8a';x=30 if on else 12
 svg('switch-'+state,f'<rect x="2" y="6" width="38" height="18" rx="9" fill="{fill}" stroke="#6b5135" stroke-width="2"/><circle cx="{x}" cy="15" r="10" fill="#f3d89c" stroke="#795330" stroke-width="2"/><path d="M{x-3} 12 V18 M{x+1} 12 V18" stroke="#ba8e51"/>',44,30)

def color(h):
 vals=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 return 'Color('+', '.join(f'{v:.4f}' for v in vals)+', 1)'
lines=['[gd_resource type="Theme" format=3 uid="uid://cr50xu8k1vr3e"]','',
 '[ext_resource type="FontFile" path="res://assets/fonts/FiraSans-Regular.ttf" id="body"]',
 '[ext_resource type="FontFile" path="res://assets/fonts/FiraSans-Medium.ttf" id="button-font"]',
 '[ext_resource type="FontFile" path="res://assets/fonts/NotoSerif-Medium.ttf" id="heading-font"]']
for name in ['parchment-panel','button','button-hover','button-pressed','button-primary','button-primary-hover','button-disabled','slider-knob','arrow-down','arrow-up','switch-checked','switch-unchecked']:
 lines.append(f'[ext_resource type="Texture2D" path="res://assets/ui/{name}.svg" id="{name}"]')
def texture_style(name,texture,margin=10,padx=12,pady=8):
 lines.extend(['',f'[sub_resource type="StyleBoxTexture" id="{name}"]',f'texture = ExtResource("{texture}")'])
 for edge in ['left','top','right','bottom']:
  lines.append(f'texture_margin_{edge} = {margin}.0')
  lines.append(f'content_margin_{edge} = {padx if edge in ["left","right"] else pady}.0')
texture_style('Panel','parchment-panel',14,16,12)
for name in ['button','button-hover','button-pressed','button-primary','button-primary-hover','button-disabled']:texture_style(name,name)
def flat(name,fill,border='a68658',width=1,radius=7,padx=12,pady=8):
 lines.extend(['',f'[sub_resource type="StyleBoxFlat" id="{name}"]',f'bg_color = {color(fill)}',f'border_color = {color(border)}'])
 for side in ['left','top','right','bottom']:
  lines.extend([f'border_width_{side} = {width}',f'content_margin_{side} = {padx if side in ["left","right"] else pady}.0'])
 for corner in ['top_left','top_right','bottom_left','bottom_right']:lines.append(f'corner_radius_{corner} = {radius}')
flat('Input','fff1d3','b49668',1)
flat('InputFocus','fff5df','6b834f',2)
flat('Popup','f4e2bb','795635',2,8)
flat('Track','b5a07b','91734d',1,3,2,2)
flat('Fill','6d8958','496340',1,3,2,2)
flat('Focus','f2c870','b77633',2,9,0,0)
lines[lines.index('[sub_resource type="StyleBoxFlat" id="Focus"]')+1]='bg_color = Color(0, 0, 0, 0)'
# Compact soundtrack buttons share a small raised parchment tile.
for name,fill in [('MusicIcon','e4c18c'),('MusicIconHover','f2d4a0')]:
 flat(name,fill,'ac8654',1,6,8,4)
 lines.extend(['shadow_color = Color(0.18, 0.1, 0.04, 0.18)','shadow_size = 3','shadow_offset = Vector2(0, 2)'])
lines.extend(['','[resource]','default_font = ExtResource("body")','default_font_size = 16'])
def prop(key,value):lines.append(key+' = '+value)
for typ in ['Button','OptionButton','CheckButton','CheckBox']:
 for key,h in [('font_color','493521'),('font_hover_color','392818'),('font_pressed_color','fff1d2'),('font_hover_pressed_color','fff6df'),('font_disabled_color','8b7b63')]:prop(f'{typ}/colors/{key}',color(h))
 for key,h in [('icon_normal_color','493521'),('icon_hover_color','392818'),('icon_pressed_color','fff1d2'),('icon_hover_pressed_color','fff6df'),('icon_disabled_color','8b7b63')]:prop(f'{typ}/colors/{key}',color(h))
 prop(f'{typ}/fonts/font','ExtResource("button-font")')
 for state,style in [('normal','button'),('hover','button-hover'),('pressed','button-pressed'),('hover_pressed','button-pressed'),('disabled','button-disabled'),('focus','Focus')]:prop(f'{typ}/styles/{state}',f'SubResource("{style}")')
prop('PrimaryButton/base_type','&"Button"')
for key in ['font_color','font_hover_color','font_pressed_color','icon_normal_color','icon_hover_color']:prop('PrimaryButton/colors/'+key,color('fff1d2'))
for state,style in [('normal','button-primary'),('hover','button-primary-hover'),('pressed','button-pressed')]:prop('PrimaryButton/styles/'+state,f'SubResource("{style}")')
prop('MusicIconButton/base_type','&"Button"')
for state,style in [('normal','MusicIcon'),('hover','MusicIconHover'),('pressed','MusicIconHover')]:prop('MusicIconButton/styles/'+state,f'SubResource("{style}")')
prop('Label/colors/font_color',color('493521'))
prop('HeadingLabel/base_type','&"Label"')
prop('HeadingLabel/fonts/font','ExtResource("heading-font")')
for key,h in [('font_color','493521'),('font_placeholder_color','8a775c'),('caret_color','526747'),('selection_color','b4c696')]:prop('LineEdit/colors/'+key,color(h))
prop('LineEdit/styles/normal','SubResource("Input")');prop('LineEdit/styles/focus','SubResource("InputFocus")')
prop('PanelContainer/styles/panel','SubResource("Panel")')
prop('PopupPanel/styles/panel','SubResource("Popup")')
prop('PopupMenu/styles/panel','SubResource("Popup")');prop('PopupMenu/styles/hover','SubResource("button-hover")')
for key,h in [('font_color','493521'),('font_hover_color','392818'),('font_disabled_color','8b7b63')]:prop('PopupMenu/colors/'+key,color(h))
prop('OptionButton/icons/arrow','ExtResource("arrow-down")')
# Match number steppers to the existing dropdown chevrons and day/night palette.
for direction in ['up','down']:
 for state in ['', '_hover', '_pressed', '_disabled']:
  prop('SpinBox/icons/'+direction+state, f'ExtResource("arrow-{direction}")')
  prop('SpinBox/colors/'+direction+state+'_icon_modulate','Color(1, 1, 1, 0.45)' if state=='_disabled' else 'Color(1, 1, 1, 1)')
prop('SpinBox/constants/buttons_width','28')
prop('SpinBox/constants/field_and_buttons_separation','4')
for state in ['checked','unchecked']:
 for variant in [state,state+'_disabled']:prop('CheckButton/icons/'+variant,f'ExtResource("switch-{state}")')
for typ in ['HSlider','VSlider']:
 for key in ['grabber','grabber_highlight','grabber_disabled']:prop(typ+'/icons/'+key,'ExtResource("slider-knob")')
 for state,style in [('slider','Track'),('grabber_area','Fill'),('grabber_area_highlight','Fill')]:prop(typ+'/styles/'+state,f'SubResource("{style}")')
for typ in ['HScrollBar','VScrollBar']:
 for state,style in [('scroll','Track'),('grabber','Fill'),('grabber_highlight','Fill'),('grabber_pressed','Fill')]:prop(typ+'/styles/'+state,f'SubResource("{style}")')
prop('ProgressBar/styles/background','SubResource("Track")');prop('ProgressBar/styles/fill','SubResource("Fill")')
prop('TooltipPanel/styles/panel','SubResource("Popup")');prop('TooltipLabel/colors/font_color',color('493521'))
prop('HBoxContainer/constants/separation','8');prop('VBoxContainer/constants/separation','8')
# Resource identifiers accept underscores; asset filenames keep their hyphens.
text='\n'.join(lines)+'\n'
text=re.sub(r'(id="|(?:ExtResource|SubResource)\(")([^"]+)',lambda m:m[1]+m[2].replace('-','_'),text)
(ROOT/'assets/ui_theme.tres').write_text(text)
