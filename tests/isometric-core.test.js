const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const corePath = path.join(__dirname, '../src/isometric-core.js');

test('isometric core exists', () => assert.ok(fs.existsSync(corePath), 'Shared isometric geometry is missing'));
if (fs.existsSync(corePath)) {
  const { project, unproject, roadMask, parcelFootprint, visible, pickTile, zoomCamera, bridgeEdges, includePoints } = require(corePath);
  test('a visible cliff remains in ground bounds when its elevated cap is above the viewport',()=>{
    const grass={x:-50,y:-151,width:200,height:150};
    assert.equal(visible(grass,100,100),false);
    const lower=project(1,1,100,50,-76);lower.y-=-3*100*.15;
    const expanded=includePoints(grass,[lower]);
    assert.equal(expanded.y+expanded.height,69);
    assert.equal(visible(expanded,100,100),true);
  });
  test('bridge guardrails run parallel to each road axis',()=>{
    for(const [mask,axis] of [[5,'y'],[10,'x']])for(const [ax,ay,bx,by] of bridgeEdges(mask)) {
      if(axis==='y'){assert.equal(ax,bx);assert.notEqual(ay,by);}
      else {assert.equal(ay,by);assert.notEqual(ax,bx);}
    }
  });
  test('picking follows elevated ground surfaces and rejects outside the map',()=>{
    const tiles=Array.from({length:25},()=>({elev:0})); tiles[12].elev=5;tiles[18].elev=-3;
    const camera={scale:40,cx:300,cy:30};
    for(const i of [0,4,12,18,20,24]) {
      const p=project(i%5+.5,Math.floor(i/5)+.5,40,300,30);p.y-=tiles[i].elev*40*.15;
      assert.equal(pickTile(p.x,p.y,camera,tiles,5),i);
    }
    assert.equal(pickTile(-999,-999,camera,tiles,5),-1);
  });
  test('zoom preserves the world point under a gesture and clamps scale',()=>{
    const camera={scale:20,cx:200,cy:-150};const before=unproject(400,200,20,200,-150);
    zoomCamera(camera,2,400,200);
    assert.deepEqual(unproject(400,200,camera.scale,camera.cx,camera.cy),before);
    zoomCamera(camera,100,400,200);assert.equal(camera.scale,100);
    zoomCamera(camera,.0001,400,200);assert.equal(camera.scale,7);
  });
  test('ground coordinates survive projection over all 2704 tiles and zooms', () => {
    for (const scale of [7, 19, 50, 100]) for (let y = 0; y < 52; y++) for (let x = 0; x < 52; x++) {
      const screen = project(x + .5, y + .5, scale, 123, -456);
      const world = unproject(screen.x, screen.y, scale, 123, -456);
      assert.equal(Math.floor(world.x), x); assert.equal(Math.floor(world.y), y);
    }
    assert.deepEqual(project(1, 0, 66, 0, 0), {x:66,y:33});
    assert.deepEqual(project(0, 1, 66, 0, 0), {x:-66,y:33});
  });
  test('road masks cover all junctions without wrapping rows', () => {
    for (let mask=0; mask<16; mask++) {
      const tiles=Array.from({length:25},()=>({road:false}));
      for (const [bit,i] of [[1,7],[2,13],[4,17],[8,11]]) if(mask&bit) tiles[i].road=true;
      assert.equal(roadMask(tiles,12,5),mask);
    }
    const edge=Array.from({length:25},()=>({road:true}));
    assert.equal(roadMask(edge,0,5),6); assert.equal(roadMask(edge,4,5),12);
  });
  test('irregular parcel building footprint contains only property members', () => {
    for(const members of [[0],[0,1,5,6],[0,1,2,5,10],[0,1,2,5,7,10,11,12]]) {
      const footprint=parcelFootprint(members,5);const set=new Set(members);
      for(let y=footprint.y;y<footprint.y+footprint.height;y++) for(let x=footprint.x;x<footprint.x+footprint.width;x++) assert.ok(set.has(y*5+x));
    }
    assert.deepEqual(parcelFootprint([0,1,5,6],5),{x:0,y:0,width:2,height:2});
  });
  test('overhanging sprite bounds are visible when its anchor is offscreen',()=>{
    assert.equal(visible({x:50,y:110,width:30,height:50},100,100),false);
    assert.equal(visible({x:50,y:80,width:30,height:50},100,100),true);
    assert.equal(visible({x:-80,y:0,width:100,height:30},100,100),true);
  });
}

test('asset manifest exists and includes the supplied licenses', () => {
  const file=path.join(__dirname,'../assets/manifest.json');assert.ok(fs.existsSync(file),'Asset manifest is missing');
  const m=JSON.parse(fs.readFileSync(file));assert.equal(m.tile.width,132);assert.equal(m.tile.height,66);
  assert.equal(m.licenses.length,4);
  for(const entry of m.licenses) assert.match(fs.readFileSync(path.join(__dirname,'..',entry.file),'utf8'),/CC0/);
  for(const sprite of Object.values(m.sprites)) {
    const atlas=m.atlases[sprite.atlas];assert.ok(sprite.x>=0&&sprite.y>=0&&sprite.x+sprite.width<=atlas.width&&sprite.y+sprite.height<=atlas.height);
  }
});
