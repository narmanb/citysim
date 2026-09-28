from pathlib import Path
import re

path = Path('MetroForge-2000.html')
text = path.read_text()
original = text


def replace(old, new, label):
    global text
    if old not in text:
        raise SystemExit(f'Patch target not found: {label}')
    text = text.replace(old, new, 1)


def sub(pattern, repl, label, flags=0):
    global text
    text2, n = re.subn(pattern, repl, text, count=1, flags=flags)
    if n != 1:
        raise SystemExit(f'Patch target not found or ambiguous ({n}): {label}')
    text = text2

# Tool palette, subtype map, and categories.
sub(
    r"const N=52, COUNT=N\*N, COST=\{.*?\}, CONFIG=",
    "const N=52, COUNT=N*N, COST={bulldoze:18,road:18,rail:36,line:13,pipe:12,res:9,apt:14,shop:12,office:16,light:12,logistics:18,heavy:22,park:95,plant:3000,pump:950,tower:800,police:1200,fire:1200,school:1600,hospital:1900,station:550,raise:20,lower:20,river:24,grass:5,desert:5,tree:4,forest:6}, CONFIG=",
    'tool costs',
    re.S,
)
sub(
    r"const TOOLS=\[.*?\];\nconst CATEGORIES=\{.*?\};",
    """const TOOLS=[['pan','✋ Pan'],['bulldoze','▧ Bulldoze'],['road','═ Road'],['rail','≡ Rail'],['line','⚡ Power line'],['pipe','◌ Water pipe'],['res','⌂ House lots'],['apt','▥ Apartment lots'],['shop','▣ Shops & services'],['office','▥ Offices'],['light','▤ Light industry'],['logistics','▰ Logistics'],['heavy','♨ Heavy industry'],['park','♣ Park'],['plant','⚙ Power plant'],['pump','◉ Water pump'],['tower','◍ Water tower'],['police','✦ Police'],['fire','▲ Fire station'],['school','◆ School'],['hospital','✚ Hospital'],['station','▥ Rail station'],['raise','▲ Raise terrain'],['lower','▼ Lower terrain'],['river','≈ Dig water channel'],['grass','· Grass biome'],['desert','░ Desert biome'],['tree','♠ Tree'],['forest','♣ Forest brush']];
const ZONE_TOOL={res:{zone:'res',type:'house'},apt:{zone:'res',type:'apt'},shop:{zone:'com',type:'shop'},office:{zone:'com',type:'office'},light:{zone:'ind',type:'light'},logistics:{zone:'ind',type:'logistics'},heavy:{zone:'ind',type:'heavy'}};
const TERRAIN_TOOLS=new Set(['raise','lower','river','grass','desert','tree','forest']);
const CATEGORIES={Transport:['road','rail','station'],Zoning:['res','apt','shop','office','light','logistics','heavy'],Utilities:['line','pipe','plant','pump','tower'],Services:['police','fire','school','hospital'],Parks:['park'],Terraform:['raise','lower','river','grass','desert','tree','forest']};""",
    'tool palette and categories',
    re.S,
)

