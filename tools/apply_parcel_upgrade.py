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

replace(
    '<button id="placementMode" type="button" title="Switch between drag painting and tap-to-place with drag panning">Mode: Paint drag</button>',
    '<button id="placementMode" class="mode-tap" type="button" title="Switch between drag painting and tap-to-place with drag panning">Mode: Tap + pan</button>',
    'placement mode markup',
)
replace('pipe:12,res:9,com:12', 'pipe:12,res:9,apt:14,com:12', 'apartment zoning cost')
replace("['res','⌂ Residential'],['com','▣ Commercial']", "['res','⌂ House lots'],['apt','▥ Apartment lots'],['com','▣ Commercial']", 'zoning tool labels')
replace("Zoning:['res','com','ind']", "Zoning:['res','apt','com','ind']", 'zoning category')

parcel_helpers = r'''
class ParcelSystem{
 static invalidate(w){w._parcelAt=null;w._parcels=null}
 static rebuild(w){let groups=new Map,at=new Array(COUNT).fill(null);for(let i=0;i<COUNT;i++){let t=w.tiles[i];if(t.zone!=='res')continue;if(!t.parcel)t.parcel=1000000+i;if(!t.resType)t.resType='house';let p=groups.get(t.parcel);if(!p){p={id:t.parcel,type:t.resType,members:[],root:i,anchor:i,minX:N,minY:N,maxX:0,maxY:0};groups.set(t.parcel,p)}p.members.push(i);let [x,y]=xy(i);p.minX=Math.min(p.minX,x);p.minY=Math.min(p.minY,y);p.maxX=Math.max(p.maxX,x);p.maxY=Math.max(p.maxY,y);if(i<p.root)p.root=i;if(i>p.anchor)p.anchor=i}for(let p of groups.values()){p.width=p.maxX-p.minX+1;p.height=p.maxY-p.minY+1;p.area=p.members.length;p.members.forEach(i=>at[i]=p)}w._parcels=groups;w._parcelAt=at;return groups}
 static info(w,i){if(!w._parcelAt)this.rebuild(w);return w._parcelAt[i]||null}
 static roads(w,p){let out=new Set;for(let i of p.members)for(let j of neighbors(i))if(w.tiles[j].road)out.add(j);return [...out]}
 static roadNear(w,i){let p=this.info(w,i);return p?this.roads(w,p).length>0:neighbors(i).some(j=>w.tiles[j].road)}
 static avg(w,p,name){let a=w.fields[name];if(!a||!p)return 0;return p.members.reduce((n,i)=>n+a[i],0)/Math.max(1,p.members.length)}
 static has(w,p,name){let a=w.fields[name];return !!(a&&p&&p.members.some(i=>a[i]))}
 static capacity(w,p,level){if(!p||!level)return 0;let type=w.tiles[p.root].resType||p.type||'house',area=p.area;if(type==='apt'){let base=area===1?14:area===2?30:area===3?48:area*20,m=[0,1,1.55,2.3,3.4][Math.min(4,level)]||1;return Math.round(base*m)}let base=area===1?5:area===2?8:area===3?12:16+Math.max(0,area-4)*3;return Math.round(base*(1+(Math.min(3,level)-1)*.12))}
 static setLevel(w,p,level){for(let i of p.members){w.tiles[i].level=level;if(!level)w.tiles[i].occupancy=0}}
 static setAbandoned(w,p,value){for(let i of p.members)w.tiles[i].abandoned=value}
}
'''
replace("const blank=(terrain='grass',tree=false)=>({terrain,tree,road:false,rail:false,line:false,pipe:false,zone:null,level:0,occupancy:0,abandoned:0,civic:null,condition:1,fire:0,damage:0,storage:0});",
        parcel_helpers + "const blank=(terrain='grass',tree=false)=>({terrain,tree,road:false,rail:false,line:false,pipe:false,zone:null,resType:null,parcel:0,level:0,occupancy:0,abandoned:0,civic:null,condition:1,fire:0,damage:0,storage:0});",
        'parcel helpers and tile schema')
replace("this.demand={res:60,com:25,ind:70};this.selected=-1;this.generate();this.recalculate()",
        "this.demand={res:60,com:25,ind:70};this.selected=-1;this.nextParcelId=1;this.generate();this.recalculate()",
        'world parcel counter')
