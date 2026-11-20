import {ARENA_SIZE, hasGround, PROPS, SKILLS, attackRange, previewTargets} from './combat.mjs';
import {ellipse, flame, gate, noise, paintIcon, pillar, pine, polygon, rect, sprite, stone} from './art.mjs';

export const WIDTH = 576;
export const HEIGHT = 340;
const X0 = WIDTH / 2;
const Y0 = 47;
const HALF_W = 14;
const HALF_H = 7;

export function toScreen(x, y) {
  return [X0 + (x - y) * HALF_W, Y0 + (x + y) * HALF_H];
}

export function toWorld(x, y) {
  return {x: ((x - X0) / HALF_W + (y - Y0) / HALF_H) * .5,
    y: ((y - Y0) / HALF_H - (x - X0) / HALF_W) * .5};
}

function corners(x, y) {
  return [toScreen(x, y), toScreen(x+1, y), toScreen(x+1, y+1), toScreen(x, y+1)];
}

function gradient(ctx, x, y, size, center, edge) {
  const paint = ctx.createRadialGradient(x, y, 0, x, y, size);
  paint.addColorStop(0, center);
  paint.addColorStop(1, edge);
  ctx.fillStyle = paint;
  ctx.fillRect(x - size, y - size, size * 2, size * 2);
}

function backdrop(ctx) {
  const dusk = ctx.createLinearGradient(0, 0, 0, HEIGHT);
  dusk.addColorStop(0, '#151d2a');
  dusk.addColorStop(.56, '#1c2b34');
  dusk.addColorStop(1, '#111921');
  ctx.fillStyle = dusk;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);
  gradient(ctx, 286, 64, 245, '#655c5445', '#25273500');
  gradient(ctx, 278, 235, 244, '#58726d27', '#24313600');

  for (let layer = 0; layer < 3; layer++) {
    const vertices = [[0, HEIGHT]];
    for (let x = 0; x <= WIDTH; x += 4) {
      const y = 108 + layer * 25 + Math.sin(x * .013 + layer * 2) * 20 +
        Math.sin(x * .039 + layer * 4) * 10 + noise(x, layer, 5) * 5;
      vertices.push([x, Math.round(y / 3) * 3]);
    }
    vertices.push([WIDTH, HEIGHT]);
    polygon(ctx, vertices, ['#29364088', '#24343c9b', '#1c2b35ae'][layer]);
  }

  for (let i = 0; i < 34; i++) {
    const x = Math.round(noise(i, 6, 13) * WIDTH);
    const y = 116 + Math.round(noise(i, 12, 12) * 101);
    ctx.globalAlpha = .33 + noise(i, 0, 9) * .19;
    pine(ctx, x, y, i, .38 + noise(i, 2, 9) * .5);
  }
  ctx.globalAlpha = 1;
  for (let i = 0; i < 58; i++) {
    const x = Math.round(noise(i, 6, 6) * WIDTH);
    const y = Math.round(noise(i, 5, 5) * HEIGHT);
    rect(ctx, i % 3 ? '#91a39c27' : '#b493762e', x, y, i % 4 === 0 ? 2 : 1, 1);
  }
  ellipse(ctx, 292, 234, 235, 86, '#141f2955');
  ellipse(ctx, 289, 237, 202, 73, '#10172050');
}

const STONE_TILES = ['#555e57', '#60665b', '#58625a', '#575f57', '#646a5f', '#515e55'];
const GRASS_TILES = ['#3b4e45', '#3b4a43', '#46574b', '#455148', '#3c5149', '#3b4844', '#4a554a'];

function stoneTile(x, y) {
  const distance = Math.hypot(x - 8, y - 8.5);
  return distance < 5.2 || (y >= 2 && y <= 12 && x >= 6 && x <= 8) ||
    (y >= 5 && y <= 9 && x >= 6 && x <= 13);
}

