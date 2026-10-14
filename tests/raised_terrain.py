"""Level terrain, zone contact, and object placement must agree at every height."""
import os
import unittest
from pathlib import Path
from playwright.sync_api import sync_playwright

OUT = Path('/workspace/scratch/raised-terrain')
OUT.mkdir(parents=True, exist_ok=True)
FIXTURE = '''()=>{
 const m=MetroForge,d=m.world.serialize(),base={...m.world.tiles.find(t=>t.terrain==='grass'),terrain:'grass',tree:false,road:false,rail:false,line:false,pipe:false,zone:null,zoneType:null,resType:null,parcel:0,level:0,occupancy:0,civic:null,fire:0,abandoned:0,damage:0,storage:0,elev:0,biome:'grass',channel:false,waterSource:false};
 d.tiles=Array.from({length:2704},()=>({...base}));d.cars=[];d.trains=[];d.cash=200000;
 m.setWorld(m.world.constructor.from(d));const r=m.renderer;r.scale=66;r.cx=640;r.cy=r.h/2-26.5*66;r.hover=-1;r.overlay='none';
}'''


class RaisedTerrain(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.playwright = sync_playwright().start()
        cls.browser = cls.playwright.chromium.launch(executable_path='/usr/bin/chromium', args=['--no-sandbox'])
        cls.page = cls.browser.new_page(viewport={'width': 1280, 'height': 720}, device_scale_factor=float(os.environ.get('METROFORGE_TEST_DPR', '1')))
        cls.page.goto('http://127.0.0.1:8765/MetroForge-2000.html')
        cls.page.wait_for_function('MetroForge.renderer.art.ready')
        cls.page.locator('#pause').click()

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.playwright.stop()

    def setUp(self):
        self.page.evaluate(FIXTURE)

    def test_plateau_surface_covers_the_entire_zoned_diamond(self):
        results = self.page.evaluate('''()=>{
         const m=MetroForge,r=m.renderer,results=[];
         for(const biome of ['grass','desert'])for(const elev of [-3,0,2,5]){
          for(let y=25;y<=27;y++)for(let x=25;x<=27;x++)Object.assign(m.world.tiles[y*52+x],{elev,biome});
          r.dirty=true;r.draw(m.world);let wrong=0,pickedWrong=0;const colors=[];
          for(const y of [.2,.4,.6,.8])for(const x of [.2,.4,.6,.8]){
           const p=r.art.point(26+x,26+y,elev),rgba=r.ctx.getImageData(Math.floor(p.x),Math.floor(p.y),1,1).data;
           const cap=biome==='grass'?rgba[1]>rgba[0]&&rgba[1]>rgba[2]:rgba[0]>rgba[2]+30&&rgba[1]>rgba[2]+30;
           colors.push(Array.from(rgba).slice(0,3));if(!cap)wrong++;if(r.toTile(p.x,p.y)!==26*52+26)pickedWrong++;
          }
          const variation=Math.max(...[0,1,2].map(k=>Math.max(...colors.map(c=>c[k]))-Math.min(...colors.map(c=>c[k]))));
          results.push({biome,elev,wrong,pickedWrong,variation});
         }return results;
        }''')
        for result in results:
            self.assertEqual(result['wrong'], 0, 'Zone footprint reaches off its ground surface: '+str(result))
            self.assertEqual(result['pickedWrong'], 0, result)
            self.assertLessEqual(result['variation'], 4, 'A level plateau contains a ramp or a shoreline: '+str(result))

    def test_isolated_raise_has_only_the_requested_height_faces(self):
        result = self.page.evaluate('''()=>{
         const m=MetroForge,r=m.renderer,i=26*52+26;m.world.tiles[i].elev=1;r.dirty=true;r.draw(m.world);
         // The soil face ends at the neighboring elevation, not at the PNG's
         // built-in foundation depth. Sample below the real front wall.
         const p=r.art.point(27,27,0),color=Array.from(r.ctx.getImageData(Math.floor(p.x),Math.floor(p.y+5),1,1).data);
         return {color,isGround:color[1]>color[0]&&color[1]>color[2]};
        }''')
        self.assertTrue(result['isGround'], 'Sprite foundation sticks below the actual cliff: '+str(result))

    def test_terrain_texture_cannot_extend_below_its_surface_plane(self):
        result = self.page.evaluate('''()=>{
         const r=MetroForge.renderer;r.ctx.clearRect(0,0,r.w,r.h);r.art.terrain('grass',26,26,3);
         const bottom=r.art.point(27,27,3),rgba=Array.from(r.ctx.getImageData(Math.floor(bottom.x),Math.floor(bottom.y+5),1,1).data);
         return {rgba};
        }''')
        self.assertEqual(result['rgba'][3], 0, 'Terrain texture supplies a false slope/foundation outside the ground plane: '+str(result))

    def test_level_ground_has_no_background_cracks_between_tiles(self):
        result = self.page.evaluate('''()=>{
         const r=MetroForge.renderer;r.dirty=true;r.draw(MetroForge.world);let maxDelta=0;
         for(const x of [25,26,27])for(const f of [.25,.5,.75]){
          const edge=r.art.point(x,26+f,0),interior=r.art.point(x+.1,26+f,0);
          const a=r.ctx.getImageData(Math.floor(edge.x),Math.floor(edge.y),1,1).data,b=r.ctx.getImageData(Math.floor(interior.x),Math.floor(interior.y),1,1).data;
          for(let k=0;k<3;k++)maxDelta=Math.max(maxDelta,Math.abs(a[k]-b[k]));
         }return {maxDelta};
        }''')
        self.assertLessEqual(result['maxDelta'], 25, 'Background leaks through equal-height tile seams: '+str(result))

    def test_forest_brush_cannot_put_trees_back_on_power_lines(self):
        result = self.page.evaluate('''()=>{const w=MetroForge.world,i=26*52+26;w.place(i,'line');return {tree:w.canPlace(i,'tree'),forest:w.canPlace(i,'forest')};}''')
        self.assertFalse(result['tree'], result)
        self.assertFalse(result['forest'], result)

    def test_loading_an_older_city_clears_trees_under_its_power_lines(self):
        result = self.page.evaluate('''()=>{const m=MetroForge,d=m.world.serialize(),i=26*52+26;Object.assign(d.tiles[i],{line:true,tree:true});const w=m.world.constructor.from(d);return {line:w.tiles[i].line,tree:w.tiles[i].tree};}''')
        self.assertTrue(result['line'], result)
        self.assertFalse(result['tree'], result)

    def test_agent_recomposition_cannot_change_the_terrain_behind_it(self):
        results = self.page.evaluate('''()=>{
         const m=MetroForge,r=m.renderer,results=[],original=r.art.sprite;
         r.art.sprite=function(name,...args){return name.startsWith('car')?true:original.call(this,name,...args);};
         const i=26*52+26;m.world.tiles[i].road=true;m.world.tiles[i+1].road=true;
         for(const position of [.13,.27,.59]){
          m.world.cars=[];r.dirty=true;r.draw(m.world);const before=r.ctx.getImageData(0,0,r.canvas.width,r.canvas.height).data;
          m.world.cars=[{path:[i,i+1],p:position,speed:.8}];r.draw(m.world);const after=r.ctx.getImageData(0,0,r.canvas.width,r.canvas.height).data;let changed=0,maxDelta=0;
          for(let i=0;i<after.length;i++){const delta=Math.abs(before[i]-after[i]);maxDelta=Math.max(maxDelta,delta);if(delta>10)changed++;}
          results.push({position,changed,maxDelta});
         }r.art.sprite=original;return results;
        }''')
        for result in results:
            self.assertEqual(result['changed'], 0, 'Agent region changes terrain pixels with no visible agent: '+str(result))

    def test_agent_recomposition_preserves_wires_between_different_heights(self):
        result = self.page.evaluate('''()=>{
         const m=MetroForge,r=m.renderer,id=(x,y)=>y*52+x;
         Object.assign(m.world.tiles[id(26,26)],{line:true,elev:-3});Object.assign(m.world.tiles[id(26,25)],{civic:'plant',elev:5});
         Object.assign(m.world.tiles[id(26,24)],{road:true,elev:5});Object.assign(m.world.tiles[id(27,24)],{road:true,elev:5});
         m.world.cars=[];r.dirty=true;r.draw(m.world);const before=r.ctx.getImageData(0,0,r.canvas.width,r.canvas.height).data,original=r.art.sprite;
         r.art.sprite=function(name,...args){return name.startsWith('car')?true:original.call(this,name,...args);};
         m.world.cars=[{path:[id(26,24),id(27,24)],p:.3,speed:.8}];r.draw(m.world);r.art.sprite=original;
         const after=r.ctx.getImageData(0,0,r.canvas.width,r.canvas.height).data;let changed=0,maxDelta=0;
         for(let i=0;i<after.length;i++){const delta=Math.abs(before[i]-after[i]);maxDelta=Math.max(maxDelta,delta);if(delta>10)changed++;}
         return {changed,maxDelta};
        }''')
        self.assertEqual(result['changed'], 0, 'An agent region erases a long elevated wire: '+str(result))

    def test_power_pole_does_not_change_neighboring_raised_ground(self):
        results = self.page.evaluate('''()=>{
         const m=MetroForge,r=m.renderer,results=[];
         for(const elev of [0,1,3,5]){
          for(let y=24;y<=28;y++)for(let x=24;x<=28;x++)Object.assign(m.world.tiles[y*52+x],{elev:(x<=26&&y<=26)?elev:0,line:false});
          const i=26*52+26;r.dirty=true;r.draw(m.world);const W=r.canvas.width,H=r.canvas.height,dpr=W/r.w,before=r.ctx.getImageData(0,0,W,H).data;
          const p=r.art.point(26.5,26.5,elev),bounds={x:p.x-r.scale*.20-3,y:p.y-r.scale*.65-3,width:r.scale*.40+6,height:r.scale*.65+6};
          const elevations=m.world.tiles.map(t=>t.elev);m.world.place(i,'line');m.world.recalculate();r.dirty=true;r.draw(m.world);const after=r.ctx.getImageData(0,0,W,H).data;let changed=0;
          for(let y=5;y<H-5;y++)for(let x=5;x<W-5;x++){
           const px=(x+.5)/dpr,py=(y+.5)/dpr;if(px>=bounds.x&&px<=bounds.x+bounds.width&&py>=bounds.y&&py<=bounds.y+bounds.height)continue;
           const at=(y*W+x)*4;let delta=0;for(let k=0;k<3;k++)delta=Math.max(delta,Math.abs(before[at+k]-after[at+k]));if(delta>10)changed++;
          }
          results.push({elev,changed,elevationsChanged:m.world.tiles.some((t,i)=>t.elev!==elevations[i])});
         }return results;
        }''')
        for result in results:
            self.assertEqual(result['changed'], 0, 'Adding a pole repaints unrelated raised ground: '+str(result))
            self.assertFalse(result['elevationsChanged'], result)

    def test_line_clears_tree_and_undo_redo_restores_both(self):
        page = self.page
        page.evaluate('MetroForge.world.tiles[26*52+26].tree=true;MetroForge.renderer.dirty=true')
        page.locator('[data-category="Utilities"]').click()
        page.locator('[data-tool="line"]').click()
        point = page.evaluate('''()=>{const r=MetroForge.renderer,p=r.art.point(26.5,26.5,0),b=r.canvas.getBoundingClientRect();return {x:p.x+b.x,y:p.y+b.y};}''')
        cash = page.evaluate('MetroForge.world.cash')
        page.mouse.click(point['x'], point['y'])
        self.assertTrue(page.evaluate('MetroForge.world.tiles[26*52+26].line'))
        self.assertFalse(page.evaluate('MetroForge.world.tiles[26*52+26].tree'), 'Power line left its tree in place')
        self.assertEqual(page.evaluate('MetroForge.world.cash'), cash-13)
        page.locator('#undoBtn').click()
        self.assertTrue(page.evaluate('MetroForge.world.tiles[26*52+26].tree'))
        self.assertFalse(page.evaluate('MetroForge.world.tiles[26*52+26].line'))
        self.assertEqual(page.evaluate('MetroForge.world.cash'), cash)
        page.locator('#redoBtn').click()
        self.assertFalse(page.evaluate('MetroForge.world.tiles[26*52+26].tree'))
        self.assertTrue(page.evaluate('MetroForge.world.tiles[26*52+26].line'))
        self.assertEqual(page.evaluate('MetroForge.world.cash'), cash-13)


if __name__ == '__main__':
    unittest.main()
