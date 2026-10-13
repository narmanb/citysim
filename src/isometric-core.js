(function (root) {
  'use strict';
  function project(x, y, scale, cx = 0, cy = 0) {
    return { x: cx + (x - y) * scale, y: cy + (x + y) * scale / 2 };
  }
  function unproject(x, y, scale, cx = 0, cy = 0) {
    return { x: (y - cy) / scale + (x - cx) / (2 * scale),
      y: (y - cy) / scale - (x - cx) / (2 * scale) };
  }
  // N/E/S/W in logical map coordinates; map edges never wrap.
  function roadMask(tiles, i, n, kind = 'road') {
    const x = i % n, y = Math.floor(i / n);
    return (y > 0 && tiles[i - n][kind] ? 1 : 0) |
      (x < n - 1 && tiles[i + 1][kind] ? 2 : 0) |
      (y < n - 1 && tiles[i + n][kind] ? 4 : 0) |
      (x > 0 && tiles[i - 1][kind] ? 8 : 0);
  }
  function parcelFootprint(members, n) {
    const set = new Set(members);
    let best = { x: members[0] % n, y: Math.floor(members[0] / n), width: 1, height: 1 };
    // A contained 1×1 or 2×2 main building leaves irregular portions as yard.
    for (const i of members) {
      const x = i % n, y = Math.floor(i / n);
      for (const width of [1, 2]) for (const height of [1, 2]) {
        if (x + width > n || y + height > n || width * height <= best.width * best.height) continue;
        let fits = true;
        for (let dy = 0; dy < height; dy++) for (let dx = 0; dx < width; dx++)
          if (!set.has((y + dy) * n + x + dx)) fits = false;
        if (fits) best = { x, y, width, height };
      }
    }
    return best;
  }
  function visible(rect, width, height) {
    return rect.x + rect.width >= 0 && rect.y + rect.height >= 0 && rect.x <= width && rect.y <= height;
  }
  function pickTile(px, py, camera, tiles, n) {
    let best = -1, depth = -Infinity;
    for (let elevation = -3; elevation <= 5; elevation++) {
      const p = unproject(px, py + elevation * camera.scale * .15, camera.scale, camera.cx, camera.cy);
      const x = Math.floor(p.x), y = Math.floor(p.y);
      if (x < 0 || y < 0 || x >= n || y >= n) continue;
      const i = y * n + x;
      if ((tiles[i].elev || 0) !== elevation) continue;
      if (x + y >= depth) { best = i; depth = x + y; }
    }
    return best;
  }
  function zoomCamera(camera, factor, x, y) {
    const next = Math.max(7, Math.min(100, camera.scale * factor)), ratio = next / camera.scale;
    camera.cx = x + (camera.cx - x) * ratio; camera.cy = y + (camera.cy - y) * ratio;
    camera.scale = next;
  }
  function bridgeEdges(mask) {
    return (mask & 5) ? [[.15,0,.15,1],[.85,0,.85,1]] : [[0,.15,1,.15],[0,.85,1,.85]];
  }
  function includePoints(rect, points) {
    const left=Math.min(rect.x,...points.map(p=>p.x)),top=Math.min(rect.y,...points.map(p=>p.y));
    const right=Math.max(rect.x+rect.width,...points.map(p=>p.x)),bottom=Math.max(rect.y+rect.height,...points.map(p=>p.y));
    return {x:left,y:top,width:right-left,height:bottom-top};
  }
  function overlaps(a,b) {
    return a.x<=b.x+b.width && a.x+a.width>=b.x && a.y<=b.y+b.height && a.y+a.height>=b.y;
  }
  const api = { project, unproject, roadMask, parcelFootprint, visible, pickTile, zoomCamera, bridgeEdges, includePoints, overlaps };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.MetroForgeIsoCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
