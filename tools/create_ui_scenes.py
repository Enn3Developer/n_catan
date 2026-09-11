"""Author the editable, container-based native Godot UI scenes."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
FULL='layout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2'
class Scene:
 def __init__(self,name,script=None):
  self.lines=['[gd_scene format=3]','[ext_resource type="Theme" path="res://assets/ui_theme.tres" id="1"]']
  if script:self.lines += [f'[ext_resource type="Script" path="res://scripts/{script}" id="2"]']
  self.lines += [f'[node name="{name}" type="Control"]',FULL,'mouse_filter = 2','theme = ExtResource("1")']
  if script:self.lines += ['script = ExtResource("2")']
 def node(self,name,typ,parent='.',props='',unique=True):
  self.lines += [f'\n[node name="{name}" type="{typ}" parent="{parent}"]']
  if unique:self.lines += ['unique_name_in_owner = true']
  self.lines += ['layout_mode = 2',props]
  return name if parent=='.' else parent+'/'+name
 def label(self,name,text,parent='.',size=16,props=''):
  return self.node(name,'Label',parent,f'text = "{text}"\ntheme_override_font_sizes/font_size = {size}\n'+props)
 def button(self,name,text,parent='.',props=''):
  return self.node(name,'Button',parent,f'text = "{text}"\ncustom_minimum_size = Vector2(0, 40)\n'+props)
 def full(self,name,typ,parent='.',margin=16,props=''):
  return self.node(name,typ,parent,FULL+f'\noffset_left = {margin}.0\noffset_top = {margin}.0\noffset_right = -{margin}.0\noffset_bottom = -{margin}.0\n'+props)
 def save(self,file):
  # Later explicit layout_mode wins in source authoring; normalize duplicates.
  result=[]
  for block in '\n'.join(self.lines).split('\n[node '):
   lines=block.splitlines();found=set();keep=[]
   for line in reversed(lines):
    key=line.split(' = ')[0]
    if ' = ' in line and key in found:continue
    if ' = ' in line:found.add(key)
    keep.append(line)
   result.append('\n'.join(reversed(keep)))
  (root/'scenes/ui'/file).write_text('\n[node '.join(result)+'\n')
s=Scene('MainMenu')
p=s.node('Expedition','PanelContainer',props='layout_mode = 1\nanchor_top = 0.5\nanchor_bottom = 0.5\noffset_left = 24.0\noffset_top = -240.0\noffset_right = 390.0\noffset_bottom = 240.0')
b=s.node('ExpeditionBody','VBoxContainer',p,'theme_override_constants/separation = 10')
s.label('Brand','T I D E S  &  T I M B E R',b,13)
s.label('Title','CATAN',b,62)
s.node('MenuScroll','ScrollContainer',b,'size_flags_vertical = 3\nhorizontal_scroll_mode = 0')
items=s.node('MenuItems','VBoxContainer',b+'/MenuScroll','size_flags_horizontal = 3\ntheme_override_constants/separation = 10')
s.node('PlayerName','LineEdit',items,'placeholder_text = "Your name"\nmax_length = 20\ncustom_minimum_size = Vector2(0, 40)')
s.button('Singleplayer','Play solo',items)
s.button('Learn','Learn to play',items)
s.button('OpenCosmetics','Piece cosmetics',items,'tooltip_text = "Preview and equip your roads, settlements and cities"')
s.button('ShowOnline','Play online',items,'toggle_mode = true')
form=s.node('OnlineForm','VBoxContainer',items,'visible = false')
s.node('ServerAddress','LineEdit',form,'placeholder_text = "Server address"\ncustom_minimum_size = Vector2(0, 40)')
s.node('RoomPassword','LineEdit',form,'placeholder_text = "Password (optional)"\nmax_length = 64\nsecret = true\ncustom_minimum_size = Vector2(0, 40)')
row=s.node('OnlineButtons','HBoxContainer',form)
s.button('HostOnline','Host room',row,'size_flags_horizontal = 3')
s.button('JoinOnline','Join room',row,'size_flags_horizontal = 3')
s.button('Reconnect','Reconnect',items,'visible = false')
s.label('MenuNote','3–6 players · Solo & online',b,13)
s.button('OpenSettings','',props='layout_mode = 1\nanchor_left = 1.0\nanchor_right = 1.0\noffset_left = -64.0\noffset_top = 24.0\noffset_right = -24.0\noffset_bottom = 64.0\ntooltip_text = "Settings"')
s.save('home.tscn')

s=Scene('GameHUD')
p=s.node('Top','PanelContainer',props='layout_mode = 1\nanchor_right = 1.0\noffset_left = 16.0\noffset_top = 12.0\noffset_right = -16.0\noffset_bottom = 66.0')
s.node('TopBody','VBoxContainer',p)
p=s.node('Players','Control',props='layout_mode = 1\nanchor_right = 1.0\noffset_left = 16.0\noffset_top = 76.0\noffset_right = -16.0\noffset_bottom = 122.0\nmouse_filter = 2')
s.node('PlayersBody','HFlowContainer',p,FULL+'\ntheme_override_constants/h_separation = 6\ntheme_override_constants/v_separation = 6')
p=s.node('Bottom','PanelContainer',props='layout_mode = 1\nanchor_top = 1.0\nanchor_bottom = 1.0\nanchor_right = 1.0\noffset_left = 16.0\noffset_top = -152.0\noffset_right = -16.0\noffset_bottom = -12.0\ngrow_vertical = 0')
b=s.node('BottomBody','VBoxContainer',p,'theme_override_constants/separation = 8')
row=s.node('Hand','HBoxContainer',b,'theme_override_constants/separation = 18')
s.node('HandBody','VBoxContainer',row,'size_flags_horizontal = 3')
s.label('Instruction','',row,15,'size_flags_horizontal = 3\nautowrap_mode = 3')
s.node('ActionsBody','HFlowContainer',b,'theme_override_constants/h_separation = 8\ntheme_override_constants/v_separation = 6\nalignment = 1')
s.save('hud.tscn')

s=Scene('Lobby')
p=s.full('Frame','VBoxContainer',margin=24,props='theme_override_constants/separation = 16')
h=s.node('Header','HBoxContainer',p)
s.label('LobbyTitle','Your room',h,30,'size_flags_horizontal = 3')
s.button('LobbyCosmetics','Piece cosmetics',h)
s.button('LobbySettings','',h,'custom_minimum_size = Vector2(40, 40)\ntooltip_text = "Settings"')
cols=s.node('Columns','HBoxContainer',p,'size_flags_vertical = 3\ntheme_override_constants/separation = 18')
c=s.node('Crew','PanelContainer',cols,'size_flags_horizontal = 3')
b=s.node('CrewBody','VBoxContainer',c)
h=s.node('CrewHeader','HBoxContainer',b)
s.label('CrewTitle','Players',h,18,'size_flags_horizontal = 3')
s.label('PlayerCount','1 / 6',h)
sc=s.node('CrewScroll','ScrollContainer',b,'size_flags_vertical = 3\nhorizontal_scroll_mode = 0')
s.node('PlayerSlots','VBoxContainer',sc,'size_flags_horizontal = 3\ntheme_override_constants/separation = 8')
h=s.node('CrewActions','HBoxContainer',b)
s.button('AddBot','+ Add bot',h,'size_flags_horizontal = 3')
s.button('ReadyButton',"I'm ready",h,'size_flags_horizontal = 3')
c=s.node('Voyage','PanelContainer',cols,'custom_minimum_size = Vector2(280, 0)')
b=s.node('VoyageBody','VBoxContainer',c)
s.label('RoomType','Online',b,14)
s.label('RoomSummary','Classic · 19 hexes',b,22,'autowrap_mode = 3')
s.label('InviteHeading','Invite friends',b,16)
s.node('InviteAddress','LineEdit',b,'placeholder_text = "Public address:24567"\ncustom_minimum_size = Vector2(0, 40)')
h=s.node('InviteActions','HBoxContainer',b)
s.button('CopyInvite','Copy address',h,'size_flags_horizontal = 3')
s.button('MapRouter','Map router',h,'size_flags_horizontal = 3')
s.label('ConnectionHelp','',b,14,'autowrap_mode = 3')
s.node('FlexibleSpace','Control',b,'size_flags_vertical = 3')
s.label('LobbyStatus','',b,15,'autowrap_mode = 3')
s.button('StartGame','Start game',b)
s.button('LeaveRoom','Back',b)
s.save('lobby.tscn')

s=Scene('Settings','settings_menu.gd')
s.full('Shade','ColorRect',margin=0,props='color = Color(0.015, 0.026, 0.035, 0.94)')
p=s.full('SettingsPanel','PanelContainer',margin=20)
b=s.node('Body','VBoxContainer',p,'theme_override_constants/separation = 12')
s.label('Title','Settings',b,30)
s.node('Navigation','HFlowContainer',b,'theme_override_constants/h_separation = 8\ntheme_override_constants/v_separation = 6')
cols=s.node('Columns','HBoxContainer',b,'size_flags_vertical = 3\ntheme_override_constants/separation = 20')
s.node('SettingsContent','VBoxContainer',cols,'size_flags_horizontal = 3')
h=s.node('Help','VBoxContainer',cols,'custom_minimum_size = Vector2(240, 0)\ntheme_override_constants/separation = 14')
for name,text,size in [('RendererInfo','',13),('HelpTitle','',23),('HelpBody','',16),('HelpCost','',14)]:s.label(name,text,h,size,'autowrap_mode = 3')
s.node('Spacer','Control',h,'size_flags_vertical = 3')
s.label('Performance','',h,14)
h=s.node('Buttons','HBoxContainer',b)
s.button('ResetSettings','Restore defaults',h)
s.label('SettingsNote','Saved automatically',h,13,'size_flags_horizontal = 3\nhorizontal_alignment = 1\nautowrap_mode = 3')
s.button('CloseSettings','Done',h,'custom_minimum_size = Vector2(100, 40)')
s.save('settings.tscn')

s=Scene('Tutorial')
p=s.node('LessonPanel','PanelContainer',props='layout_mode = 1\nanchor_right = 1.0\noffset_left = 24.0\noffset_top = 132.0\noffset_right = -24.0\noffset_bottom = 292.0')
b=s.node('LessonPanelBody','VBoxContainer',p,'theme_override_constants/separation = 6')
h=s.node('LessonHeader','HBoxContainer',b)
s.label('Progress','1 / 10',h,13,'size_flags_horizontal = 3')
s.label('LessonStatus','Practice',h,13)
s.label('LessonTitle','Welcome',b,22)
s.label('LessonBody','Learn by building.',b,15,'autowrap_mode = 3')
h=s.node('LessonButtons','HBoxContainer',b)
s.button('PreviousLesson','Previous',h)
s.button('RestartLesson','Retry',h)
s.button('SkipLesson','Skip',h)
s.node('Spacer','Control',h,'size_flags_horizontal = 3')
s.button('NextLesson','Continue',h)
s.save('tutorial.tscn')
