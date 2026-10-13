"""Trees and viewport movement must not reveal buried terrain or erase map content."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

OUT = Path('/workspace/scratch/pan-rendering')
OUT.mkdir(parents=True, exist_ok=True)

FIXTURE = '''()=>{
 const m=MetroForge,d=m.world.serialize(),base={...m.world.tiles.find(t=>t.terrain==='grass'),terrain:'grass',tree:false,road:false,rail:false,line:false,pipe:false,zone:null,zoneType:null,resType:null,parcel:0,level:0,occupancy:0,civic:null,fire:0,abandoned:0,damage:0,storage:0,elev:0,biome:'grass',channel:false,waterSource:false};
 d.tiles=Array.from({length:2704},()=>({...base}));d.cars=[];d.trains=[];
 m.setWorld(m.world.constructor.from(d));
}'''

TREE_TEST = '''(scale)=>{
 const m=MetroForge,r=m.renderer,c=r.ctx;r.scale=scale;r.cx=r.w/2;r.cy=r.h/2-26.5*scale;r.dirty=true;r.draw(m.world);
 const W=r.canvas.width,H=r.canvas.height,dpr=W/r.w,read=()=>c.getImageData(0,0,W,H).data;
 const before=read(),tile=m.world.tiles[26*52+26];tile.tree=true;r.dirty=true;r.draw(m.world);const after=read();
 const bounds=r.art.spriteBounds('tree',r.art.point(26.5,26.5),2);let changed=0,maxDelta=0;
 for(let y=10;y<H-10;y++)for(let x=10;x<W-10;x++){
  const px=(x+.5)/dpr,py=(y+.5)/dpr;
  if(px>=bounds.x-2&&px<=bounds.x+bounds.width+2&&py>=bounds.y-2&&py<=bounds.y+bounds.height+2)continue;
  const p=MetroForgeIsoCore.unproject(px,py,scale,r.cx,r.cy),fx=p.x-Math.floor(p.x),fy=p.y-Math.floor(p.y);
  if(fx<.08||fx>.92||fy<.08||fy>.92)continue;
  const i=(y*W+x)*4;let delta=0;for(let k=0;k<3;k++)delta=Math.max(delta,Math.abs(before[i+k]-after[i+k]));
  if(delta>10)changed++;maxDelta=Math.max(maxDelta,delta);
 }
 return {changed,maxDelta,scale,dpr};
}'''

PAN_TEST = '''([scale,dx,dy])=>{
 const m=MetroForge,r=m.renderer,c=r.ctx;r.scale=scale;r.cx=r.w/2;r.cy=r.h/2-26.5*scale;
 for(let i=0;i<2704;i++)m.world.tiles[i].tree=(i%52*11+Math.floor(i/52)*17)%9<2;
 for(const [x,y]of [[25,22],[26,22],[27,22],[25,24],[26,24],[27,24],[24,26],[25,26],[26,26],[24,28],[25,28]])m.world.place(y*52+x,'res',false,5000+y);
 m.world.recalculate();const tilesBefore=JSON.stringify(m.world.serialize().tiles);
 r.dirty=true;r.draw(m.world);const W=r.canvas.width,H=r.canvas.height,dpr=W/r.w;
 const before=c.getImageData(0,0,W,H).data;r.cx+=dx;r.cy+=dy;r.dirty=true;r.draw(m.world);
 const after=c.getImageData(0,0,W,H).data,sx=Math.round(dx*dpr),sy=Math.round(dy*dpr);let changed=0,maxDelta=0;
 for(let y=50;y<H-50;y++)for(let x=50;x<W-50;x++){
  const ox=x-sx,oy=y-sy;if(ox<50||oy<50||ox>=W-50||oy>=H-50)continue;
  const p=MetroForgeIsoCore.unproject((x+.5)/dpr,(y+.5)/dpr,scale,r.cx,r.cy),fx=p.x-Math.floor(p.x),fy=p.y-Math.floor(p.y);
  if(fx<.08||fx>.92||fy<.08||fy>.92)continue;
  const a=(oy*W+ox)*4,b=(y*W+x)*4;let delta=0;
  for(let k=0;k<3;k++)delta=Math.max(delta,Math.abs(before[a+k]-after[b+k]));
  if(delta>10)changed++;maxDelta=Math.max(maxDelta,delta);
 }
 if(JSON.stringify(m.world.serialize().tiles)!==tilesBefore)throw Error('Rendering mutated logical tiles');
 return {changed,maxDelta,scale,dx,dy,dpr};
}'''

def main():
    results=[]
    with sync_playwright() as p:
        browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox'])
        for dpr in [1,1.5,2]:
            page=browser.new_page(viewport={'width':854,'height':394},device_scale_factor=dpr)
            page.goto('http://127.0.0.1:8765/MetroForge-2000.html')
            page.wait_for_function('MetroForge.renderer.art.ready');page.locator('#pause').click()
            for scale in [28,33,66]:
                page.evaluate(FIXTURE);result=page.evaluate(TREE_TEST,scale);results.append({'kind':'tree',**result})
                assert result['changed']==0,'Adding a tree changed distant flat ground: '+json.dumps(result)
                for dx,dy in [[-40,32],[0,-32],[40,-32]]:
                    page.evaluate(FIXTURE);result=page.evaluate(PAN_TEST,[scale,dx,dy]);results.append({'kind':'pan',**result})
                    assert result['changed']==0,'Camera movement changed existing map contents: '+json.dumps(result)
            if dpr==1.5:page.screenshot(path=str(OUT/'fixed-flat-forest.png'))
            page.close()
        browser.close()
    (OUT/'results.json').write_text(json.dumps(results,indent=2))
    print(f'Terrain/tree isolation and camera pan invariance: {len(results)} checks PASS')

if __name__=='__main__':main()