function cliff(ctx, from, to, depth, side, x, y) {
  const [[a, b], [c, d]] = [from, to];
  const bottom = depth + Math.round(noise(x, y, 8) * 8);
  const near = side ? '#2f3b3b' : '#35453f';
  polygon(ctx, [[a,b],[c,d],[c,d+bottom-5],[(a+c)/2,(b+d)/2+bottom],[a,b+bottom-2]], near);
  polygon(ctx, [[a,b+7],[c,d+6],[c,d+10],[(a+c)/2,(b+d)/2+11],[a,b+11]], side ? '#374340' : '#46544a');
  polygon(ctx, [[a,b+13],[c,d+11],[c,d+bottom-5],[(a+c)/2,(b+d)/2+bottom],[a,b+bottom-2]], side ? '#273239' : '#2c3a3a');
  for (let i = 0; i < 4; i++) {
    const t = noise(x, y, i+3);
    const yOffset = 5 + Math.floor(noise(x, y, i+7) * (depth-4));
    rect(ctx, i % 2 ? '#66705b52' : '#181f276d', a+(c-a)*t, b+(d-b)*t+yOffset, 2+i%2, 1);
  }
}

function drawFloor(ctx) {
  const tiles = [];
  for (let y = 0; y < ARENA_SIZE; y++) {
    for (let x = 0; x < ARENA_SIZE; x++) {
      if (hasGround(x,y)) tiles.push([x,y]);
    }
  }
  tiles.sort((a,b) => a[0]+a[1]-b[0]-b[1]);
  for (const [x,y] of tiles) {
    const [, right, front, left] = corners(x,y);
    if (!hasGround(x+1,y)) cliff(ctx, right, front, 17, true, x, y);
    if (!hasGround(x,y+1)) cliff(ctx, front, left, 17, false, x, y);
  }

  for (const [x,y] of tiles) {
    const paving = stoneTile(x,y);
    const palette = paving ? STONE_TILES : GRASS_TILES;
    const tint = palette[Math.floor(noise(x, y, 8) * palette.length)];
    const diamond = corners(x,y);
    polygon(ctx, diamond, tint, paving ? '#2f3d3a66' : '#283a3765');
    const [px,py] = toScreen(x+.5,y+.5);
    rect(ctx, paving ? '#8d938079' : '#7e96645b', px-1, py-4, 4, 1);
    if (paving && noise(x,y,4) > .53) {
      rect(ctx, '#2e413c95', px+3, py, 3, 1);
      rect(ctx, '#3c4b40', px+6, py+1, 4, 1);
      rect(ctx, '#b3b28d57', px-6, py+2, 3, 1);
    }
    for (let grain = 0; grain < 6; grain++) {
      const [sx,sy] = toScreen(x+.15+noise(x,y,14+grain)*.7,y+.15+noise(x,y,24+grain)*.7);
      rect(ctx, grain % 2 ? '#a5a98344' : '#1f332e55', sx, sy, grain % 3 ? 1 : 2, 1);
    }
    if (!paving && noise(x,y,15) > .69) {
      for (let grass = 0; grass < 4; grass++) {
        const sx = px + Math.round(noise(x,y,30+grass)*13)-6;
        const sy = py + Math.round(noise(x,y,38+grass)*5)-2;
        rect(ctx, grass % 2 ? '#738a61' : '#516d53', sx, sy-2, 1, 3);
        rect(ctx, '#5e7959', sx-1, sy, 1, 1);
      }
    }
    if ((!hasGround(x+1,y) || !hasGround(x,y+1)) && noise(x,y,7) > .42) {
      rect(ctx, '#6e825c', px-6, py, 6, 1);
      rect(ctx, '#769062', px-4, py+1, 2, 3);
    }
  }

  const center = {x:8.35,y:8.9};
  for (const [i, radius] of [4.18,3.78,1.22,.89].entries()) {
    const points = Array.from({length: 49}, (_, index) => {
      const angle = index * Math.PI / 24;
      return toScreen(center.x + Math.cos(angle) * radius, center.y + Math.sin(angle) * radius);
    });
    polygon(ctx, points, null, ['#777d665f','#9b9d7863','#acac8177','#737d6382'][i]);
  }
  for (let i = 0; i < 8; i++) {
    const angle = i * Math.PI/4;
    const [x,y] = toScreen(center.x + Math.cos(angle)*3.98, center.y + Math.sin(angle)*3.98);
    polygon(ctx, [[x,y-3],[x+4,y],[x,y+3],[x-4,y]], '#727f69', '#a0a381a8');
    rect(ctx, '#b1a978', x, y, 1, 1);
  }
}