replace(" roadNear(i){return neighbors(i).some(j=>this.tiles[j].road)}",
        " roadNear(i){let t=this.tiles[i];return t?.zone==='res'&&t.parcel?ParcelSystem.roadNear(this,i):neighbors(i).some(j=>this.tiles[j].road)}",
        'parcel road access')

new_placement = r''' canPlace(i,tool,bridge=false){let t=this.tiles[i];if(!t)return false;if(tool==='pan')return false;if(tool==='bulldoze')return !!(t.road||t.rail||t.line||t.pipe||t.zone||t.civic||t.fire||t.tree);if(tool==='pipe')return true;if(tool==='road'||tool==='rail')return !t.civic&&(t.terrain!=='water'||bridge);if(t.terrain==='water')return false;if(tool==='line')return !t.civic;if(['res','apt','com','ind'].includes(tool))return !t.civic&&!t.road&&!t.rail;if(tool==='park')return !t.civic&&!t.road&&!t.rail&&!t.zone;if(tool==='station')return t.rail&&!t.civic;return !t.civic&&!t.road&&!t.rail&&!t.zone}
 place(i,tool,bridge=false,parcelId=0){if(!this.canPlace(i,tool,bridge))return false;let t=this.tiles[i],cost=COST[tool]+((t.terrain==='water'&&['road','rail'].includes(tool))?COST[tool]*4:0);if(tool==='bulldoze'){if(!this.spend(cost))return false;EditHistory.capture(i,cost);if(t.fire)t.fire=0;else if(t.civic){t.civic=null;t.storage=0}else if(t.zone&&t.level){if(t.zone==='res'&&t.parcel){let p=ParcelSystem.info(this,i);for(let j of p.members){if(j!==i)EditHistory.capture(j,0);this.tiles[j].level=0;this.tiles[j].occupancy=0;this.tiles[j].abandoned=0;this.tiles[j].damage=0}}else{t.level=0;t.occupancy=0;t.abandoned=0}}else if(t.zone){t.zone=null;t.resType=null;t.parcel=0}else if(t.road)t.road=false;else if(t.rail)t.rail=false;else if(t.line)t.line=false;else if(t.pipe)t.pipe=false;else t.tree=false;ParcelSystem.invalidate(this);return true}
 let targetZone=tool==='apt'?'res':tool;if(tool==='road'&&t.road||tool==='rail'&&t.rail||tool==='line'&&t.line||tool==='pipe'&&t.pipe||['res','apt','com','ind'].includes(tool)&&t.zone===targetZone&&(tool!=='apt'||t.resType==='apt')&&(tool!=='res'||t.resType!=='apt')||tool==='park'&&t.civic==='park')return false;
 if(!this.spend(cost))return false;EditHistory.capture(i,cost);
 if(tool==='road'){t.road=true;t.tree=false;t.zone=null;t.resType=null;t.parcel=0;t.level=0;t.occupancy=0;t.condition=1}
 else if(tool==='rail'){t.rail=true;t.tree=false;t.zone=null;t.resType=null;t.parcel=0;t.level=0;t.occupancy=0}
 else if(tool==='line')t.line=true;
 else if(tool==='pipe')t.pipe=true;
 else if(['res','apt','com','ind'].includes(tool)){t.zone=targetZone;t.level=0;t.occupancy=0;t.abandoned=0;t.tree=false;if(targetZone==='res'){t.resType=tool==='apt'?'apt':'house';t.parcel=parcelId||this.nextParcelId++}else{t.resType=null;t.parcel=0}}
 else {t.civic=tool;t.tree=false;if(tool==='tower')t.storage=0}
 ParcelSystem.invalidate(this);return true}
'''
sub(r" canPlace\(i,tool,bridge=false\)\{.*?\n return true\}\n serialize\(\)", new_placement + " serialize()", 'placement methods', re.S)
replace("return {version:4,seed:this.seed,tiles:this.tiles,cash:this.cash,year:this.year,month:this.month,tick:this.tick,taxes:this.taxes,funding:this.funding,randomDisasters:this.randomDisasters,bondMonths:this.bondMonths,milestones:this.milestones,messages:this.messages,events:this.events,stats:this.stats,cars:this.cars||[],trains:this.trains||[]}",
        "return {version:5,seed:this.seed,tiles:this.tiles,cash:this.cash,year:this.year,month:this.month,tick:this.tick,taxes:this.taxes,funding:this.funding,randomDisasters:this.randomDisasters,bondMonths:this.bondMonths,milestones:this.milestones,messages:this.messages,events:this.events,stats:this.stats,cars:this.cars||[],trains:this.trains||[],nextParcelId:this.nextParcelId}",
        'save version')
