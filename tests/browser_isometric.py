"""Chromium integration checks. Start python -m http.server 8765 first.

Requires Python Playwright and Chromium. Artifacts go to /workspace/scratch.
"""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

OUT = Path('/workspace/scratch/isometric'); OUT.mkdir(parents=True, exist_ok=True)

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='/usr/bin/chromium', args=['--no-sandbox'])
        page = browser.new_page(viewport={'width': 1280, 'height': 720}, accept_downloads=True)
        errors = []; page.on('pageerror', lambda e: errors.append(str(e)))
        response = page.goto('http://127.0.0.1:8765/isometric-preview.html')
        assert response.status == 200, 'Interactive asset proof scene is missing'
        page.wait_for_function('window.MetroForgePreview && MetroForgePreview.ready')
        assert page.evaluate('MetroForgePreview.art.errors.length') == 0
        page.screenshot(path=str(OUT / 'asset-proof.png'))
        before = page.evaluate('MetroForgePreview.view.cx')
        page.mouse.move(640, 360); page.mouse.down(); page.mouse.move(710, 385, steps=5); page.mouse.up()
        assert page.evaluate('MetroForgePreview.view.cx') != before
        page.mouse.wheel(0, -150)
        page.goto('http://127.0.0.1:8765/MetroForge-2000.html')
        page.wait_for_function('window.MetroForge')
        assert page.evaluate("MetroForge.renderer.projection === 'isometric'"), 'The real game still uses the square renderer'
        page.wait_for_function('MetroForge.renderer.art && MetroForge.renderer.art.ready')
        assert page.evaluate('MetroForge.renderer.art.errors.length') == 0
        page.locator('#pause').click()
        assert page.evaluate("MetroForge.input.mode === 'tapPan'")
        page.evaluate('''() => {
          const w=MetroForge.world, data=w.serialize();
          const blank={...w.tiles.find(t=>t.terrain==='grass'),tree:false,road:false,rail:false,line:false,pipe:false,zone:null,zoneType:null,resType:null,parcel:0,level:0,occupancy:0,civic:null,fire:0,abandoned:0,damage:0,storage:0,elev:0,channel:false,waterSource:false,biome:'grass'};
          data.tiles=Array.from({length:2704},()=>({...blank}));data.cash=200000;data.seed=4242;data.cars=[];data.trains=[];
          MetroForge.setWorld(w.constructor.from(data));
        }''')
        def position(x,y):
            return page.evaluate('''([x,y])=>{const r=MetroForge.renderer,p=r.art.point(x+.5,y+.5,MetroForge.world.tiles[y*52+x].elev),b=document.getElementById('city').getBoundingClientRect();return {x:p.x+b.x,y:p.y+b.y};}''',[x,y])
        def select(category,tool):
            page.locator(f'[data-category="{category}"]').click();page.locator(f'[data-tool="{tool}"]').click()
        def click_tile(x,y):
            pos=position(x,y);page.mouse.click(pos['x'],pos['y'])
        select('Transport','road');click_tile(26,26)
        assert page.evaluate('MetroForge.world.tiles[26*52+26].road')
        page.locator('#undoBtn').click();assert not page.evaluate('MetroForge.world.tiles[26*52+26].road')
        page.locator('#redoBtn').click();assert page.evaluate('MetroForge.world.tiles[26*52+26].road')
        # Dragging in default Tap + pan moves the camera without placing a road.
        before=page.evaluate('({cx:MetroForge.renderer.cx,cash:MetroForge.world.cash,count:MetroForge.world.tiles.filter(t=>t.road).length})')
        pos=position(25,25);page.mouse.move(pos['x'],pos['y']);page.mouse.down();page.mouse.move(pos['x']+60,pos['y']+25,steps=6);page.mouse.up()
        assert page.evaluate('MetroForge.renderer.cx')!=before['cx']
        assert page.evaluate('MetroForge.world.cash')==before['cash']
        assert page.evaluate('MetroForge.world.tiles.filter(t=>t.road).length')==before['count']
        # Paint-drag creates one connected parcel, then undo/redo restores it.
        page.locator('#placementMode').click();select('Zoning','res')
        a,b=position(25,24),position(27,24);page.mouse.move(a['x'],a['y']);page.mouse.down();page.mouse.move(b['x'],b['y'],steps=12);page.mouse.up()
        ids=[24*52+x for x in range(25,28)]
        parcels=page.evaluate('(ids)=>ids.map(i=>MetroForge.world.tiles[i].parcel)',ids)
        assert all(parcels) and len(set(parcels))==1,parcels
        page.locator('#undoBtn').click();assert page.evaluate('(ids)=>ids.every(i=>!MetroForge.world.tiles[i].zone)',ids)
        page.locator('#redoBtn').click();assert page.evaluate('(ids)=>ids.every(i=>MetroForge.world.tiles[i].zone==="res")',ids)
        page.locator('#placementMode').click();select('Terraform','raise');click_tile(28,24)
        assert page.evaluate('MetroForge.world.tiles[24*52+28].elev')==1
        select('Terraform','raise');click_tile(28,24)
        assert page.evaluate('MetroForge.world.tiles[24*52+28].elev')==2
        page.locator('[data-tool="pan"]').click();click_tile(28,24)
        assert page.evaluate('MetroForge.world.selected')==24*52+28
        assert 'elevation 2' in page.locator('#details').inner_text()
        # UI export/import and browser persistence retain the actual edited city.
        page.locator('#fileBtn').click();page.locator('#saveBtn').click()
        saved=page.evaluate("JSON.parse(localStorage.getItem('metroforge2000-city'))")
        with page.expect_download() as download:page.locator('#exportBtn').click()
        download.value.save_as(str(OUT/'edited-city.json'))
        exported=json.loads((OUT/'edited-city.json').read_text());assert exported==saved
        page.evaluate('MetroForge.world.cash=123');page.locator('#loadBtn').click()
        assert page.evaluate('MetroForge.world.cash')==saved['cash']
        page.evaluate('MetroForge.world.cash=456');page.locator('#importFile').set_input_files(str(OUT/'edited-city.json'))
        page.wait_for_function('MetroForge.world.cash!==456')
        assert page.evaluate('MetroForge.world.serialize().tiles')==exported['tiles']
        assert page.evaluate('MetroForge.world.serialize().seed')==exported['seed']
        page.locator('#fileModal [data-close]').click()
        for overlay in ['none','zoning','traffic','crime','pollution','landValue','police','fire','school','hospital','power','water','roadCondition']:
            page.locator('#overlayBtn').click();page.locator(f'[data-overlay="{overlay}"]').click()
            assert page.evaluate('MetroForge.renderer.overlay')==overlay
        page.locator('#overlayBtn').click();page.locator('[data-overlay="none"]').click()
        page.screenshot(path=str(OUT / 'edited-game.png'))
        # Removing optional fields from an older city still uses the existing import defaults.
        old=page.evaluate('''()=>{const data=MetroForge.world.serialize();data.version=2;for(const t of data.tiles){delete t.elev;delete t.biome;delete t.zoneType;}return data;}''')
        page.locator('#importFile').set_input_files({'name':'older-city.json','mimeType':'application/json','buffer':json.dumps(old).encode()})
        page.wait_for_function('MetroForge.world.tiles.every(t=>t.elev===0)')
        assert page.evaluate('MetroForge.world.tiles.every(t=>t.biome==="grass")')
        # Cached ground is reused while the live agent/object layer continues to draw.
        page.wait_for_timeout(100);count=page.evaluate('MetroForge.renderer.metrics.groundRedraws');page.wait_for_timeout(150)
        assert page.evaluate('MetroForge.renderer.metrics.groundRedraws')==count
        (OUT/'browser-results.json').write_text(json.dumps({'assetProof':'PASS','realGame':'PASS','placement':'PASS','pan':'PASS','parcelPaint':'PASS','undoRedo':'PASS','elevatedPicking':'PASS','saveLoadExportImport':'PASS','legacyImport':'PASS','overlays':13,'groundCache':'PASS','errors':errors},indent=2))
        assert not errors, errors
        print(json.dumps({'assetProof': 'PASS', 'realGame': 'PASS', 'errors': errors}))
        browser.close()

if __name__ == '__main__': main()
