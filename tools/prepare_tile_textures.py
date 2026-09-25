"""Create runtime texture tiers and packed occlusion/roughness maps."""
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[1]/'assets/materials'
# Only the maps tile_art.gd samples. Ground uses all three, cliffs skip orm,
# and model surfaces read albedo only.
SURFACE=['albedo']
USED={'forest_ground_04':['albedo','normal','orm'],'brown_mud_dry':['albedo','normal','orm'],
    'leafy_grass':['albedo','normal','orm'],'rock_ground':['albedo','normal','orm'],
    'red_sand':['albedo','normal','orm'],'rock_boulder_dry':['albedo','normal'],
    'pine_bark':SURFACE,'weathered_brown_planks':SURFACE}
for directory in sorted(ROOT.iterdir()):
    if directory.name not in USED: continue
    maps=USED[directory.name]
    for size in [512,1024,2048]:
        out=ROOT/'runtime'/str(size)/directory.name
        out.mkdir(parents=True,exist_ok=True)
        for channel in [c for c in ['albedo','normal'] if c in maps]:
            image=Image.open(directory/(channel+'.jpg')).convert('RGB').resize((size,size),Image.Resampling.LANCZOS)
            image.save(out/(channel+'.jpg'),quality=93,subsampling=0)
        if 'orm' not in maps: continue
        ao=Image.open(directory/'ao.jpg').convert('L').resize((size,size),Image.Resampling.LANCZOS)
        rough=Image.open(directory/'roughness.jpg').convert('L').resize((size,size),Image.Resampling.LANCZOS)
        Image.merge('RGB',(ao,rough,Image.new('L',(size,size),0))).save(out/'orm.jpg',quality=93,subsampling=0)
    print('Prepared',directory.name,flush=True)

# Runtime shader-bound maps are not automatically detected as 3D textures.
for p in (ROOT/'runtime').rglob('*.jpg.import'):
    s=p.read_text().replace('mipmaps/generate=false','mipmaps/generate=true').replace('compress/mode=0','compress/mode=2').replace('compress/high_quality=false','compress/high_quality=true')
    if p.name=='normal.jpg.import':s=s.replace('compress/normal_map=0','compress/normal_map=1')
    p.write_text(s)