replace("w.cars=obj.cars||[];w.trains=obj.trains||[];w.recalculate();",
        "w.cars=obj.cars||[];w.trains=obj.trains||[];w.nextParcelId=Math.max(1,Number(obj.nextParcelId)||1);ParcelSystem.invalidate(w);w.recalculate();",
        'load parcel state')
replace(" recalculate(){UtilityNetwork.update(this);ServiceSystem.update(this);Environment.update(this);PopulationSimulation.update(this);DemandSimulation.update(this);TrafficSystem.prepare(this);Economy.calculate(this)}",
        " recalculate(){ParcelSystem.rebuild(this);UtilityNetwork.update(this);ServiceSystem.update(this);Environment.update(this);PopulationSimulation.update(this);DemandSimulation.update(this);TrafficSystem.prepare(this);Economy.calculate(this)}",
        'recalculate parcel index')

population_class = r'''class PopulationSimulation{
 static update(w){ParcelSystem.rebuild(w);let s=w.stats,f=w.fields,tiles=w.tiles;let capacity={res:0,com:0,ind:0},occupied={res:0,com:0,ind:0},developed={res:0,com:0,ind:0},abandoned=0,seen=new Set;for(let i=0;i<COUNT;i++){let t=tiles[i];if(t.zone==='res'&&t.parcel){let p=ParcelSystem.info(w,i);if(!p||seen.has(p.id))continue;seen.add(p.id);t=tiles[p.root];if(t.abandoned)abandoned++;if(!t.level)continue;let c=ParcelSystem.capacity(w,p,t.level);capacity.res+=c;developed.res++;let access=ParcelSystem.roadNear(w,p.root),utilities=ParcelSystem.has(w,p,'power')&&ParcelSystem.has(w,p,'water'),value=ParcelSystem.avg(w,p,'landValue'),poll=ParcelSystem.avg(w,p,'pollution'),crime=ParcelSystem.avg(w,p,'crime'),quality=clamp(.88+(value-50)*.004-poll*.002-crime*.0015,.35,1);let occ=utilities&&access&&!t.abandoned&&!t.fire?Math.round(c*quality):Math.round(t.occupancy*.65);t.occupancy=occ;for(let j of p.members)if(j!==p.root)tiles[j].occupancy=0;occupied.res+=occ;continue}if(t.abandoned)abandoned++;if(!t.zone||!t.level)continue;let c=CONFIG.buildingCapacity[t.zone][t.level];capacity[t.zone]+=c;developed[t.zone]++;let access=w.roadNear(i),utilities=f.power[i]&&f.water[i];let viable=access&&utilities&&!t.abandoned&&!t.fire;let quality=clamp(.88+(f.landValue[i]-50)*.004-f.pollution[i]*.002-f.crime[i]*.0015,.35,1);t.occupancy=viable?Math.round(c*quality):Math.round(t.occupancy*.65);occupied[t.zone]+=t.occupancy}
 let group=new Int16Array(COUNT).fill(-1),parts=[];for(let i=0;i<COUNT;i++)if(tiles[i].road&&group[i]<0){let id=parts.length,q=[i];parts.push({res:0,jobs:0});group[i]=id;for(let p=0;p<q.length;p++)for(let j of neighbors(q[p]))if(tiles[j].road&&group[j]<0){group[j]=id;q.push(j)}}for(let i=0;i<COUNT;i++){let t=tiles[i];if(!t.zone||!t.occupancy)continue;let roads=t.zone==='res'&&t.parcel?ParcelSystem.roads(w,ParcelSystem.info(w,i)):neighbors(i).filter(k=>tiles[k].road);let j=roads[0];if(j===undefined)continue;let id=group[j];if(id<0)continue;parts[id][t.zone==='res'?'res':'jobs']+=t.occupancy}
 let jobs=occupied.com+occupied.ind,population=occupied.res,employed=parts.reduce((n,p)=>n+Math.min(p.res,p.jobs),0),unemployment=population?Math.round(100*(population-employed)/population):0;Object.assign(s,{population,resCapacity:capacity.res,commercialCapacity:capacity.com,industrialCapacity:capacity.ind,jobs,commercialJobs:occupied.com,industrialJobs:occupied.ind,employed,unemployment,developed,abandoned,capacity,occupied})}
 static growthScore(w,i){let t=w.tiles[i],f=w.fields,demand=w.demand[t.zone],rate=w.taxes[t.zone],value,poll,crime,utility,service,traffic;if(t.zone==='res'&&t.parcel){let p=ParcelSystem.info(w,i);value=ParcelSystem.avg(w,p,'landValue');poll=ParcelSystem.avg(w,p,'pollution');crime=ParcelSystem.avg(w,p,'crime');utility=ParcelSystem.has(w,p,'power')&&ParcelSystem.has(w,p,'water');service=(ParcelSystem.avg(w,p,'school')+ParcelSystem.avg(w,p,'hospital'))*.5;traffic=ParcelSystem.avg(w,p,'trafficImpact')}else{value=f.landValue[i];poll=f.pollution[i];crime=f.crime[i];utility=f.power[i]&&f.water[i];service=(f.school[i]+f.hospital[i])*.5;traffic=f.trafficImpact[i]}let score=18+demand*.65+(value-48)*.53+service*11-poll*(t.zone==='res'?.30:t.zone==='ind'?.035:.1)-crime*.10-(rate-8)*3-traffic*.12;if(!utility)score-=100;if(t.zone==='com'&&w.stats.population<35)score-=28;if(t.zone==='ind'&&w.stats.population<10)score-=10;if(t.zone==='res'&&w.stats.jobs<10)score-=20;if(t.fire)score-=120;return score}
 static develop(w){let tiles=w.tiles,candidates=[],seen=new Set;for(let i=0;i<COUNT;i++){let t=tiles[i],target=i;if(t.zone==='res'&&t.parcel){let p=ParcelSystem.info(w,i);if(!p||seen.has(p.id))continue;seen.add(p.id);target=p.root;t=tiles[target]}if(!t.zone||!w.roadNear(target))continue;let score=this.growthScore(w,target)+hash(target,w.tick,w.seed)*16-8;candidates.push({i:target,score})}
 candidates.sort((a,b)=>b.score-a.score);let growLimit=clamp(Math.ceil(candidates.length*.05),2,14),grown=0;for(let {i,score} of candidates){let t=tiles[i],p=t.zone==='res'&&t.parcel?ParcelSystem.info(w,i):null,max=t.zone==='res'?(t.resType==='apt'?4:3):4,level=t.level,ab=t.abandoned,damage=t.damage;if(score>17&&grown<growLimit){if(ab&&score>20){ab=0;level=Math.max(1,level);damage=0;grown++}else if(!ab&&level<max&&score>(level?22+level*19:17)){level++;grown++}}else if(score< -38&&level){damage++;if(damage>=3){damage=0;if(level>1)level--;else ab=Math.min(8,ab+1)}}else if(score< -12&&level){damage++;if(damage>=5){damage=0;ab=Math.min(8,ab+1)}}else if(score>12){damage=Math.max(0,damage-1);if(ab&&score>20)ab=0}if(ab>=6&&level){level=0;ab=0}if(p){ParcelSystem.setLevel(w,p,level);ParcelSystem.setAbandoned(w,p,ab);for(let j of p.members)tiles[j].damage=damage}else{t.level=level;t.abandoned=ab;t.damage=damage;if(!level)t.occupancy=0}}
 }
}
'''
sub(r'class PopulationSimulation\{.*?\n\}\nclass DemandSimulation\{', population_class + 'class DemandSimulation{', 'population simulation', re.S)

