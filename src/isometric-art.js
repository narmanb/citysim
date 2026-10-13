(function (root) {
  'use strict';
  const { project, visible } = root.MetroForgeIsoCore;
  class IsometricArt {
    constructor(view, invalidate = () => {}) {
      this.view = view; this.manifest = root.MetroForgeAssets; this.images = {}; this.errors = []; this.ready = false;
      this.loaded = Promise.all(Object.entries(this.manifest.atlases).map(([name, atlas]) => new Promise(resolve => {
        const image = new Image(); this.images[name] = image;
        image.onload = () => { invalidate(); resolve(); };
        image.onerror = () => { this.errors.push(atlas.file); invalidate(); resolve(); };
        image.src = atlas.file;
      }))).then(() => { this.ready = true; invalidate(); });
    }
    point(x, y, elevation = 0) {
      const v = this.view, p = project(x, y, v.scale, v.cx, v.cy);
      p.y -= elevation * v.scale * .15; return p;
    }
    polygon(points, fill, stroke, width = 1) {
      const c = this.view.ctx; c.beginPath(); points.forEach((p, i) => i ? c.lineTo(p.x, p.y) : c.moveTo(p.x, p.y));
      c.closePath(); if (fill) { c.fillStyle = fill; c.fill(); }
      if (stroke) { c.strokeStyle = stroke; c.lineWidth = width; c.stroke(); }
    }
    rectPath(x, y, elevation = 0, left = 0, top = 0, width = 1, height = 1) {
      const c = this.view.ctx, points = [[left,top],[left+width,top],[left+width,top+height],[left,top+height]];
      points.forEach(([dx,dy], i) => { const p=this.point(x+dx,y+dy,elevation); i ? c.lineTo(p.x,p.y) : c.moveTo(p.x,p.y); }); c.closePath();
    }
    diamond(x, y, elevation, fill, stroke, lineWidth = 1) {
      this.polygon([[x,y],[x+1,y],[x+1,y+1],[x,y+1]].map(([a,b])=>this.point(a,b,elevation)),fill,stroke,lineWidth);
    }
    spriteBounds(name, point, size = 1, lift = 0) {
      const sprite = this.manifest.sprites[name], factor = this.view.scale / 66 * size;
      return { x: point.x - sprite.anchor.x * factor, y: point.y - (sprite.anchor.y + lift) * factor,
        width: sprite.width * factor, height: sprite.height * factor };
    }
    sprite(name, point, size = 1, lift = 0) {
      const s = this.manifest.sprites[name], image = this.images[s.atlas], rect = this.spriteBounds(name, point, size, lift);
      if (!visible(rect,this.view.w,this.view.h)) return true;
      if (!image.complete || !image.naturalWidth) return false;
      this.view.ctx.drawImage(image,s.x,s.y,s.width,s.height,rect.x,rect.y,rect.width,rect.height); return true;
    }
    terrain(name, x, y, elevation = 0, surfaceOnly = false) {
      const c=this.view.ctx;
      if(surfaceOnly) {
        c.save();c.beginPath();this.rectPath(x,y,elevation);c.clip();
      }
      // Source PNGs include partially transparent interior pixels as well as
      // edge antialiasing. An opaque surface prevents objects leaking through.
      this.diamond(x,y,elevation,({water:'#79b9d1',sand:'#d7bd7a',dirt:'#9f8156',grass:'#91b955'})[name]);
      this.sprite(name,this.point(x+.5,y+.5,elevation));
      if(surfaceOnly)c.restore();
    }
    road(x, y, elevation, mask, condition = 1, bridge = false) {
      const c=this.view.ctx, p=this.point(x+.5,y+.5,elevation);
      // Only the ground texture is used; tall PNG side walls cannot change pitch.
      c.save(); c.beginPath(); this.rectPath(x,y,elevation); c.clip();
      if(!this.sprite('pavement',p)) this.diamond(x,y,elevation,'#d8d2b8');
      c.beginPath(); this.rectPath(x,y,elevation,.23,.23,.54,.54);
      if(mask&1) this.rectPath(x,y,elevation,.23,0,.54,.5);
      if(mask&2) this.rectPath(x,y,elevation,.5,.23,.5,.54);
      if(mask&4) this.rectPath(x,y,elevation,.23,.5,.54,.5);
      if(mask&8) this.rectPath(x,y,elevation,0,.23,.5,.54);
      c.clip(); if(!this.sprite('asphalt',p)) this.diamond(x,y,elevation,'#68696d');
      if(condition<.5) this.diamond(x,y,elevation,'#382f2680'); c.restore();
      if(bridge) {
        const edges=root.MetroForgeIsoCore.bridgeEdges(mask);
        c.strokeStyle='#dfc99b';c.lineWidth=Math.max(1,this.view.scale*.05);
        for(const [ax,ay,bx,by] of edges) {const a=this.point(x+ax,y+ay,elevation),b=this.point(x+bx,y+by,elevation);c.beginPath();c.moveTo(a.x,a.y-3);c.lineTo(b.x,b.y-3);c.stroke();}
      }
    }
    box(x, y, elevation, width, depth, height, colors) {
      const points=[[x,y],[x+width,y],[x+width,y+depth],[x,y+depth]].map(([a,b])=>this.point(a,b,elevation));
      const roof=points.map(p=>({x:p.x,y:p.y-height}));
      this.polygon([roof[1],roof[2],points[2],points[1]],colors[1]);
      this.polygon([roof[2],roof[3],points[3],points[2]],colors[2]); this.polygon(roof,colors[0]);
      return roof;
    }
    building(x, y, elevation, type = 'house', level = 1, size = 1, abandoned = false, variant = 0) {
      const c=this.view.ctx, p=this.point(x,y,elevation), floors=type==='house'?Math.min(3,Math.max(1,level)):type==='shop'?Math.min(3,Math.max(1,level)):Math.min(5,level+1);
      const sprite=type==='house'?(variant%2?'house':'houseBeige'):type==='shop'||type==='office'?'office':'house';
      const step=this.manifest.sprites[sprite].height-this.manifest.sprites[sprite].width/2;
      c.save(); if(abandoned) { c.globalAlpha=.65; c.filter='grayscale(1)'; }
      for(let floor=0;floor<floors;floor++) {
        if(!this.sprite(sprite,p,size,floor*step)) this.box(x-.34*size,y-.34*size,elevation,.68*size,.68*size,this.view.scale*(floor+1)*.5,['#d9ceaf','#a49476','#b9ad91']);
      }
      this.sprite(type==='house'?'roof':'flatRoof',p,size,floors*step);
      c.restore();
      if(abandoned && this.view.scale>12) {c.fillStyle='#f5ba90';c.font='bold 11px sans-serif';c.textAlign='center';c.fillText('×',p.x,p.y-floors*step*this.view.scale/66*size-8);}
    }
    tree(x,y,elevation=0) {
      const p=this.point(x,y,elevation);
      if(!this.sprite('tree',p,2)) this.box(x-.13,y-.13,elevation,.26,.26,this.view.scale*.8,['#8eb544','#4d7a31','#689e39']);
    }
  }
  root.MetroForgeIsoArt=IsometricArt;
})(globalThis);
