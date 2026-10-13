"""Different growth levels must visibly change residential and industrial art."""
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
    page=browser.new_page(viewport={'width':1280,'height':720})
    page.goto('http://127.0.0.1:8765/MetroForge-2000.html');page.wait_for_function('MetroForge.renderer.art.ready');page.locator('#pause').click()
    results=page.evaluate('''()=>{
      const m=MetroForge,data=m.world.serialize(),blank={...m.world.tiles.find(t=>t.terrain==='grass'),tree:false,road:false,rail:false,line:false,pipe:false,zone:null,zoneType:null,resType:null,parcel:0,level:0,occupancy:0,civic:null,fire:0,abandoned:0,damage:0,storage:0,elev:0,channel:false,waterSource:false,biome:'grass'};
      data.tiles=Array.from({length:2704},()=>({...blank}));data.cars=[];data.trains=[];
      m.setWorld(m.world.constructor.from(data));const r=m.renderer,t=m.world.tiles[26*52+26];r.scale=66;r.cx=640;r.cy=280-26.5*66;
      const image=()=>{r.dirty=true;r.draw(m.world);return Array.from(r.ctx.getImageData(550,80,180,230).data);};const results={};
      for(const [zone,type]of [['res','house'],['ind','light']]){
        Object.assign(t,{zone,zoneType:type,resType:zone==='res'?type:null,parcel:0,level:1});const first=image();t.level=2;const second=image();results[type]=second.filter((value,i)=>value!==first[i]).length;
      }return results;
    }''')
    for kind,count in results.items():assert count>100,f'{kind} levels 1 and 2 look identical: {results}'
    print('House and industrial growth levels change their rendered appearance: PASS')
    browser.close()