utility_consumers = r'''  let resConsumers=new Set;for(let i=0;i<COUNT;i++){let t=tiles[i],p=t.zone==='res'&&t.parcel?ParcelSystem.info(w,i):null;if(p){if(resConsumers.has(p.id)||i!==p.root)continue;resConsumers.add(p.id)}let candidate=p?[...new Set(p.members.flatMap(m=>[groupAt[m],...neighbors(m).map(j=>groupAt[j])]))].filter(id=>id>=0):[groupAt[i],...neighbors(i).map(j=>groupAt[j])].filter(id=>id>=0);if(!candidate.length)continue;let id=candidate.reduce((a,b)=>groups[a].capacity>=groups[b].capacity?a:b),g=groups[id];if(!t.level&&!t.civic)continue;let n=t.level?(p?Math.max(2,Math.ceil(ParcelSystem.capacity(w,p,t.level)*.105)):Math.max(2,Math.ceil(CONFIG.buildingCapacity[t.zone][t.level]*.105))):(kind==='power'&&t.civic==='pump'?10:['hospital','police','fire','school','station'].includes(t.civic)?t.civic==='hospital'?15:9:0);if(n)g.consumers.push({i,n})}
'''
sub(r"  for\(let i=0;i<COUNT;i\+\+\)\{let t=tiles\[i\],candidate=\[groupAt\[i\],\.\.\.neighbors\(i\)\.map\(j=>groupAt\[j\]\)\]\.filter\(id=>id>=0\);.*?\n  let production=0;", utility_consumers + '  let production=0;', 'utility parcel consumers', re.S)
replace("let unpowered=0,unwatered=0;w.tiles.forEach((t,i)=>{if(t.level){if(!p.covered[i])unpowered++;if(!a.covered[i])unwatered++}});",
        "let unpowered=0,unwatered=0,seen=new Set;w.tiles.forEach((t,i)=>{if(!t.level)return;if(t.zone==='res'&&t.parcel){let q=ParcelSystem.info(w,i);if(!q||seen.has(q.id)||i!==q.root)return;seen.add(q.id);if(!ParcelSystem.has(w,q,'power'))unpowered++;if(!ParcelSystem.has(w,q,'water'))unwatered++}else{if(!p.covered[i])unpowered++;if(!a.covered[i])unwatered++}});",
        'utility parcel shortage count')
