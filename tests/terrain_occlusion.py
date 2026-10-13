"""A raised foreground diamond must hide the portion of a car behind it."""
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
    page=browser.new_page(viewport={'width':1280,'height':720})
    page.goto('http://127.0.0.1:8765/MetroForge-2000.html');page.wait_for_function('MetroForge.renderer.art.ready');page.locator('#pause').click()
    result=page.evaluate('''()=>{
      const m=MetroForge,data=m.world.serialize(),blank={...m.world.tiles.find(t=>t.terrain==='grass'),tree:false,road:false,rail:false,line:false,pipe:false,zone:null,zoneType:null,resType:null,parcel:0,level:0,occupancy:0,civic:null,fire:0,abandoned:0,damage:0,storage:0,elev:0,channel:false,waterSource:false,biome:'grass'};
      data.tiles=Array.from({length:2704},()=>({...blank}));data.cars=[];data.trains=[];data.tiles[10*52+10].road=true;data.tiles[10*52+11].road=true;data.tiles[11*52+11].elev=5;
      m.setWorld(m.world.constructor.from(data));const r=m.renderer;r.scale=100;r.cx=100;r.cy=-1000;r.dirty=true;r.draw(m.world);
      const read=()=>Array.from(r.ctx.getImageData(90,35,20,15).data);
      m.world.cars=[{path:[10*52+10,10*52+11],p:0,speed:.8}];
      // Keep the same ground compositor in both images, eliminating PNG-edge
      // antialias differences from repeated terrain painting. Only omit the car.
      const sprite=r.art.sprite;r.art.sprite=function(name,...args){return name.startsWith('car')?true:sprite.call(this,name,...args);};
      r.draw(m.world);const before=read();r.art.sprite=sprite;r.draw(m.world);const after=read();
      return {picked:r.toTile(100,50),foreground:11*52+11,differentPixels:after.filter((value,i)=>value!==before[i]).length,maxDelta:Math.max(...after.map((value,i)=>Math.abs(value-before[i])))};
    }''')
    assert result['picked']==result['foreground'],result
    assert result['differentPixels']==0,'Car is visible through raised terrain: '+str(result)
    print('Raised foreground terrain occludes a moving-agent sprite: PASS')
    browser.close()