function drawProp(ctx, prop, clock) {
  const [x, y] = toScreen(prop.x+.5, prop.y+.5);
  const seed = prop.x * 19 + prop.y;
  switch (prop.art) {
    case 'pine': pine(ctx, x, y, seed); break;
    case 'stone': stone(ctx, x, y, .8 + noise(prop.x, prop.y, 3)*.45, 1); break;
    case 'pillar': pillar(ctx, x, y); break;
    case 'gate': gate(ctx, x, y); break;
    case 'wall':
      stone(ctx, x+4, y, 1.2);
      stone(ctx, x-5, y+2, .7, 1);
      break;
    case 'torch': {
      gradient(ctx, x, y-13, 29, '#d98f4a37', '#a7673000');
      pillar(ctx, x, y, 11);
      flame(ctx, x, y-13, clock);
      break;
    }
  }
}

function projectedArc(x, y, aim, r, angle, steps = 18) {
  const bearing = Math.atan2(aim.y, aim.x);
  return Array.from({length: steps + 1}, (_, index) => {
    const theta = bearing - angle + index * angle * 2 / steps;
    return toScreen(x + r * Math.cos(theta), y + r * Math.sin(theta));
  });
}

function circleOnGround(ctx, x, y, r, fill, stroke) {
  polygon(ctx, projectedArc(x, y, {x:1,y:0}, r, Math.PI, 28), fill, stroke);
}

function drawPreview(ctx, battle, range) {
  const {hero, aim, selected} = battle;
  if (!battle.preview || battle.outcome === 'won' || battle.outcome === 'lost') return;
  const skill = SKILLS[selected];
  if (selected === 'slash') {
    const contour = [toScreen(hero.x, hero.y), ...projectedArc(hero.x, hero.y, aim, range, skill.halfAngle)];
    polygon(ctx, contour, '#e99d4d38', '#f9b66ee0');
    const [startX, startY] = toScreen(hero.x, hero.y);
    const [endX, endY] = toScreen(hero.x + aim.x * range, hero.y + aim.y * range);
    ctx.setLineDash([2,3]);
    ctx.beginPath();
    ctx.moveTo(startX,startY);
    ctx.lineTo(endX,endY);
    ctx.strokeStyle = '#ffe1ab83';
    ctx.stroke();
    ctx.setLineDash([]);
  } else {
    const w = skill.halfWidth;
    const a = {x:hero.x-aim.y*w, y:hero.y+aim.x*w};
    const b = {x:hero.x+aim.y*w, y:hero.y-aim.x*w};
    polygon(ctx, [toScreen(a.x,a.y),toScreen(a.x+aim.x*range,a.y+aim.y*range),
      toScreen(b.x+aim.x*range,b.y+aim.y*range),toScreen(b.x,b.y)], '#83dace38', '#a8f1e2d7');
    const [endX,endY] = toScreen(hero.x+aim.x*range,hero.y+aim.y*range);
    polygon(ctx, [[endX,endY-2],[endX+3,endY],[endX,endY+2],[endX-3,endY]], '#b5f3e1');
  }
}

function healthBar(ctx, x, y, fraction, targeted) {
  rect(ctx, '#25232c', x-10, y-1, 20, 4);
  rect(ctx, '#593d44', x-9, y, 18, 2);
  rect(ctx, targeted ? '#e59265' : '#c77679', x-9, y, Math.ceil(18*fraction), 2);
}