replace(" static roadEntrances(w,i){return neighbors(i).filter(j=>w.tiles[j].road)}",
        " static roadEntrances(w,i){let t=w.tiles[i];return t.zone==='res'&&t.parcel?ParcelSystem.roads(w,ParcelSystem.info(w,i)):neighbors(i).filter(j=>w.tiles[j].road)}",
        'traffic parcel entrances')
replace(" if(t.level)this.drawBuilding(t,px,py,S);",
        " if(t.level){if(t.zone==='res'&&t.parcel){let p=ParcelSystem.info(w,i);if(p&&i===p.anchor)this.drawResidentialParcel(w,p,S)}else this.drawBuilding(t,px,py,S)}",
        'parcel renderer call')

residential_renderer = r''' drawResidentialParcel(w,p,S){let c=this.ctx,t=w.tiles[p.root],x=this.cx+p.minX*S,y=this.cy+p.minY*S,W=p.width*S,H=p.height*S,area=p.area,apt=t.resType==='apt',v=Math.floor(hash(p.id,w.seed,31)*5),ab=!!t.abandoned;let walls=['#d9c7a5','#c9d6cf','#d6b397','#c6c0b3','#d8d0bd'],roofs=['#71483f','#4b5862','#7b583d','#526047','#66516c'],wall=ab?'#737774':walls[v],roof=ab?'#4c5050':roofs[v];c.save();c.fillStyle=ab?'#667066':'#789a61';c.fillRect(x+2,y+2,W-4,H-4);c.strokeStyle=ab?'#555':'#9db479';c.lineWidth=1;c.strokeRect(x+2.5,y+2.5,W-5,H-5);let seed=hash(p.id,w.seed,77),m=Math.max(2,S*.11);for(let q of p.members){let [tx,ty]=xy(q),px=this.cx+tx*S,py=this.cy+ty*S;if(hash(q,p.id,w.seed)>.66){c.fillStyle=ab?'#5c625a':'#2f6a43';c.beginPath();c.arc(px+S*(.18+hash(q,3,w.seed)*.62),py+S*(.18+hash(q,7,w.seed)*.62),Math.max(1.5,S*.08),0,7);c.fill()}}
 if(!apt){let bx=x+W*(area===1?.18:.12),by=y+H*(area===1?.2:.14),bw=W*(area===1?.64:area===2?.67:.72),bh=H*(area===1?.56:area===2?.64:.68),z=Math.max(2,Math.min(S*.28,S*(.12+.055*t.level)));if(area>=2){let gx=x+W*.68,gy=y+H*.46,gw=Math.max(S*.22,W*.22),gh=Math.max(S*.25,H*.31);c.fillStyle='#77756e';c.fillRect(gx+gw*.15,gy+gh*.55,Math.max(2,W-gx+x-gw*.15),Math.max(2,H-(gy-y)-gh*.55));c.fillStyle=wall;c.fillRect(gx,gy-z,gw,gh+z);c.fillStyle=roof;c.fillRect(gx-m,gy-z-m,gw+2*m,gh*.48)}if(area>=4&&v%2===0){c.fillStyle='#76a9b7';c.fillRect(x+W*.12,y+H*.68,W*.26,H*.16);c.strokeStyle='#d4e4dc';c.strokeRect(x+W*.12,y+H*.68,W*.26,H*.16)}c.fillStyle='#2b3a35aa';c.fillRect(bx+z*.7,by+z*.7,bw,bh);c.fillStyle=wall;c.fillRect(bx,by-z,bw,bh+z);c.fillStyle=roof;c.fillRect(bx-m,by-z-m,bw+2*m,bh*.56+m);c.strokeStyle=ab?'#343a3a':'#d6b987';c.lineWidth=Math.max(1,S*.045);c.beginPath();if(v%2){c.moveTo(bx,by-z+bh*.28);c.lineTo(bx+bw,by-z+bh*.28)}else{c.moveTo(bx+bw*.5,by-z-m);c.lineTo(bx+bw*.5,by-z+bh*.56)}c.stroke();c.fillStyle=ab?'#323a3c':'#e8d89d';let win=Math.max(1.5,S*.07);for(let k=1;k<=Math.min(4,1+area);k++)c.fillRect(bx+bw*k/(Math.min(4,1+area)+1)-win*.5,by+bh*.72,win,Math.max(1.5,S*.08));c.fillStyle='#5b493c';c.fillRect(bx+bw*.46,by+bh*.76,Math.max(2,S*.1),Math.max(2,S*.16));if(v===0||v===3){c.fillStyle='#665247';c.fillRect(bx+bw*.18,by-z-m*1.6,Math.max(2,S*.09),Math.max(3,S*.2))}}
 else{let tower=area>=4&&t.level>=3,court=area>=4&&!tower,bx=x+W*.11,by=y+H*.11,bw=W*.78,bh=H*.76,z=Math.max(3,S*(.18+t.level*.11));if(court){let gapW=bw*.42,gapH=bh*.45;c.fillStyle=wall;c.fillRect(bx,by-z,bw,bh+z);c.fillStyle='#789a61';c.fillRect(bx+(bw-gapW)/2,by+bh-gapH,gapW,gapH);c.fillStyle=roof;c.fillRect(bx-m,by-z-m,bw+2*m,bh*.23);c.fillRect(bx-m,by-z,bw*.24,bh*.7);c.fillRect(bx+bw*.76,by-z,bw*.24+m,bh*.7);c.fillStyle='#d6cfad';c.beginPath();c.arc(bx+bw*.5,by+bh*.72,Math.max(2,S*.1),0,7);c.fill()}else{if(tower){bx=x+W*.23;by=y+H*.19;bw=W*.54;bh=H*.58;z=Math.max(z,S*.75)}c.fillStyle='#2a3438aa';c.fillRect(bx+z*.45,by+z*.45,bw,bh);c.fillStyle=wall;c.fillRect(bx,by-z,bw,bh+z);c.fillStyle=roof;c.fillRect(bx-m,by-z-m,bw+2*m,bh*.2+m);c.fillStyle=ab?'#30383b':'#bcd5d2';let cols=Math.max(2,Math.min(6,Math.round(bw/Math.max(6,S*.3)))),rows=Math.max(2,Math.min(5,t.level+1));for(let r=0;r<rows;r++)for(let k=0;k<cols;k++)c.fillRect(bx+(k+.35)*bw/cols,by+(r+.55)*bh/rows,Math.max(1.5,S*.06),Math.max(1.5,S*.07));c.fillStyle='#5b6665';for(let k=0;k<Math.min(3,area);k++)c.fillRect(bx+bw*(.18+k*.25),by-z-m*.6,Math.max(2,S*.09),Math.max(2,S*.07))}}
 c.restore()}
 drawBuilding(t,x,y,S){let c=this.ctx,L=t.level,z=t.zone,base=z==='com'?'#70a4c2':'#af8d6a',roof=z==='com'?'#376889':'#615d59';if(t.abandoned){base='#696f6b';roof='#464b4c'}let margin=S*(.18-L*.025),h=S*(.25+L*.11);c.fillStyle='#293c37a0';c.fillRect(x+margin+S*.09,y+margin+S*.1,S-2*margin,h+S*.1);c.fillStyle=base;c.fillRect(x+margin,y+S*.78-h,S-2*margin,h);c.fillStyle=roof;c.fillRect(x+margin-S*.035,y+S*.75-h,S-2*margin+S*.07,S*.14);let rows=Math.min(L+1,4),cols=Math.max(2,L+1);c.fillStyle=t.abandoned?'#28353b':'#d9e7bb';for(let row=0;row<rows;row++)for(let col=0;col<cols;col++)if(!t.abandoned||((row+col)%3===0))c.fillRect(x+margin+(col+.35)*(S-2*margin)/cols,y+S*.8-h+(row+.55)*(h-S*.12)/rows,Math.max(1,S*.045),Math.max(1,S*.05));if(!t.abandoned&&z==='ind'){c.fillStyle='#5d5147';c.fillRect(x+S*.68,y+S*.47-h,S*.11,S*.3);c.fillStyle='#ded2b1';c.fillRect(x+S*.68,y+S*.46-h,S*.11,S*.045)}if(!t.abandoned&&z==='com'&&L>=3){c.strokeStyle='#d4e0d5';c.lineWidth=Math.max(1,S*.05);c.beginPath();c.moveTo(x+S*.52,y+S*.75-h);c.lineTo(x+S*.52,y+S*.58-h);c.stroke()}if(t.abandoned){c.strokeStyle='#a17265';c.lineWidth=2;c.beginPath();c.moveTo(x+margin,y+S*.74-h);c.lineTo(x+S-margin,y+S*.8);c.stroke()}}
 drawAgents'''