# Terrain/water connectivity + generalized parcel model.
sub(
    r"class ParcelSystem\{.*?\n\}\nconst blank=",
    r'''class TerrainSystem{
 static reflow(w){let q=[],seen=new Uint8Array(COUNT);for(let i=0;i<COUNT;i++){let t=w.tiles[i];if(t.terrain==='water'&&!t.channel){t.waterSource=true}if(t.waterSource&&t.terrain==='water'){seen[i]=1;q.push(i)}}for(let h=0;h<q.length;h++){let i=q[h];for(let j of neighbors(i)){let t=w.tiles[j];if(seen[j]||!t.channel||t.elev>0)continue;seen[j]=1;q.push(j)}}for(let i=0;i<COUNT;i++){let t=w.tiles[i];if(t.channel)t.terrain=seen[i]?'water':'grass'}}
}
class ParcelSystem{
 static invalidate(w){w._parcelAt=null;w._parcels=null}
 static defaultType(zone){return zone==='res'?'house':zone==='com'?'shop':'light'}
 static rebuild(w){let groups=new Map,at=new Array(COUNT).fill(null);for(let i=0;i<COUNT;i++){let t=w.tiles[i];if(!t.zone||!t.parcel)continue;if(!t.zoneType)t.zoneType=t.resType||this.defaultType(t.zone);if(t.zone==='res')t.resType=t.zoneType;let p=groups.get(t.parcel);if(!p){p={id:t.parcel,zone:t.zone,type:t.zoneType,members:[],root:i,anchor:i,minX:N,minY:N,maxX:0,maxY:0};groups.set(t.parcel,p)}p.members.push(i);let [x,y]=xy(i);p.minX=Math.min(p.minX,x);p.minY=Math.min(p.minY,y);p.maxX=Math.max(p.maxX,x);p.maxY=Math.max(p.maxY,y);if(i<p.root)p.root=i;if(i>p.anchor)p.anchor=i}for(let p of groups.values()){p.width=p.maxX-p.minX+1;p.height=p.maxY-p.minY+1;p.area=p.members.length;p.members.forEach(i=>at[i]=p)}w._parcels=groups;w._parcelAt=at;return groups}
 static info(w,i){if(!w._parcelAt)this.rebuild(w);return w._parcelAt[i]||null}
 static roads(w,p){let out=new Set;for(let i of p.members)for(let j of neighbors(i))if(w.tiles[j].road)out.add(j);return [...out]}
 static roadNear(w,i){let p=this.info(w,i);return p?this.roads(w,p).length>0:neighbors(i).some(j=>w.tiles[j].road)}
 static avg(w,p,name){let a=w.fields[name];if(!a||!p)return 0;return p.members.reduce((n,i)=>n+a[i],0)/Math.max(1,p.members.length)}
 static has(w,p,name){let a=w.fields[name];return !!(a&&p&&p.members.some(i=>a[i]))}
 static capacity(w,p,level){if(!p||!level)return 0;let t=w.tiles[p.root],type=t.zoneType||t.resType||p.type||this.defaultType(t.zone),area=p.area,L=Math.min(4,level);if(t.zone==='res'){if(type==='apt'){let base=area===1?14:area===2?30:area===3?48:area*20,m=[0,1,1.55,2.3,3.4][L]||1;return Math.round(base*m)}let base=area===1?5:area===2?8:area===3?12:16+Math.max(0,area-4)*3;return Math.round(base*(1+(Math.min(3,L)-1)*.12))}if(t.zone==='com'){let base=type==='office'?Math.max(10,area*18):Math.max(7,area*11),m=[0,1,1.45,2.05,2.8][L]||1;return Math.round(base*m)}let base=type==='heavy'?Math.max(16,area*20):type==='logistics'?Math.max(12,area*16):Math.max(9,area*12),m=[0,1,1.35,1.8,2.35][L]||1;return Math.round(base*m)}
 static setLevel(w,p,level){for(let i of p.members){w.tiles[i].level=level;if(!level)w.tiles[i].occupancy=0}}
 static setAbandoned(w,p,value){for(let i of p.members)w.tiles[i].abandoned=value}
}
const blank=''',
    'terrain and generalized parcel model',
    re.S,
)
sub(
    r"const blank=\(terrain='grass',tree=false\)=>\(\{.*?\}\);",
    "const blank=(terrain='grass',tree=false)=>({terrain,tree,road:false,rail:false,line:false,pipe:false,zone:null,resType:null,zoneType:null,parcel:0,level:0,occupancy:0,abandoned:0,civic:null,condition:1,fire:0,damage:0,storage:0,elev:0,biome:'grass',channel:false,waterSource:terrain==='water'});",
    'tile schema',
    re.S,
)

replace(" roadNear(i){let t=this.tiles[i];return t?.zone==='res'&&t.parcel?ParcelSystem.roadNear(this,i):neighbors(i).some(j=>this.tiles[j].road)}",
        " roadNear(i){let t=this.tiles[i];return t?.parcel?ParcelSystem.roadNear(this,i):neighbors(i).some(j=>this.tiles[j].road)}",
        'general parcel road access')

