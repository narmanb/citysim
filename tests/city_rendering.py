"""Real simulation growth, city systems, agents and measured desktop render checks."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

OUT=Path('/workspace/scratch/isometric');OUT.mkdir(parents=True,exist_ok=True)

def main():
    with sync_playwright() as p:
        browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
        page=browser.new_page(viewport={'width':1280,'height':720});errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto('http://127.0.0.1:8765/MetroForge-2000.html');page.wait_for_function('MetroForge.renderer.art.ready');page.locator('#pause').click()
        result=page.evaluate('''()=>{
          const m=MetroForge,data=m.world.serialize(),blank={...m.world.tiles.find(t=>t.terrain==='grass'),tree:false,road:false,rail:false,line:false,pipe:false,zone:null,zoneType:null,resType:null,parcel:0,level:0,occupancy:0,civic:null,fire:0,abandoned:0,damage:0,storage:0,elev:0,channel:false,waterSource:false,biome:'grass'};
          data.tiles=Array.from({length:2704},()=>({...blank}));data.cash=200000;data.seed=4242;data.cars=[];data.trains=[];data.tick=0;data.month=1;data.year=2000;
          m.setWorld(m.world.constructor.from(data));const w=m.world,id=(x,y)=>y*52+x,put=(x,y,tool,parcel=0)=>w.place(id(x,y),tool,false,parcel);
          for(let y=20;y<=35;y++)Object.assign(w.tiles[id(33,y)],{terrain:'water',waterSource:true});
          for(let x=18;x<=36;x++)put(x,26,'road');
          for(let y=22;y<=32;y++){put(24,y,'road');put(30,y,'road');}
          for(let x=20;x<=35;x++)put(x,32,'road');
          m.input.tool='road';m.input.placeLinear(id(31,26),id(35,26));
          for(let x=10;x<=38;x++)put(x,34,'rail');m.input.tool='rail';m.input.placeLinear(id(31,34),id(35,34));put(19,34,'station');put(35,34,'station');
          put(19,20,'plant');put(19,21,'line');put(19,22,'line');put(20,22,'pump');
          for(let x=19;x<=32;x++){put(x,23,'line');put(x,23,'pipe');put(x,27,'line');put(x,27,'pipe');}
          for(let y=23;y<=27;y++){put(19,y,'line');put(19,y,'pipe');}
          for(const [x,y]of [[24,22],[30,22],[24,31],[30,31]])put(x,y,'park');
          for(const [x,y,tool]of [[25,21,'police'],[27,21,'fire'],[27,30,'school'],[31,30,'hospital'],[21,22,'tower']])put(x,y,tool);
          let parcel=100;
          for(const [x,y,tool]of [[20,24,'res'],[22,24,'res'],[25,24,'office'],[25,28,'shop'],[22,28,'apt'],[28,24,'light'],[28,28,'logistics'],[31,28,'heavy']]){
            parcel++;for(let dy=0;dy<2;dy++)for(let dx=0;dx<2;dx++)put(x+dx,y+dy,tool,parcel);
          }
          put(18,24,'tree');put(19,25,'tree');put(27,29,'tree');put(35,23,'desert');put(35,24,'raise');put(35,24,'raise');
          w.recalculate();m.step(36);
          const grown=w.tiles.filter(t=>t.level).length;
          // Existing TrafficSystem.advance is reached by the normal running frame.
          m.renderer.fit();m.input.tool='pan';m.renderer.dirty=true;
          return {grown,stats:{population:w.stats.population,jobs:w.stats.jobs,power:w.stats.powerGenerated,water:w.stats.waterCapacity},bridge:w.tiles[id(33,26)].road,stations:w.network.stations.length,railRoutes:w.network.railRoutes.length};
        }''')
        assert result['grown']>0,result
        assert result['stats']['population']>0,result
        assert result['stats']['power']==550,result
        assert result['stats']['water']>0,result
        assert result['bridge'],result
        assert result['stations']==2 and result['railRoutes']>0,result
        page.locator('#pause').click()
        page.wait_for_function('MetroForge.world.trains.length>0',timeout=10000)
        page.wait_for_function('MetroForge.world.cars.length>0',timeout=10000)
        page.locator('#pause').click()
        result['agents']=page.evaluate('({cars:MetroForge.world.cars.length,trains:MetroForge.world.trains.length})')
        before=page.evaluate('MetroForge.world.cars[0].p');page.locator('#pause').click();page.wait_for_function('(before)=>MetroForge.world.cars[0].p!==before',arg=before);page.locator('#pause').click()
        # City event UI invokes the existing disaster simulation, with no test-only renderer code.
        # Fire ignition ignores bare roads; choose a developed candidate deterministically.
        page.evaluate('''()=>{const candidates=MetroForge.world.tiles.filter(t=>t.level||t.civic||t.road),target=candidates.findIndex(t=>t.level);window.testOriginalRandom=Math.random;Math.random=()=>(target+.5)/candidates.length;}''')
        page.locator('#disasterBtn').click();page.locator('[data-disaster="fire"]').click()
        page.evaluate('Math.random=window.testOriginalRandom;delete window.testOriginalRandom')
        assert page.evaluate('MetroForge.world.tiles.some(t=>t.fire>0)')
        page.evaluate('MetroForge.renderer.scale=40;MetroForge.renderer.cx=640;MetroForge.renderer.cy=MetroForge.renderer.h/2-26*40;MetroForge.renderer.dirty=true')
        page.wait_for_timeout(100);page.screenshot(path=str(OUT/'developed-city.png'))
        metrics=page.evaluate('''()=>new Promise(resolve=>{
          const r=MetroForge.renderer,original=r.draw,times=[],intervals=[];let last=performance.now();
          r.draw=function(w){const start=performance.now();intervals.push(start-last);last=start;original.call(this,w);times.push(performance.now()-start);
            if(times.length===80){r.draw=original;times.sort((a,b)=>a-b);intervals.sort((a,b)=>a-b);resolve({medianDrawMs:times[40],p95DrawMs:times[76],medianFrameIntervalMs:intervals[40],p95FrameIntervalMs:intervals[76],visibleTiles:r.metrics.visibleTiles,staticObjects:r.metrics.staticObjects,occludingGroundTiles:r.metrics.occludingGroundTiles});}
          };
        })''')
        result['desktopRender']=metrics
        exported=page.evaluate('MetroForge.world.serialize()');(OUT/'developed-city.json').write_text(json.dumps(exported,separators=(',',':')))
        # Every valid tile center, including map corners, still round-trips at every supported endpoint.
        assert page.evaluate('''()=>{const r=MetroForge.renderer;for(const scale of [7,19,50,100]){r.scale=scale;for(let i=0;i<2704;i++){if(MetroForge.world.tiles[i].elev)continue;const p=r.art.point(i%52+.5,Math.floor(i/52)+.5,0);if(r.toTile(p.x,p.y)!==i)return false;}}r.fit();r.dirty=true;return true;}''')
        assert not errors,errors
        result['errors']=errors;(OUT/'city-rendering-results.json').write_text(json.dumps(result,indent=2));print(json.dumps(result));browser.close()

if __name__=='__main__':main()