sub(r" drawBuilding\(t,x,y,S\)\{.*?\n drawAgents", residential_renderer, 'residential renderer', re.S)
replace("constructor(canvas){this.canvas=canvas;this.tool='pan';this.mode='paint';this.active=new Map;",
        "constructor(canvas){this.canvas=canvas;this.tool='pan';this.mode='tapPan';this.parcelId=0;this.active=new Map;",
        'default input mode')
replace("this.anchor=Renderer.toTile(p.x,p.y);this.painted=new Set;if(this.tool!=='pan'&&e.button!==2)EditHistory.begin();",
        "this.anchor=Renderer.toTile(p.x,p.y);this.painted=new Set;this.parcelId=['res','apt'].includes(this.tool)?world.nextParcelId++:0;if(this.tool!=='pan'&&e.button!==2)EditHistory.begin();",
        'parcel id per stroke')
replace("paint(i){if(i<0||this.painted.has(i))return;this.painted.add(i);if(world.place(i,this.tool)){Renderer.dirty=true;UI.refresh()}}",
        "paint(i){if(i<0||this.painted.has(i))return;this.painted.add(i);if(world.place(i,this.tool,false,this.parcelId)){Renderer.dirty=true;UI.refresh()}}",
        'parcel-aware painting')
replace("UI.afterPlacement()}Renderer.hover=-1;Renderer.dirty=true}",
        "UI.afterPlacement();this.parcelId=0}Renderer.hover=-1;Renderer.dirty=true}",
        'clear parcel stroke')