# Replace placement logic with subtype parcels and terraforming.
new_placement = r''' canPlace(i,tool,bridge=false){let t=this.tiles[i];if(!t)return false;if(tool==='pan')return false;if(TERRAIN_TOOLS.has(tool)){if(tool==='grass'||tool==='desert')return t.terrain!=='water'&&!t.civic&&!t.level;if(tool==='tree'||tool==='forest')return t.terrain!=='water'&&!t.civic&&!t.road&&!t.rail&&!t.level;if(tool==='river'||tool==='raise'||tool==='lower')return !t.civic&&!t.road&&!t.rail&&!t.level&&!t.zone;return false}if(tool==='bulldoze')return !!(t.road||t.rail||t.line||t.pipe||t.zone||t.civic||t.fire||t.tree||t.channel);if(tool==='pipe')return true;if(tool==='road'||tool==='rail')return !t.civic&&(t.terrain!=='water'||bridge);if(t.terrain==='water')return false;if(tool==='line')return !t.civic;if(ZONE_TOOL[tool])return !t.civic&&!t.road&&!t.rail;if(tool==='park')return !t.civic&&!t.road&&!t.rail&&!t.zone;if(tool==='station')return t.rail&&!t.civic;return !t.civic&&!t.road&&!t.rail&&!t.zone}
 place(i,tool,bridge=false,parcelId=0){if(!this.canPlace(i,tool,bridge))return false;let t=this.tiles[i],cost=COST[tool]+((t.terrain==='water'&&['road','rail'].includes(tool))?COST[tool]*4:0);if(tool==='bulldoze'){if(!this.spend(cost))return false;EditHistory.capture(i,cost);if(t.fire)t.fire=0;else if(t.civic){t.civic=null;t.storage=0}else if(t.zone&&t.level){if(t.parcel){let p=ParcelSystem.info(this,i);for(let j of p.members){if(j!==i)EditHistory.capture(j,0);this.tiles[j].level=0;this.tiles[j].occupancy=0;this.tiles[j].abandoned=0;this.tiles[j].damage=0}}else{t.level=0;t.occupancy=0;t.abandoned=0}}else if(t.zone){t.zone=null;t.resType=null;t.zoneType=null;t.parcel=0}else if(t.road)t.road=false;else if(t.rail)t.rail=false;else if(t.line)t.line=false;else if(t.pipe)t.pipe=false;else if(t.channel){t.channel=false;t.terrain='grass'}else t.tree=false;TerrainSystem.reflow(this);ParcelSystem.invalidate(this);return true}
 if(TERRAIN_TOOLS.has(tool)){if(!this.spend(cost))return false;EditHistory.capture(i,cost);if(tool==='raise'){t.elev=clamp((t.elev||0)+1,-3,5);if(t.elev>0&&t.channel)t.terrain='grass'}else if(tool==='lower'){t.elev=clamp((t.elev||0)-1,-3,5)}else if(tool==='river'){t.channel=true;t.waterSource=false;t.elev=Math.min(-1,t.elev||0);t.terrain='grass';t.tree=false}else if(tool==='grass'){t.biome='grass'}else if(tool==='desert'){t.biome='desert';t.tree=false}else if(tool==='tree'){t.tree=true;t.biome='grass'}else if(tool==='forest'){t.tree=true;t.biome='grass'}TerrainSystem.reflow(this);Renderer.dirty=true;return true}
 let meta=ZONE_TOOL[tool];if(tool==='road'&&t.road||tool==='rail'&&t.rail||tool==='line'&&t.line||tool==='pipe'&&t.pipe||meta&&t.zone===meta.zone&&t.zoneType===meta.type||tool==='park'&&t.civic==='park')return false;if(!this.spend(cost))return false;EditHistory.capture(i,cost);if(tool==='road'){t.road=true;t.tree=false;t.zone=null;t.resType=null;t.zoneType=null;t.parcel=0;t.level=0;t.occupancy=0;t.condition=1}else if(tool==='rail'){t.rail=true;t.tree=false;t.zone=null;t.resType=null;t.zoneType=null;t.parcel=0;t.level=0;t.occupancy=0}else if(tool==='line')t.line=true;else if(tool==='pipe')t.pipe=true;else if(meta){t.zone=meta.zone;t.zoneType=meta.type;t.resType=meta.zone==='res'?meta.type:null;t.parcel=parcelId||this.nextParcelId++;t.level=0;t.occupancy=0;t.abandoned=0;t.tree=false}else{t.civic=tool;t.tree=false;if(tool==='tower')t.storage=0}ParcelSystem.invalidate(this);return true}
'''
sub(r" canPlace\(i,tool,bridge=false\)\{.*?\n ParcelSystem\.invalidate\(this\);return true\}\n serialize\(\)", new_placement + " serialize()", 'placement methods', re.S)
replace('return {version:5,seed:this.seed', 'return {version:6,seed:this.seed', 'save version')
replace(' recalculate(){ParcelSystem.rebuild(this);UtilityNetwork.update(this);', ' recalculate(){TerrainSystem.reflow(this);ParcelSystem.rebuild(this);UtilityNetwork.update(this);', 'terrain reflow on recalc')

# Backward-compatible loading: old saves acquire new terrain fields and zoning subtype defaults.
replace("w.tiles=obj.tiles.map(t=>Object.assign(blank(),t));", "w.tiles=obj.tiles.map(t=>{let q=Object.assign(blank(),t);if(q.terrain==='water'&&!q.channel)q.waterSource=true;if(!q.biome)q.biome='grass';if(!Number.isFinite(q.elev))q.elev=0;if(q.zone&&!q.zoneType)q.zoneType=q.resType||ParcelSystem.defaultType(q.zone);if(q.zone==='res'&&!q.resType)q.resType=q.zoneType;return q});", 'save migration')

# Utilities should treat every multi-tile parcel as one connected consumer.
text = text.replace("let resConsumers=new Set;", "let parcelConsumers=new Set;", 1)
text = text.replace("let t=tiles[i],p=t.zone==='res'&&t.parcel?ParcelSystem.info(w,i):null;if(p){if(resConsumers.has(p.id)||i!==p.root)continue;resConsumers.add(p.id)}", "let t=tiles[i],p=t.parcel?ParcelSystem.info(w,i):null;if(p){if(parcelConsumers.has(p.id)||i!==p.root)continue;parcelConsumers.add(p.id)}", 1)
text = text.replace("if(t.zone==='res'&&t.parcel){let q=ParcelSystem.info(w,i);", "if(t.parcel){let q=ParcelSystem.info(w,i);", 1)

