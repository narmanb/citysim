(function (root) {
  'use strict';
  const Core = root.MetroForgeIsoCore;
  function createRenderer(deps) {
    const { CityRenderer, N, neighbors, ParcelSystem, getWorld, getInput, hash, ZCOL } = deps;
    return class IsometricRenderer extends CityRenderer {
      constructor(canvas) {
        super(canvas); this.projection = 'isometric'; this.objects = []; this.groundTiles = [];
        this.art = new root.MetroForgeIsoArt(this, () => { this.dirty = true; });
        this.art.loaded.then(() => {
          if(this.art.errors.length && deps.onAssetError)deps.onAssetError('Some artwork could not load. Basic shapes are shown; reload the complete game folder.');
        });
        this.ground = document.createElement('canvas'); this.groundContext = this.ground.getContext('2d');
        this.metrics = { visibleTiles: 0, staticObjects: 0, groundRedraws: 0 };
      }
      fit() {
        this.scale = 28;
        this.cx = this.canvas.parentElement.clientWidth / 2;
        this.cy = this.canvas.parentElement.clientHeight / 2 - N * this.scale / 2;
        this.dirty = true;
      }
      toTile(x, y) { const w = getWorld(); return w ? Core.pickTile(x,y,this,w.tiles,N) : -1; }
      zoom(factor, x = this.w/2, y = this.h/2) { Core.zoomCamera(this,factor,x,y); this.dirty = true; }
      surfaceLine(points, color, width) {
        const c = this.ctx; c.strokeStyle = color; c.lineWidth = width; c.beginPath();
        points.forEach((p,i)=>i?c.lineTo(p.x,p.y):c.moveTo(p.x,p.y)); c.stroke();
      }
      drawConnections(w, i, kind, color, width, shift = 0) {
        const x=i%N,y=Math.floor(i/N),t=w.tiles[i],a=this.art.point(x+.5,y+.5,t.elev);
        const end=[];
        for(const j of neighbors(i)) {
          const u=w.tiles[j], compatible=kind==='pipe'&&(u.civic==='pump'||u.civic==='tower');
          if(!u[kind]&&!compatible)continue;
          const b=this.art.point(x+.5+(j%N-x)*.5,y+.5+(Math.floor(j/N)-y)*.5,t.elev);
          end.push(b);this.surfaceLine([{x:a.x,y:a.y+shift},{x:b.x,y:b.y+shift}],color,width);
        }
        if(!end.length)this.surfaceLine([{x:a.x-this.scale*.1,y:a.y+shift},{x:a.x+this.scale*.1,y:a.y+shift}],color,width);
      }
      drawRailIso(w,i) {
        const x=i%N,y=Math.floor(i/N),t=w.tiles[i],mask=Core.roadMask(w.tiles,i,N,'rail'),S=this.scale;
        this.drawConnections(w,i,'rail','#695039',Math.max(3,S*.22));
        this.drawConnections(w,i,'rail','#dbc699',Math.max(1,S*.09));
        for(const [bit,dx,dy] of [[1,0,-1],[2,1,0],[4,0,1],[8,-1,0]])if(mask&bit)for(const d of [.12,.32,.48]) {
          const px=x+.5+dx*d,py=y+.5+dy*d,ax=this.art.point(px-dy*.09,py+dx*.09,t.elev),bx=this.art.point(px+dy*.09,py-dx*.09,t.elev);
          this.surfaceLine([ax,bx],'#66503c',Math.max(1,S*.065));
        }
      }
      shore(w,i) {
        const t=w.tiles[i],x=i%N,y=Math.floor(i/N);if(t.terrain==='water')return;
        const c=this.ctx;c.save();c.beginPath();
        for(const j of neighbors(i))if(w.tiles[j].terrain==='water') {
          if(j===i-N)this.art.rectPath(x,y,t.elev,0,0,1,.1);
          if(j===i+N)this.art.rectPath(x,y,t.elev,0,.9,1,.1);
          if(j===i-1)this.art.rectPath(x,y,t.elev,0,0,.1,1);
          if(j===i+1)this.art.rectPath(x,y,t.elev,.9,0,.1,1);
        }
        c.fillStyle='#dcc78d';c.fill();c.restore();
      }
      cliff(w,i) {
        const x=i%N,y=Math.floor(i/N),e=w.tiles[i].elev||0;
        for(const [dx,dy,color] of [[1,0,'#8b7954'],[0,1,'#a18b62']]) {
          const j=(y+dy)*N+x+dx,lower=x+dx<N&&y+dy<N?(w.tiles[j].elev||0):0;
          if(e<=lower)continue;
          const ends=dx?[[x+1,y],[x+1,y+1]]:[[x,y+1],[x+1,y+1]];
          this.art.polygon([this.art.point(...ends[0],e),this.art.point(...ends[1],e),this.art.point(...ends[1],lower),this.art.point(...ends[0],lower)],color);
        }
      }
      parcelTile(w,i) {
        const t=w.tiles[i],x=i%N,y=Math.floor(i/N),c=this.ctx,base=ZCOL[t.zone];
        this.art.diamond(x,y,t.elev,base+(t.level?'22':'66'));
        if(!t.parcel){this.art.diamond(x,y,t.elev,null,base,1);return;}
        const same=(xx,yy)=>xx>=0&&yy>=0&&xx<N&&yy<N&&w.tiles[yy*N+xx].parcel===t.parcel;
        for(const [dx,dy,ax,ay,bx,by]of [[0,-1,0,0,1,0],[1,0,1,0,1,1],[0,1,1,1,0,1],[-1,0,0,1,0,0]])
          if(!same(x+dx,y+dy))this.surfaceLine([this.art.point(x+ax,y+ay,t.elev),this.art.point(x+bx,y+by,t.elev)],base,Math.max(1,this.scale*.045));
      }
      drawGroundTile(w,i) {
        const t=w.tiles[i],x=i%N,y=Math.floor(i/N);
        const name=t.terrain==='water'?'water':t.channel?'dirt':t.biome==='desert'?'sand':'grass';
        this.cliff(w,i);this.art.terrain(name,x,y,t.elev);this.shore(w,i);
        if(t.zone)this.parcelTile(w,i);
        if(t.road)this.art.road(x,y,t.elev,Core.roadMask(w.tiles,i,N),t.condition,t.terrain==='water');
        if(t.rail)this.drawRailIso(w,i);
        if(t.pipe)this.drawConnections(w,i,'pipe',w.fields.water?.[i]?'#6fe0ec':'#cf799a',Math.max(1.2,this.scale*.07),this.scale*.15);
        if(t.channel&&t.terrain!=='water')this.surfaceLine([this.art.point(x+.2,y+.5,t.elev),this.art.point(x+.8,y+.5,t.elev)],'#796345',this.scale*.12);
      }
      buildGround(w) {
        if(this.ground.width!==this.canvas.width||this.ground.height!==this.canvas.height){this.ground.width=this.canvas.width;this.ground.height=this.canvas.height;}
        const original=this.ctx;this.ctx=this.groundContext;
        const dpr=this.canvas.width/Math.max(1,this.w);this.ctx.setTransform(dpr,0,0,dpr,0,0);
        this.ctx.clearRect(0,0,this.w,this.h);this.ctx.fillStyle='#193848';this.ctx.fillRect(0,0,this.w,this.h);
        this.groundTiles=[];this.objects=[];this.groundRecords=[];
        // Ground order uses logical diagonal depth; complete art bounds are culled.
        for(let sum=0;sum<2*N-1;sum++)for(let x=Math.max(0,sum-N+1);x<=Math.min(N-1,sum);x++) {
          const y=sum-x,i=y*N+x,t=w.tiles[i],p=this.art.point(x+.5,y+.5,t.elev);
          const name=t.terrain==='water'?'water':t.channel?'dirt':t.biome==='desert'?'sand':'grass';
          const cap=this.art.spriteBounds(name,p);
          const east=x<N-1?(w.tiles[i+1].elev||0):0,south=y<N-1?(w.tiles[i+N].elev||0):0;
          const bounds=Core.includePoints(cap,[this.art.point(x+1,y+1,Math.min(t.elev||0,east,south))]);
          const onscreen=Core.visible(bounds,this.w,this.h);
          if(onscreen) {
            this.groundTiles.push(i);this.drawGroundTile(w,i);
            this.groundRecords.push({depth:sum+1,bounds,terrain:true,draw:()=>this.drawGroundTile(w,i)});
          }
          const add=(depth,draw,bounds)=>this.objects.push({depth,draw,bounds});
          if(t.tree&&t.terrain!=='water'&&!t.road&&!t.rail&&!t.civic&&!t.level&&Core.visible(this.art.spriteBounds('tree',p,2),this.w,this.h))
            add(sum+1.1,()=>this.art.tree(x+.5,y+.5,t.elev),this.art.spriteBounds('tree',p,2));
          if(t.line && Core.visible({x:p.x-this.scale*2,y:p.y-this.scale,width:this.scale*4,height:this.scale*2},this.w,this.h))
            add(sum+1.2,()=>this.drawPole(w,i),{x:p.x-this.scale*2,y:p.y-this.scale,width:this.scale*4,height:this.scale*2});
          if(t.civic && Core.visible({x:p.x-this.scale,y:p.y-this.scale*2,width:this.scale*2,height:this.scale*3},this.w,this.h))
            add(sum+1.6,()=>this.drawCivicIso(t,x,y),{x:p.x-this.scale,y:p.y-this.scale*2,width:this.scale*2,height:this.scale*3});
          if(t.level) {
            const parcel=t.parcel?ParcelSystem.info(w,i):null;
            if(parcel && i!==parcel.root)continue;
            const root=parcel?w.tiles[parcel.root]:t,fp=parcel?Core.parcelFootprint(parcel.members,N):{x,y,width:1,height:1};
            const bx=fp.x+fp.width/2,by=fp.y+fp.height/2,size=Math.min(fp.width,fp.height),point=this.art.point(bx,by,root.elev);
            const overhang={x:point.x-this.scale*size,y:point.y-this.scale*size*4,width:this.scale*size*2,height:this.scale*size*5};
            if(Core.visible(overhang,this.w,this.h))add(fp.x+fp.y+fp.width+fp.height-.1,()=>this.drawDevelopment(root,bx,by,size),overhang);
          }
        }
        this.staticOccluders=this.groundRecords.filter(ground=>this.objects.some(object=>object.depth<ground.depth&&Core.overlaps(ground.bounds,object.bounds)));
        this.staticOccluderSet=new Set(this.staticOccluders);
        this.ctx=original;this.metrics.visibleTiles=this.groundTiles.length;this.metrics.staticObjects=this.objects.length;this.metrics.groundRedraws++;
      }
      drawPole(w,i) {
        const x=i%N,y=Math.floor(i/N),t=w.tiles[i],p=this.art.point(x+.5,y+.5,t.elev),top={x:p.x,y:p.y-this.scale*.65};
        this.surfaceLine([p,top],'#614d39',Math.max(1.5,this.scale*.07));
        this.surfaceLine([{x:top.x-this.scale*.16,y:top.y},{x:top.x+this.scale*.16,y:top.y}],'#d5b97b',Math.max(1,this.scale*.05));
        for(const j of neighbors(i))if(w.tiles[j].line||w.tiles[j].civic==='plant') {
          const q=this.art.point(j%N+.5,Math.floor(j/N)+.5,w.tiles[j].elev);
          this.surfaceLine([top,{x:(top.x+q.x)/2,y:(top.y+q.y-this.scale*.65)/2+this.scale*.07},{x:q.x,y:q.y-this.scale*.65}],'#b9af8b',Math.max(.7,this.scale*.025));
        }
      }
      drawCivicIso(t,x,y) {
        const S=this.scale,k=t.civic;
        if(k==='park'){this.art.tree(x+.35,y+.35,t.elev);this.art.tree(x+.7,y+.65,t.elev);return;}
        const color={plant:['#a4a6a0','#525c60','#737d80'],pump:['#84c7d6','#347484','#4994a3'],tower:['#b2dbe0','#417c8b','#70a8b5'],police:['#82acce','#385c89','#587d9f'],fire:['#d98764','#9a3d38','#bd5e4c'],school:['#e3cc86','#a2844c','#c1a66a'],hospital:['#f1e8db','#a69d96','#d6cfc1'],station:['#bcb1cd','#675d82','#91839f']}[k]||['#bbb','#777','#999'];
        const height=k==='tower'?S*1.2:k==='plant'?S*.55:S*.6;
        this.art.box(x+.16,y+.16,t.elev,.68,.68,height,color);
        if(k==='plant')for(const offset of [.25,.55])this.art.box(x+offset,y+.27,t.elev,.12,.12,S*1.0,['#cabfb0','#737572','#949891']);
        const p=this.art.point(x+.5,y+.5,t.elev);this.ctx.fillStyle='#fff5da';this.ctx.textAlign='center';this.ctx.font=`bold ${Math.max(8,Math.min(12,S*.36))}px sans-serif`;
        this.ctx.fillText(({plant:'PWR',pump:'W',tower:'T',police:'POL',fire:'F',school:'E',hospital:'+',station:'R'})[k]||'?',p.x,p.y-height+3);
      }
      drawDevelopment(t,x,y,size) {
        const type=t.zoneType||t.resType||(t.zone==='res'?'house':t.zone==='com'?'shop':'light');
        if(t.zone==='ind') {
          const S=this.scale*size,span=.7*size,height=S*((type==='heavy'?.4:.25)+Math.min(4,t.level)*.1),colors=t.abandoned?['#99968a','#69665b','#817e70']:['#c3b793','#6c716d','#999482'];
          this.art.box(x-span/2,y-span/2,t.elev,span,span,height,colors);
          if(type==='heavy')this.art.box(x+span*.25,y-span*.2,t.elev,span*.16,span*.16,S*1.4,['#a18464','#5d5350','#8b7268']);
          const p=this.art.point(x,y,t.elev);this.ctx.fillStyle='#342f29';this.ctx.font=`bold ${Math.max(8,Math.min(12,this.scale*.4))}px sans-serif`;this.ctx.textAlign='center';this.ctx.fillText(type==='logistics'?'LOG':type==='heavy'?'H':'IND',p.x,p.y-height+3);
        } else this.art.building(x,y,t.elev,type,t.level,size,!!t.abandoned,Math.floor(hash(t.parcel||Math.floor(x+y*N),37,11)*2));
      }
      agents(w) {
        const records=[],S=this.scale;
        for(const [kind,list] of [['car',w.cars||[]],['train',w.trains||[]]])for(const agent of list) {
          const a=agent.path[Math.floor(agent.p)],b=agent.path[Math.min(agent.path.length-1,Math.floor(agent.p)+1)];
          if(a===undefined||b===undefined)continue;
          const v=agent.p%1,ax=a%N,ay=Math.floor(a/N),dx=b%N-ax,dy=Math.floor(b/N)-ay;
          const x=ax+.5+dx*v+(kind==='car'?-dy*.10:0),y=ay+.5+dy*v+(kind==='car'?dx*.10:0),e=(w.tiles[a].elev||0)*(1-v)+(w.tiles[b].elev||0)*v,p=this.art.point(x,y,e);
          if(!Core.visible({x:p.x-S,y:p.y-S,width:2*S,height:2*S},this.w,this.h))continue;
          const direction=dx>0?'SE':dx<0?'NW':dy>0?'SW':'NE';
          records.push({depth:x+y+.1,bounds:{x:p.x-S,y:p.y-S,width:2*S,height:2*S},draw:()=>{
            if(kind==='car') {
              if(!this.art.sprite('car'+direction,p,.85))this.art.box(x-.09,y-.07,e,.18,.14,S*.12,['#f5d16a','#936934','#d5a247']);
            } else this.art.box(x-.17,y-.17,e,.34,.34,S*.26,['#e39a7e','#924b49','#c66b56']);
          }});
        }
        return records;
      }
      draw(w) {
        const c=this.ctx;
        if(this.dirty || this.cachedWorld!==w || this.cachedScale!==this.scale || this.cachedX!==this.cx || this.cachedY!==this.cy || this.cachedWidth!==this.canvas.width || this.cachedHeight!==this.canvas.height) {
          this.buildGround(w);this.cachedWorld=w;this.cachedScale=this.scale;this.cachedX=this.cx;this.cachedY=this.cy;this.cachedWidth=this.canvas.width;this.cachedHeight=this.canvas.height;
        }
        c.drawImage(this.ground,0,0,this.ground.width,this.ground.height,0,0,this.w,this.h);
        const agents=this.agents(w),objects=[...this.objects,...agents];
        // Repaint only ground that intersects an earlier object, at its proper
        // depth. This retains the base cache without drawing agents through hills.
        const occluders=[...this.staticOccluders,...this.groundRecords.filter(ground=>!this.staticOccluderSet.has(ground)&&agents.some(object=>object.depth<ground.depth&&Core.overlaps(ground.bounds,object.bounds)))];
        this.metrics.occludingGroundTiles=occluders.length;
        c.save();
        for(const item of [...objects,...occluders].sort((a,b)=>a.depth-b.depth)) {
          c.globalAlpha=(this.overlay!=='none'&&!item.terrain) ? .7 : 1;item.draw();
        }
        c.restore();
        for(const i of this.groundTiles) {
          const t=w.tiles[i],x=i%N,y=Math.floor(i/N),color=this.overlayColor(w,i);
          if(color)this.art.diamond(x,y,t.elev,color);
          if(t.fire){const p=this.art.point(x+.5,y+.5,t.elev);this.art.polygon([{x:p.x-this.scale*.16,y:p.y},{x:p.x,y:p.y-this.scale*.8},{x:p.x+this.scale*.18,y:p.y-this.scale*.1}], '#f69b3b','#e64525');}
          if(i===w.selected)this.art.diamond(x,y,t.elev,null,'#fff3ad',2);
          if(i===this.hover && getInput().tool!=='pan')this.art.diamond(x,y,t.elev,w.canPlace(i,getInput().tool)?'#eaf2a077':'#ee555577','#fff',1.5);
        }
        for(const event of w.events)if(event.type==='dispatch') {
          const t=w.tiles[event.i],p=this.art.point(event.i%N+.5,Math.floor(event.i/N)+.5,t.elev);
          c.strokeStyle='#80e5f4';c.lineWidth=2;c.beginPath();c.arc(p.x,p.y,this.scale*(.35+Math.sin(performance.now()*.008)*.05),0,Math.PI*2);c.stroke();
        }
        this.dirty=false;
      }
    };
  }
  root.MetroForgeIso={createRenderer};
})(globalThis);