replace("res:'Zones need an adjacent road, power, water, and demand. Jobs help residential growth. Development takes months.',com:",
        "res:'Each paint stroke is one house lot. Tap makes 1×1; switch to Paint drag for larger lots. Lot size changes the house that can develop.',apt:'Apartment lots use the same parcel system. Larger lots can support courtyard buildings and eventually towers.',com:",
        'tool help')
sub(r"else if\(\['res','com','ind'\]\.includes\(k\)\)\{let n=\{road:0,power:0,water:0,ready:0\};world\.tiles\.forEach\(\(t,i\)=>\{if\(t\.zone!==k\|\|t\.level\)return;.*?Empty zones do not relay utilities; buildings do\.\`\}\}",
    "else if(['res','apt','com','ind'].includes(k)){let zone=k==='apt'?'res':k,n={road:0,power:0,water:0,ready:0,parcels:new Set};world.tiles.forEach((t,i)=>{if(t.zone!==zone||t.level||(zone==='res'&&((k==='apt')!==(t.resType==='apt'))))return;let p=t.parcel?ParcelSystem.info(world,i):null,key=p?p.id:i;if(n.parcels.has(key))return;n.parcels.add(key);let road=world.roadNear(i),power=p?ParcelSystem.has(world,p,'power'):!!world.fields.power[i],water=p?ParcelSystem.has(world,p,'water'):!!world.fields.water[i];if(!road)n.road++;if(!power)n.power++;if(!water)n.water++;if(road&&power&&water)n.ready++});this.$('status').textContent=`Empty ${k==='apt'?'apartment':zone.toUpperCase()} parcels: ${n.ready} network-ready · ${n.road} need road · ${n.power} need power · ${n.water} need water.`}",
    'after placement parcel status', re.S)