# Generic parcel simulation for residential, commercial, and industrial.
population_class = r'''class PopulationSimulation{
 static update(w){ParcelSystem.rebuild(w);let s=w.stats,f=w.fields,tiles=w.tiles;let capacity={res:0,com:0,ind:0},occupied={res:0,com:0,ind:0},developed={res:0,com:0,ind:0},abandoned=0,seen=new Set;for(let i=0;i<COUNT;i++){let t=tiles[i];if(t.parcel){let p=ParcelSystem.info(w,i);if(!p||seen.has(p.id))continue;seen.add(p.id);t=tiles[p.root];if(t.abandoned)abandoned++;if(!t.level)continue;let c=ParcelSystem.capacity(w,p,t.level);capacity[t.zone]+=c;developed[t.zone]++;let access=ParcelSystem.roadNear(w,p.root),utilities=ParcelSystem.has(w,p,'power')&&ParcelSystem.has(w,p,'water'),value=ParcelSystem.avg(w,p,'landValue'),poll=ParcelSystem.avg(w,p,'pollution'),crime=ParcelSystem.avg(w,p,'crime'),pen=t.zone==='res'?poll*.002:poll*.0007,quality=clamp(.88+(value-50)*.004-pen-crime*.0015,.35,1),occ=utilities&&access&&!t.abandoned&&!t.fire?Math.round(c*quality):Math.round(t.occupancy*.65);t.occupancy=occ;for(let j of p.members)if(j!==p.root)tiles[j].occupancy=0;occupied[t.zone]+=occ;continue}if(t.abandoned)abandoned++;if(!t.zone||!t.level)continue;let c=CONFIG.buildingCapacity[t.zone][t.level];capacity[t.zone]+=c;developed[t.zone]++;let viable=w.roadNear(i)&&f.power[i]&&f.water[i]&&!t.abandoned&&!t.fire,quality=clamp(.88+(f.landValue[i]-50)*.004-f.pollution[i]*.002-f.crime[i]*.0015,.35,1);t.occupancy=viable?Math.round(c*quality):Math.round(t.occupancy*.65);occupied[t.zone]+=t.occupancy}
 let group=new Int16Array(COUNT).fill(-1),parts=[];for(let i=0;i<COUNT;i++)if(tiles[i].road&&group[i]<0){let id=parts.length,q=[i];parts.push({res:0,jobs:0});group[i]=id;for(let p=0;p<q.length;p++)for(let j of neighbors(q[p]))if(tiles[j].road&&group[j]<0){group[j]=id;q.push(j)}}let counted=new Set;for(let i=0;i<COUNT;i++){let t=tiles[i],p=t.parcel?ParcelSystem.info(w,i):null;if(p){if(counted.has(p.id)||i!==p.root)continue;counted.add(p.id)}if(!t.zone||!t.occupancy)continue;let roads=p?ParcelSystem.roads(w,p):neighbors(i).filter(k=>tiles[k].road),j=roads[0];if(j===undefined)continue;let id=group[j];if(id<0)continue;parts[id][t.zone==='res'?'res':'jobs']+=t.occupancy}
 let jobs=occupied.com+occupied.ind,population=occupied.res,employed=parts.reduce((n,p)=>n+Math.min(p.res,p.jobs),0),unemployment=population?Math.round(100*(population-employed)/population):0;Object.assign(s,{population,resCapacity:capacity.res,commercialCapacity:capacity.com,industrialCapacity:capacity.ind,jobs,commercialJobs:occupied.com,industrialJobs:occupied.ind,employed,unemployment,developed,abandoned,capacity,occupied})}
 static growthScore(w,i){let t=w.tiles[i],p=t.parcel?ParcelSystem.info(w,i):null,f=w.fields,demand=w.demand[t.zone],rate=w.taxes[t.zone],value=p?ParcelSystem.avg(w,p,'landValue'):f.landValue[i],poll=p?ParcelSystem.avg(w,p,'pollution'):f.pollution[i],crime=p?ParcelSystem.avg(w,p,'crime'):f.crime[i],utility=p?(ParcelSystem.has(w,p,'power')&&ParcelSystem.has(w,p,'water')):(f.power[i]&&f.water[i]),service=p?(ParcelSystem.avg(w,p,'school')+ParcelSystem.avg(w,p,'hospital'))*.5:(f.school[i]+f.hospital[i])*.5,traffic=p?ParcelSystem.avg(w,p,'trafficImpact'):f.trafficImpact[i],score=18+demand*.65+(value-48)*.53+service*11-poll*(t.zone==='res'?.30:t.zone==='ind'?.035:.1)-crime*.10-(rate-8)*3-traffic*.12;if(!utility)score-=100;if(t.zone==='com'&&w.stats.population<35)score-=28;if(t.zone==='ind'&&w.stats.population<10)score-=10;if(t.zone==='res'&&w.stats.jobs<10)score-=20;if(p){let type=t.zoneType||t.resType;if(type==='office'&&w.stats.population<90)score-=24;if(type==='logistics'&&p.area<2)score-=55;if(type==='heavy'&&p.area<4)score-=80;if(type==='apt'&&p.area>1)score+=5;if(type==='shop'&&w.stats.population>80)score+=5}if(t.fire)score-=120;return score}
 static develop(w){let tiles=w.tiles,candidates=[],seen=new Set;for(let i=0;i<COUNT;i++){let t=tiles[i],p=t.parcel?ParcelSystem.info(w,i):null,target=i;if(p){if(seen.has(p.id))continue;seen.add(p.id);target=p.root;t=tiles[target]}if(!t.zone||!w.roadNear(target))continue;let score=this.growthScore(w,target)+hash(target,w.tick,w.seed)*16-8;candidates.push({i:target,score})}candidates.sort((a,b)=>b.score-a.score);let growLimit=clamp(Math.ceil(candidates.length*.05),2,14),grown=0;for(let {i,score} of candidates){let t=tiles[i],p=t.parcel?ParcelSystem.info(w,i):null,type=t.zoneType||t.resType,max=t.zone==='res'?(type==='apt'?4:3):type==='office'||type==='heavy'?4:3,level=t.level,ab=t.abandoned,damage=t.damage;if(score>17&&grown<growLimit){if(ab&&score>20){ab=0;level=Math.max(1,level);damage=0;grown++}else if(!ab&&level<max&&score>(level?22+level*19:17)){level++;grown++}}else if(score<-38&&level){damage+=.18;if(damage>1){ab=1;damage=0}}else damage=Math.max(0,damage-.08);if(p){ParcelSystem.setLevel(w,p,level);ParcelSystem.setAbandoned(w,p,ab);tiles[p.root].damage=damage}else{t.level=level;t.abandoned=ab;t.damage=damage}}
 }
}
'''
sub(r"class PopulationSimulation\{.*?\nclass DemandSimulation", population_class + "class DemandSimulation", 'population simulation', re.S)