function drawHero(ctx, hero, clock) {
  const [x,y] = toScreen(hero.x, hero.y);
  ellipse(ctx, x, y, 9, 4, '#172025a6');
  circleOnGround(ctx, hero.x, hero.y, .59, '#ebb67720', '#f5ce9ba8');
  const bob = hero.moving ? Math.round(Math.sin(hero.stride*2)*1.8) : Math.round(Math.sin(clock*5)*.65);
  sprite(ctx, 'hero', x, y-2-bob, {flip:hero.facing<0, flash:hero.hurt>.19});
  polygon(ctx, [[x,y-29],[x+3,y-26],[x,y-23],[x-3,y-26]], '#f4bd84');
  rect(ctx, '#ffe4b6', x, y-27, 1, 1);
}

function enemyLift(enemy, clock) {
  return enemy.id === 'bat' ? 7 + Math.round(Math.sin(clock*7)*2) : Math.round(Math.abs(Math.sin(enemy.stride))*1.4);
}

export function aimPoint(battle, screenX, screenY) {
  for (const enemy of battle.enemies) {
    if (enemy.hp <= 0) continue;
    const [x,y] = toScreen(enemy.x, enemy.y);
    const lift = enemyLift(enemy, battle.clock);
    const height = enemy.id === 'golem' ? 18 : 12;
    if (Math.abs(screenX-x) <= 9 && screenY >= y-lift-height-2 && screenY <= y+4) {
      return {x:enemy.x, y:enemy.y};
    }
  }
  return toWorld(screenX,screenY);
}

function drawEnemy(ctx, enemy, clock, targeted) {
  const [x,y] = toScreen(enemy.x, enemy.y);
  ellipse(ctx, x, y, enemy.id === 'golem' ? 12 : 8, 4, '#1b2124a8');
  if (targeted) circleOnGround(ctx, enemy.x, enemy.y, .65, '#ffce8b31', '#ffd18fcf');
  const jump = enemyLift(enemy, clock);
  const scale = enemy.id === 'golem' ? 21 : enemy.id === 'slime' ? 15 : 14;
  sprite(ctx, enemy.id, x, y-1-jump, {flash:enemy.hurt>.085, flip:enemy.id === 'bat' && Math.sin(clock*2) < 0});
  healthBar(ctx, x, y-scale-jump-4, enemy.hp/enemy.maxHp, targeted);
  if (targeted) rect(ctx, '#ffdea3', x-1, y-scale-jump-9, 3, 2);
  if (enemy.wind > 0) rect(ctx, '#f39377', x-1, y-scale-jump-14, 2, 4);
  if (enemy.slow > 0) {
    rect(ctx, '#89dddb', x-8, y-7, 2, 1);
    rect(ctx, '#a8d9d9', x+9, y-4, 1, 1);
  }
}