sub(r" refreshSelection\(\)\{let i=world\.selected;if\(i<0\)\{this\.\$\('details'\)\.innerHTML='';return;\}let t=world\.tiles\[i\],f=world\.fields,kind=t\.civic\|\|t\.zone\|\|t\.terrain,extra=.*?\n refreshGrowthHint\(\)",
    r''' refreshSelection(){let i=world.selected;if(i<0){this.$('details').innerHTML='';return;}let t=world.tiles[i],f=world.fields,p=t.zone==='res'&&t.parcel?ParcelSystem.info(world,i):null,kind=t.civic||(p?(t.resType==='apt'?'apartment residential':'house residential'):t.zone)||t.terrain,extra=t.civic==='tower'?`<br>Stored water: ${Math.round(t.storage||0)}/${CONFIG.waterTowerCapacity}`:t.civic==='pump'?`<br>Pump output: ${f.power[i]?(neighbors(i).some(j=>world.tiles[j].terrain==='water')?CONFIG.waterPumpCapacity:Math.round(CONFIG.waterPumpCapacity*.55)):0} (needs electricity)`:p?`<br>Parcel: ${p.width}×${p.height} · ${p.area} tile${p.area===1?'':'s'} · ${t.resType==='apt'?'apartments':'house lot'}<br>Property capacity: ${ParcelSystem.capacity(world,p,world.tiles[p.root].level)||0}`:'';let occ=p?world.tiles[p.root].occupancy:t.occupancy,power=p?ParcelSystem.has(world,p,'power'):!!f.power[i],water=p?ParcelSystem.has(world,p,'water'):!!f.water[i];this.$('details').innerHTML=`Tile ${i%N+1}, ${(i/N|0)+1} · ${kind}${t.level?' level '+t.level:''}${t.abandoned?' · ABANDONED':''}<br>Occupants: ${occ} · road: ${t.road?'yes':p&&ParcelSystem.roadNear(world,i)?'parcel access':'no'} · rail: ${t.rail?'yes':'no'}<br>Power: ${power?'yes':'no'} · water: ${water?'yes':'no'}${extra}<br>Land value: ${Math.round(p?ParcelSystem.avg(world,p,'landValue'):f.landValue[i])} · pollution: ${Math.round(p?ParcelSystem.avg(world,p,'pollution'):f.pollution[i])} · crime: ${Math.round(p?ParcelSystem.avg(world,p,'crime'):f.crime[i])}<br>Police ${Math.round(f.police[i]*100)}% · fire ${Math.round(f.fire[i]*100)}% · road condition ${Math.round(t.condition*100)}%`}
 refreshGrowthHint()''',
    'parcel selection details', re.S)
replace('<p>5. Paint industrial and residential zones, then commercial zones. In MetroForge, empty zones need a road, power, water, and enough demand before construction can begin. Residential growth benefits from jobs; industry supplies early jobs; commerce needs residents. Development takes months. Add services and parks as the city grows.</p>',
        '<p>5. Residential zoning is parcel-based. A single tap creates a 1×1 house lot. In Paint drag mode, every connected residential stroke is one property: longer/wider parcels support larger homes, garages, estates, or—using Apartment lots—larger apartment buildings. The simulation chooses a varied building that fits the property. Parcels need road access, power, water, and demand.</p>',
        'guide parcel explanation')
replace('<p>6. Mode: Paint drag builds across tiles. Mode: Tap + pan places one tile on a tap and moves the map on a drag, even with a build tool selected. Tap a tile with Pan selected for its exact conditions. Use overlays to diagnose crime, pollution, traffic, coverage, road wear, and utility gaps. Adjust taxes and funding in Budget.</p>',
        '<p>6. Tap + pan is the default: tap places one tile and drag pans. Switch to Paint drag when you want to draw a multi-tile parcel or long infrastructure stroke. With House lots or Apartment lots, one continuous Paint-drag stroke becomes one property. Tap a tile with Pan selected to inspect its parcel and conditions.</p>',
        'guide interaction mode')

if text == original:
    raise SystemExit('Patch made no changes')
path.write_text(text)
print('Applied parcel-based residential development upgrade.')