# Parcel-aware zoning visuals: fill each member, but draw only outside edges.
replace("if(t.zone){c.fillStyle=ZCOL[t.zone]+'55';c.fillRect(px+1,py+1,S-2,S-2);c.strokeStyle=ZCOL[t.zone];c.lineWidth=1;c.strokeRect(px+2,py+2,S-4,S-4)}",
        "if(t.zone){if(t.parcel){let p=ParcelSystem.info(w,i);if(p)this.drawParcelZoneTile(w,p,i,px,py,S)}else{c.fillStyle=ZCOL[t.zone]+'55';c.fillRect(px+1,py+1,S-2,S-2);c.strokeStyle=ZCOL[t.zone];c.lineWidth=1;c.strokeRect(px+2,py+2,S-4,S-4)}}",
        'parcel zoning visuals')
replace("if(t.level){if(t.zone==='res'&&t.parcel){let p=ParcelSystem.info(w,i);if(p&&i===p.anchor)this.drawResidentialParcel(w,p,S)}else this.drawBuilding(t,px,py,S)}",
        "if(t.level){if(t.parcel){let p=ParcelSystem.info(w,i);if(p&&i===p.anchor)this.drawParcelDevelopment(w,p,S)}else this.drawBuilding(t,px,py,S)}",
        'parcel development dispatch')

# Terrain tint/elevation/channel details just before trees.
replace("if(t.tree&&t.terrain==='grass'&&!t.road&&!t.civic&&!t.level){",
        "if(t.terrain==='grass'&&t.biome==='desert'){c.fillStyle='#c9ad69cc';c.fillRect(px,py,S,S);if(hash(i,w.seed,91)>.6){c.fillStyle='#9b844e';c.fillRect(px+S*.2,py+S*.62,S*.12,S*.04);c.fillRect(px+S*.67,py+S*.3,S*.16,S*.035)}}if((t.elev||0)!==0&&t.terrain!=='water'){c.fillStyle=t.elev>0?'#ffffff12':'#26382b22';c.fillRect(px,py,S,S);if(t.elev>=3){c.fillStyle='#7d7566';c.beginPath();c.moveTo(px+S*.18,py+S*.78);c.lineTo(px+S*.48,py+S*.22);c.lineTo(px+S*.82,py+S*.78);c.fill();c.fillStyle='#c9c5b9';c.beginPath();c.moveTo(px+S*.38,py+S*.4);c.lineTo(px+S*.48,py+S*.22);c.lineTo(px+S*.59,py+S*.41);c.fill()}}if(t.channel&&t.terrain!=='water'){c.fillStyle='#4e473c';c.fillRect(px+S*.18,py+S*.39,S*.64,S*.22);c.fillStyle='#756958';c.fillRect(px+S*.23,py+S*.44,S*.54,S*.12)}if(t.tree&&t.terrain==='grass'&&!t.road&&!t.civic&&!t.level){",
        'terrain rendering')

