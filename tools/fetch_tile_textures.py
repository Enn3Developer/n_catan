"""Fetch the selected CC0 Poly Haven PBR maps; no runtime network dependency."""
import concurrent.futures, hashlib, json, pathlib, urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[1]
DEST=ROOT/'assets'/'materials'
ASSETS=['forest_ground_04','leafy_grass','brown_mud_dry','red_sand','rock_face','rock_ground','pine_bark','weathered_brown_planks','rock_boulder_dry']
def get(url):
    return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'CatanTileArt/1.0 (local asset authoring)'}),timeout=50).read()
def fetch(asset):
    meta=json.loads(get('https://api.polyhaven.com/files/'+asset))
    folder=DEST/asset;folder.mkdir(parents=True,exist_ok=True)
    records=[]
    for key,out in [('Diffuse','albedo'),('nor_gl','normal'),('Rough','roughness'),('AO','ao')]:
        if key not in meta: continue
        options=meta[key].get('2k',meta[key].get('1k',{}))
        fmt='jpg' if 'jpg' in options else 'png'
        entry=options[fmt]
        target=folder/(out+'.'+fmt)
        if not target.exists(): target.write_bytes(get(entry['url']))
        records.append({'map':out,'path':str(target.relative_to(ROOT)),'url':entry['url'],'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
    return {'asset':asset,'source':'https://polyhaven.com/a/'+asset,'license':'CC0-1.0','files':records}
if __name__=='__main__':
    DEST.mkdir(parents=True,exist_ok=True)
    results=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for future in concurrent.futures.as_completed([pool.submit(fetch,a) for a in ASSETS]):
            try:
                r=future.result();results.append(r);print(r['asset'],len(r['files']),'maps',flush=True)
            except Exception as e: print('FETCH_ERROR',repr(e),flush=True)
    (DEST/'sources.json').write_text(json.dumps(results,indent=2)+'\n')
