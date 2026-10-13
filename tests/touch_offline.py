"""Real Chromium touch events and fully offline file-URL runtime checks."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright, Error

ROOT=Path(__file__).resolve().parents[1];OUT=Path('/workspace/scratch/isometric');OUT.mkdir(parents=True,exist_ok=True)

def main():
    with sync_playwright() as p:
        browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
        context=browser.new_context(viewport={'width':844,'height':390},has_touch=True,is_mobile=True)
        page=context.new_page();errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto('http://127.0.0.1:8765/MetroForge-2000.html');page.wait_for_function('MetroForge.renderer.art.ready');page.locator('#pause').click()
        page.locator('[data-category="Transport"]').click();page.locator('[data-tool="road"]').click()
        def position(x,y):return page.evaluate('''([x,y])=>{const r=MetroForge.renderer,p=r.art.point(x+.5,y+.5,0),b=document.getElementById('city').getBoundingClientRect();return {x:p.x+b.x,y:p.y+b.y};}''',[x,y])
        pos=position(26,26);page.touchscreen.tap(pos['x'],pos['y'])
        assert page.evaluate('MetroForge.world.tiles[26*52+26].road')
        cdp=context.new_cdp_session(page)
        def touch(kind,points):cdp.send('Input.dispatchTouchEvent',{'type':kind,'touchPoints':[{'x':x,'y':y,'id':i+1} for i,(x,y) in enumerate(points)]})
        cash=page.evaluate('MetroForge.world.cash');before=page.evaluate('MetroForge.renderer.cx')
        touch('touchStart',[(350,210)]);touch('touchMove',[(420,230)]);touch('touchEnd',[])
        assert page.evaluate('MetroForge.renderer.cx')!=before
        assert page.evaluate('MetroForge.world.cash')==cash
        # A pinch in paint mode must zoom without adding any zones or spending money.
        page.locator('#placementMode').click();page.locator('[data-category="Zoning"]').click();page.locator('[data-tool="res"]').click()
        before=page.evaluate('MetroForge.renderer.scale')
        touch('touchStart',[(300,210),(400,210)]);touch('touchMove',[(275,210),(425,210)]);touch('touchEnd',[])
        assert page.evaluate('MetroForge.renderer.scale')>before
        assert page.evaluate('MetroForge.world.cash')==cash
        assert page.evaluate('MetroForge.world.tiles.every(t=>!t.zone)')
        a,b=position(25,24),position(26,24)
        touch('touchStart',[(a['x'],a['y'])]);touch('touchMove',[(b['x'],b['y'])]);touch('touchEnd',[])
        assert page.evaluate('MetroForge.world.tiles[24*52+25].zone==="res" && MetroForge.world.tiles[24*52+26].zone==="res"')
        assert page.evaluate('MetroForge.world.tiles[24*52+25].parcel===MetroForge.world.tiles[24*52+26].parcel')
        page.screenshot(path=str(OUT/'mobile-landscape.png'));context.close()
        # The package starts without a server or network (Android uses the same layout).
        context=browser.new_context(viewport={'width':1280,'height':720});context.set_offline(True)
        page=context.new_page();page.on('pageerror',lambda e:errors.append(str(e)))
        file_result='PASS'
        try:
            page.goto((ROOT/'app/src/main/assets/index.html').as_uri());page.wait_for_function('MetroForge.renderer.art.ready')
            assert page.evaluate('MetroForge.renderer.art.errors.length')==0
            assert page.evaluate('MetroForge.world.tiles.length')==2704
        except Error as exc:
            if 'ERR_BLOCKED_BY_ADMINISTRATOR' not in str(exc):raise
            file_result='BLOCKED: managed Chromium policy denies file URLs'
        context.close()
        context=browser.new_context(viewport={'width':1280,'height':720})
        requests=[]
        def local_only(route):
            requests.append(route.request.url)
            if route.request.url.startswith('http://127.0.0.1:8765/'):route.continue_()
            else:route.abort()
        context.route('**/*',local_only);page=context.new_page()
        page.goto('http://127.0.0.1:8765/app/src/main/assets/index.html');page.wait_for_function('MetroForge.renderer.art.ready')
        assert page.evaluate('MetroForge.renderer.art.errors.length')==0
        assert all('/app/src/main/assets/' in request for request in requests),requests
        context.close()
        # Missing atlas textures retain a working city with an explicit message.
        context=browser.new_context(viewport={'width':1280,'height':720})
        context.route('**/atlases/*.png',lambda route:route.abort())
        page=context.new_page();page.goto('http://127.0.0.1:8765/MetroForge-2000.html');page.wait_for_function('MetroForge.renderer.art.ready')
        assert page.evaluate('MetroForge.renderer.art.errors.length')==5
        assert 'artwork' in page.locator('#toast').inner_text().lower(), 'Missing textures need a visible fallback notice'
        page.screenshot(path=str(OUT/'missing-art-fallback.png'))
        assert not errors,errors
        result={'touchTap':'PASS','touchPan':'PASS','paintPinchNoConstruction':'PASS','touchParcelPaint':'PASS','offlineFileURL':file_result,'packagedResourcesLocalOnly':'PASS','textureFailureFallback':'PASS','errors':errors}
        (OUT/'touch-offline-results.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
        context.close();browser.close()

if __name__=='__main__':main()