parcel_render_methods = r''' drawParcelZoneTile(w,p,i,x,y,S){let c=this.ctx,t=w.tiles[p.root],type=t.zoneType||t.resType||p.type,base=t.zone==='res'?'#85dca3':t.zone==='com'?'#5aa8ed':'#dcac75',fill=base+'55';if(type==='office')fill='#68c5dc55';else if(type==='heavy')fill='#bc865b66';else if(type==='logistics')fill='#d6a35f60';else if(type==='apt')fill='#65c98d60';c.fillStyle=fill;c.fillRect(x,y,S,S);c.strokeStyle=base;c.lineWidth=Math.max(1,S*.05);let same=j=>j>=0&&j<COUNT&&w.tiles[j].parcel===p.id;c.beginPath();if(!same(i-N)){c.moveTo(x,y);c.lineTo(x+S,y)}if(!same(i+N)){c.moveTo(x,y+S);c.lineTo(x+S,y+S)}if(i%N===0||!same(i-1)){c.moveTo(x,y);c.lineTo(x,y+S)}if(i%N===N-1||!same(i+1)){c.moveTo(x+S,y);c.lineTo(x+S,y+S)}c.stroke()}
 drawParcelDevelopment(w,p,S){let t=w.tiles[p.root];if(t.zone==='res')this.drawResidentialParcel(w,p,S);else if(t.zone==='com')this.drawCommercialParcel(w,p,S);else this.drawIndustrialParcel(w,p,S)}
 drawCommercialParcel(w,p,S){let c=this.ctx,t=w.tiles[p.root],type=t.zoneType||'shop',x=this.cx+p.minX*S,y=this.cy+p.minY*S,W=p.width*S,H=p.height*S,v=Math.floor(hash(p.id,w.seed,211)*4),ab=!!t.abandoned;c.save();c.fillStyle=ab?'#646967':'#7f8f86';c.fillRect(x+2,y+2,W-4,H-4);if(type==='shop'){c.fillStyle=ab?'#666':'#d7c9a4';let bx=x+W*.1,by=y+H*.18,bw=W*.68,bh=H*.45;c.fillRect(bx,by,bw,bh);c.fillStyle=['#9f4545','#3f7798','#6f8c55','#b7753d'][v];c.fillRect(bx,by,bw,bh*.2);c.fillStyle='#c9e2df';let n=Math.max(2,Math.min(6,p.area+1));for(let k=0;k<n;k++)c.fillRect(bx+bw*(.08+k*.84/n),by+bh*.33,bw*.09,bh*.34);c.fillStyle='#41474a';c.fillRect(x+W*.12,y+H*.72,W*.72,H*.16);c.strokeStyle='#ded7b9';c.lineWidth=1;for(let k=1;k<5;k++){c.beginPath();c.moveTo(x+W*(.12+k*.14),y+H*.72);c.lineTo(x+W*(.12+k*.14),y+H*.88);c.stroke()}}else{let bx=x+W*.2,by=y+H*.16,bw=W*.55,bh=H*.62,h=Math.min(H*.75,S*(.35+t.level*.22));c.fillStyle=ab?'#697175':['#8cb2ba','#a7a9a8','#8da2b6','#9db6aa'][v];c.fillRect(bx,by+bh-h,bw,h);c.fillStyle='#bdd8df';let cols=Math.max(2,Math.min(7,p.width*2)),rows=Math.max(2,Math.min(6,t.level+2));for(let r=0;r<rows;r++)for(let k=0;k<cols;k++)c.fillRect(bx+bw*(k+.18)/cols,by+bh-h+h*(r+.2)/rows,bw*.09/cols*3,h*.08);c.fillStyle='#4d5659';c.fillRect(bx+bw*.18,by+bh-h-S*.07,S*.11,S*.07);c.fillRect(bx+bw*.58,by+bh-h-S*.06,S*.1,S*.06)}c.restore()}
 drawIndustrialParcel(w,p,S){let c=this.ctx,t=w.tiles[p.root],type=t.zoneType||'light',x=this.cx+p.minX*S,y=this.cy+p.minY*S,W=p.width*S,H=p.height*S,ab=!!t.abandoned;c.save();c.fillStyle=ab?'#68655f':'#77736b';c.fillRect(x+2,y+2,W-4,H-4);if(type==='logistics'){let bx=x+W*.08,by=y+H*.15,bw=W*.72,bh=H*.5;c.fillStyle=ab?'#70706b':'#c4b89d';c.fillRect(bx,by,bw,bh);c.fillStyle='#8d6f4d';c.fillRect(bx,by,bw,bh*.16);for(let k=0;k<Math.max(2,Math.min(6,p.width+2));k++){c.fillStyle='#3e4447';c.fillRect(bx+bw*(.08+k*.14),by+bh*.62,bw*.09,bh*.28)}c.fillStyle='#4b5051';c.fillRect(x+W*.09,y+H*.73,W*.8,H*.13);for(let k=0;k<Math.min(4,p.area);k++){c.fillStyle=['#b95745','#4c78a0','#d0b14c','#eee4cc'][k%4];c.fillRect(x+W*(.14+k*.16),y+H*.76,W*.1,H*.055)}}else if(type==='heavy'){let bx=x+W*.12,by=y+H*.26,bw=W*.48,bh=H*.45;c.fillStyle=ab?'#666':'#8d877b';c.fillRect(bx,by,bw,bh);c.fillStyle='#4e5152';for(let k=0;k<Math.min(3,Math.max(1,p.area//2));k++){}c.fillRect(x+W*.62,y+H*.1,W*.09,H*.58);c.fillStyle='#b45f45';c.fillRect(x+W*.63,y+H*.08,W*.07,H*.1);c.fillStyle='#b3aaa0';c.beginPath();c.arc(x+W*.75,y+H*.58,Math.max(3,S*.18),0,7);c.fill();c.beginPath();c.arc(x+W*.48,y+H*.72,Math.max(3,S*.14),0,7);c.fill();c.strokeStyle='#443f3a';c.lineWidth=Math.max(1,S*.05);c.strokeRect(bx,by,bw,bh)}else{let bx=x+W*.1,by=y+H*.22,bw=W*.68,bh=H*.47;c.fillStyle=ab?'#676a67':'#aaa28d';c.fillRect(bx,by,bw,bh);c.fillStyle='#6d6256';let teeth=Math.max(2,Math.min(6,p.width+2));for(let k=0;k<teeth;k++){c.beginPath();c.moveTo(bx+bw*k/teeth,by);c.lineTo(bx+bw*(k+.45)/teeth,by-S*.12);c.lineTo(bx+bw*(k+1)/teeth,by);c.fill()}c.fillStyle='#31383a';for(let k=0;k<Math.max(2,p.width);k++)c.fillRect(bx+bw*(.12+k*.22),by+bh*.62,bw*.1,bh*.2)}c.restore()}
'''
replace(" drawResidentialParcel(w,p,S){", parcel_render_methods + " drawResidentialParcel(w,p,S){", 'parcel renderer methods')