function drawEffect(ctx, effect) {
  const ratio = effect.age/effect.duration;
  const [x, y] = toScreen(effect.x,effect.y);
  ctx.globalAlpha = 1-ratio;
  if (effect.kind === 'slash') {
    const skill = SKILLS.slash;
    const radius = skill.range*(.55+.45*ratio);
    const arc = projectedArc(effect.x, effect.y, effect.aim, radius, skill.halfAngle + .08);
    const inner = projectedArc(effect.x, effect.y, effect.aim, radius*.77, skill.halfAngle*.9).reverse();
    const lift = ([sx,sy]) => [sx,sy-7];
    polygon(ctx, [...arc, ...inner].map(lift), '#f2904c', '#ffd69a');
  } else if (effect.kind === 'enemy-strike') {
    circleOnGround(ctx, effect.x, effect.y, effect.range, '#e87e655b', '#d85f51');
  } else {
    const colors = effect.kind === 'ice-hit' || effect.kind === 'release' ? ['#e6ffed','#94ded6','#518eac'] :
      effect.kind === 'fall' ? ['#e1d3a6','#aab584','#818d72'] : ['#fff0c5','#f69e66','#ad5e45'];
    const particles = effect.kind === 'fall' ? 12 : 9;
    for (let i = 0; i < particles; i++) {
      const angle = i * 2.399;
      const radius = (3 + 16*ratio) * (.42 + noise(i, y, 11)*.58);
      rect(ctx, colors[i%3], x + radius*Math.cos(angle), y-8 + radius*.66*Math.sin(angle) - 5*ratio, i%3+1, i%2+1);
    }
    if (effect.amount) {
      ctx.globalAlpha = Math.min(1, (1-ratio)*2);
      ctx.font = 'bold 10px monospace';
      ctx.textAlign = 'center';
      ctx.lineWidth = 2;
      ctx.strokeStyle = '#211f26';
      ctx.fillStyle = colors[0];
      const textY = Math.round(y-27-ratio*13);
      ctx.strokeText(effect.kind === 'hero-hit' ? '-'+effect.amount : effect.amount, Math.round(x), textY);
      ctx.fillText(effect.kind === 'hero-hit' ? '-'+effect.amount : effect.amount, Math.round(x), textY);
    }
  }
  ctx.globalAlpha = 1;
}

export function createArena(canvas) {
  const ctx = canvas.getContext('2d', {alpha:false});
  const floor = document.createElement('canvas');
  floor.width = WIDTH;
  floor.height = HEIGHT;
  const ground = floor.getContext('2d', {alpha:false});
  backdrop(ground);
  drawFloor(ground);
  const props = PROPS.map(prop => ({depth: prop.x+prop.y+1, prop}));
  document.querySelectorAll('canvas[data-art]').forEach(icon => paintIcon(icon, icon.dataset.art));

  return function render(battle) {
    ctx.drawImage(floor,0,0);
    const range = attackRange(battle);
    const targets = previewTargets(battle, range);
    drawPreview(ctx, battle, range);
    for (const enemy of battle.enemies) {
      if (enemy.hp > 0 && enemy.wind > 0) {
        circleOnGround(ctx, enemy.x, enemy.y, enemy.reach, '#dd725a32', '#e77b63');
      }
    }
    const entities = [...props, {depth:battle.hero.x+battle.hero.y, hero:battle.hero},
      ...battle.enemies.filter(enemy => enemy.hp>0).map(enemy => ({depth:enemy.x+enemy.y, enemy}))];
    entities.sort((a,b) => a.depth-b.depth);
    for (const entity of entities) {
      if (entity.prop) drawProp(ctx, entity.prop, battle.clock);
      else if (entity.hero) drawHero(ctx, entity.hero, battle.clock);
      else drawEnemy(ctx, entity.enemy, battle.clock, targets.has(entity.enemy.id));
    }
    for (const cast of battle.casts) {
      const [x,y] = toScreen(cast.x,cast.y);
      const [behindX,behindY] = toScreen(cast.x-cast.aim.x*.65,cast.y-cast.aim.y*.65);
      gradient(ctx,x,y-8,13,'#a7f3ea59','#73c7c900');
      polygon(ctx, [[behindX,behindY-9],[x-2,y-11],[x+5,y-8],[x-1,y-5]], '#88d2d2','#c2f3e7');
      rect(ctx,'#eaffe6',x,y-9,3,2);
    }
    battle.effects.forEach(effect => drawEffect(ctx,effect));
    for (let i=0; i<23; i++) {
      const clock = battle.clock;
      const x = 42 + noise(i,12,22)*500 + Math.sin(clock*.31+i)*8;
      const y = 48 + noise(i,14,20)*232 + Math.cos(clock*.53+i)*7;
      const alpha = .14 + (Math.sin(clock*1.3+i)+1)*.18;
      ctx.globalAlpha = alpha;
      rect(ctx, i%3 ? '#c1a779' : '#abc5ad', x, y, i%7 ? 1 : 2, 1);
    }
    ctx.globalAlpha = 1;
    return targets;
  };
}