# Parcel IDs for every zoning subtype.
replace("this.parcelId=['res','apt'].includes(this.tool)?world.nextParcelId++:0;", "this.parcelId=ZONE_TOOL[this.tool]?world.nextParcelId++:0;", 'parcel input ids')

# UI zoning status works for every subtype; terraforming gets concise live feedback.
sub(r" afterPlacement\(\)\{.*?\n toast\(s\)\{", r''' afterPlacement(){let k=Input.tool,s=world.stats;if(['pipe','pump','tower'].includes(k))this.$('status').textContent=`Water: ${s.waterUsed||0}/${s.waterCapacity||0} available · ${s.waterPumped||0} pumped · ${s.waterStored||0} stored · ${s.unwatered||0} buildings missing water. Power the pump and connect pipes.`;else if(['line','plant'].includes(k))this.$('status').textContent=`Power: ${s.powerUsed||0}/${s.powerGenerated||0} capacity · ${s.unpowered||0} developed buildings missing power.`;else if(ZONE_TOOL[k]){let meta=ZONE_TOOL[k],n={road:0,power:0,water:0,ready:0,parcels:new Set};world.tiles.forEach((t,i)=>{if(t.zone!==meta.zone||t.zoneType!==meta.type||t.level)return;let p=t.parcel?ParcelSystem.info(world,i):null,key=p?p.id:i;if(n.parcels.has(key))return;n.parcels.add(key);let road=world.roadNear(i),power=p?ParcelSystem.has(world,p,'power'):!!world.fields.power[i],water=p?ParcelSystem.has(world,p,'water'):!!world.fields.water[i];if(!road)n.road++;if(!power)n.power++;if(!water)n.water++;if(road&&power&&water)n.ready++});this.$('status').textContent=`Empty ${TOOLS.find(t=>t[0]===k)?.[1].replace(/^[^ ]+ /,'')} parcels: ${n.ready} ready · ${n.road} need road · ${n.power} need power · ${n.water} need water.`}else if(TERRAIN_TOOLS.has(k))this.$('status').textContent=k==='river'?'Channels fill only when connected to existing water. Disconnected cuts stay dry.':k==='raise'||k==='lower'?'Elevation changed. Repeat to sculpt hills, valleys, and mountains.':k==='desert'?'Desert biome painted. Trees are cleared on converted tiles.':'Terraforming applied.'}
 toast(s){''', 'after placement status', re.S)

# General parcel inspection details and elevation/biome info.
sub(r" refreshSelection\(\)\{.*?\n refreshGrowthHint\(\)", r''' refreshSelection(){let i=world.selected;if(i<0){this.$('details').innerHTML='';return;}let t=world.tiles[i],f=world.fields,p=t.parcel?ParcelSystem.info(world,i):null,root=p?world.tiles[p.root]:t,type=root.zoneType||root.resType,kind=t.civic||(p?`${type} ${root.zone}`:t.zone)||t.terrain,extra=t.civic==='tower'?`<br>Stored water: ${Math.round(t.storage||0)}/${CONFIG.waterTowerCapacity}`:t.civic==='pump'?`<br>Pump output: ${f.power[i]?(neighbors(i).some(j=>world.tiles[j].terrain==='water')?CONFIG.waterPumpCapacity:Math.round(CONFIG.waterPumpCapacity*.55)):0} (needs electricity)`:p?`<br>Parcel: ${p.width}×${p.height} · ${p.area} tile${p.area===1?'':'s'} · ${type}<br>Parcel capacity: ${ParcelSystem.capacity(world,p,root.level)||0}`:'';let occ=p?root.occupancy:t.occupancy,power=p?ParcelSystem.has(world,p,'power'):!!f.power[i],water=p?ParcelSystem.has(world,p,'water'):!!f.water[i];this.$('details').innerHTML=`Tile ${i%N+1}, ${(i/N|0)+1} · ${kind}${root.level?' level '+root.level:''}${root.abandoned?' · ABANDONED':''}<br>Occupants/jobs: ${occ} · road: ${t.road?'yes':p&&ParcelSystem.roadNear(world,i)?'parcel access':'no'} · rail: ${t.rail?'yes':'no'}<br>Power: ${power?'yes':'no'} · water: ${water?'yes':'no'}${extra}<br>Terrain: ${t.biome||'grass'} · elevation ${t.elev||0}${t.channel?` · ${t.terrain==='water'?'water-filled channel':'dry channel'}`:''}<br>Land value: ${Math.round(p?ParcelSystem.avg(world,p,'landValue'):f.landValue[i])} · pollution: ${Math.round(p?ParcelSystem.avg(world,p,'pollution'):f.pollution[i])} · crime: ${Math.round(p?ParcelSystem.avg(world,p,'crime'):f.crime[i])}`}
 refreshGrowthHint()''', 'selection details', re.S)

# Inject basic help text for new tools by extending existing help object.
replace("apt:'Apartment lots use the same parcel system. Larger lots can support courtyard buildings and eventually towers.',com:'Commerce needs residents, an adjacent road, power, water, and demand.',ind:'Industry needs an adjacent road, power, water, and demand; it provides early jobs.'",
        "apt:'Apartment lots use the same parcel system. Larger lots can support courtyard buildings and eventually towers.',shop:'Shops and services prefer population and road access. Each stroke is one commercial property.',office:'Offices support denser jobs with less freight; they need a stronger population base.',light:'Light industry fits smaller sites and creates moderate pollution.',logistics:'Logistics works best on parcels of at least 2 tiles and creates freight-heavy employment.',heavy:'Heavy industry wants parcels of at least 4 tiles and has the strongest pollution footprint.',raise:'Raise natural terrain one elevation step. Repeat to form hills and mountains.',lower:'Lower natural terrain one elevation step. Repeat to form valleys and basins.',river:'Dig a channel. It only fills when connected to existing water.',grass:'Paint grass biome.',desert:'Paint desert biome and clear trees.',tree:'Place an individual tree.',forest:'Drag to plant forest quickly.'",
        'tool help')

# Ensure generalized parcel utility consumers use parcel capacity for all zones.
text = text.replace("p?Math.max(2,Math.ceil(ParcelSystem.capacity(w,p,t.level)*.105)):Math.max(2,Math.ceil(CONFIG.buildingCapacity[t.zone][t.level]*.105))", "p?Math.max(2,Math.ceil(ParcelSystem.capacity(w,p,t.level)*.105)):Math.max(2,Math.ceil(CONFIG.buildingCapacity[t.zone][t.level]*.105))", 1)

# Sanity markers.
required = [
    "shop:{zone:'com',type:'shop'}",
    "heavy:{zone:'ind',type:'heavy'}",
    "class TerrainSystem",
    "drawParcelZoneTile",
    "drawCommercialParcel",
    "drawIndustrialParcel",
    "sensorLandscape" if False else "class PopulationSimulation",
]
missing = [token for token in required if token not in text]
if missing:
    raise SystemExit('Upgrade validation failed; missing: ' + ', '.join(missing))

path.write_text(text)
print('MetroForge city systems upgrade applied:', len(original), '->', len(text), 'bytes')
