const PALETTES = {
  hero: ['#20202b', '#414c54', '#9aa9a1', '#843f32', '#c06840', '#eeaa6e', '#f4d19a', '#435861'],
  slime: ['#1b2926', '#33493a', '#4c6d4a', '#6e9a56', '#a3bd69', '#def5a6', '#273b33'],
  golem: ['#1c2527', '#354245', '#536158', '#6e7965', '#98a187', '#f1a965', '#857d55'],
  bat: ['#251c2c', '#442e49', '#644768', '#89618a', '#b48aac', '#f2b486', '#402c48']
};

const SPRITES = {
  hero: [
    '........0000.......',
    '.......044450......',
    '......04455550.....',
    '......03456660.....',
    '......03360060.....',
    '......03466600.....',
    '.....034445510.....',
    '....03345411120.2..',
    '....0344447120022..',
    '....0344547110222..',
    '...0334544770122...',
    '...033444471012....',
    '...03444417011.....',
    '..03334447072......',
    '..03334440700......',
    '..000344070.......',
    '.....001010.......',
    '......07010.......',
    '......00000.......'
  ],
  slime: [
    '.......0000........',
    '.....00444400......',
    '....0444454440.....',
    '...034344444330....',
    '...033344343330....',
    '..03333043043330...',
    '..03333043043330...',
    '.033333353533330...',
    '.0233333333333320..',
    '.0223333333332220..',
    '..01222222222100...',
    '...00000000000.....'
  ],
  golem: [
    '......000000.......',
    '.....03344330......',
    '.....034444340.....',
    '....00344334300....',
    '...06643355346600..',
    '..066633333366330..',
    '..043310000143320..',
    '.0432103444013210..',
    '.04321034240262110.',
    '.03331032330133210.',
    '.03232033430232310.',
    '..000003360200000..',
    '....04323042230....',
    '....03323043330....',
    '...0332310433310...',
    '...0222100222110...',
    '...0000000000000...'
  ],
  bat: [
    '.00......0...0......00.',
    '.020.....02020.....020.',
    '..0320...03430...0230..',
    '..03420.034440.02430...',
    '...0332033553320330....',
    '...023323444323320.....',
    '....0232013012320......',
    '.....000.040.000.......',
    '.........010...........',
    '..........0............'
  ]
};

export function rect(ctx, color, x, y, w, h) {
  ctx.fillStyle = color;
  ctx.fillRect(Math.round(x), Math.round(y), w, h);
}

export function polygon(ctx, vertices, fill, stroke) {
  ctx.beginPath();
  for (const [i, [x, y]] of vertices.entries()) {
    const point = [Math.round(x), Math.round(y)];
    if (i === 0) ctx.moveTo(...point);
    else ctx.lineTo(...point);
  }
  ctx.closePath();
  if (fill) {
    ctx.fillStyle = fill;
    ctx.fill();
  }
  if (stroke) {
    ctx.strokeStyle = stroke;
    ctx.stroke();
  }
}

export function sprite(ctx, type, x, y, {flip = false, flash = false} = {}) {
  const pixels = SPRITES[type];
  const palette = PALETTES[type];
  const width = pixels[0].length;
  const baseX = Math.round(x) - Math.floor(width / 2);
  const baseY = Math.round(y) - pixels.length;
  for (const [row, pattern] of pixels.entries()) {
    for (let column = 0; column < pattern.length; column++) {
      if (pattern[column] === '.') continue;
      const index = Number(pattern[column]);
      rect(ctx, flash && index > 0 ? '#eadac0' : palette[index], baseX + (flip ? width - column - 1 : column), baseY + row, 1, 1);
    }
  }
}

const ICONS = {
  logo: [
    '.......11.......', '.......121......', '......12321.....', '......123321....', '.....1234421....',
    '...1.1234421....', '...1212344321...', '..12322344321...', '..123334443321..', '.1233444443321..',
    '.1233444543421..', '.1233445544321..', '..12344544321...', '...123444321....', '....1223321.....',
    '......111.......'
  ],
  slash: [
    '............1...', '..........1221..', '........123321..', '.......123321...', '.....1234321....',
    '....12344321....', '...12344321.....', '..12344321......', '..1344321.......', '.1344321....2...',
    '.133321...21....', '.1321....21.....', '..13212121......', '...12221........', '....11..........'
  ],
  bolt: [
    '.............1..', '............131.', '...........1341.', '..........1341..', '.........1341...',
    '.....1..1341....', '....12.1341.....', '......1341......', '.....1341...1...', '....13412..21...',
    '...1341...21....', '..1231...21.....', '..121....1......', '.11......1......', '...1............'
  ]
};
const WARM = ['#35231f', '#763b2a', '#b35534', '#e6894e', '#f8b972', '#ffe4b5'];
const COLD = ['#223844', '#335458', '#457f83', '#71bcb9', '#b1ebe2', '#eefdff'];

export function paintIcon(canvas, name) {
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  if (SPRITES[name]) {
    sprite(ctx, name, canvas.width / 2, (canvas.height + SPRITES[name].length) / 2 - 1);
    return;
  }
  const pixels = ICONS[name];
  const palette = name === 'bolt' ? COLD : WARM;
  const startX = Math.floor((canvas.width - pixels[0].length) / 2);
  const startY = Math.floor((canvas.height - pixels.length) / 2);
  pixels.forEach((pattern, y) => [...pattern].forEach((code, x) => {
    if (code !== '.') rect(ctx, palette[code], startX + x, startY + y, 1, 1);
  }));
}

export function noise(x, y, seed = 1) {
  const value = Math.imul(x + seed * 17, 374761393) ^ Math.imul(y + seed * 23, 668265263);
  const mixed = Math.imul(value ^ (value >>> 13), 1274126177);
  return ((mixed ^ (mixed >>> 16)) >>> 0) / 4294967296;
}

export function ellipse(ctx, x, y, rx, ry, color) {
  ctx.beginPath();
  ctx.ellipse(Math.round(x), Math.round(y), rx, ry, 0, 0, Math.PI * 2);
  ctx.fillStyle = color;
  ctx.fill();
}

export function pine(ctx, x, y, seed, scale = 1) {
  const height = Math.round((32 + noise(seed, 5) * 22) * scale);
  const width = Math.round((11 + noise(seed, 9) * 5) * scale);
  const tone = noise(seed, 0);
  const dark = tone > .46 ? '#263d39' : '#243537';
  const mid = tone > .46 ? '#365048' : '#304749';
  const lit = tone > .46 ? '#486354' : '#455959';
  ellipse(ctx, x + 3, y, width + 3, 5, '#101c2580');
  rect(ctx, '#2e2c2b', x - 2, y - height + 7, 5, height - 6);
  rect(ctx, '#5b5445', x - 2, y - 10, 1, 9);
  for (let tier = 2; tier >= 0; tier--) {
    const top = y - height + tier * height * .18;
    const foot = top + height * (.56 + tier * .045);
    const span = width * (.51 + tier * .235);
    polygon(ctx, [[x, top], [x + span * .3, top + 8], [x + span * .28, top + 11],
      [x + span * .72, foot - 6], [x + span, foot - 2], [x + span * .72, foot + 1],
      [x + span * .28, foot], [x + 3, foot + 4], [x - span * .38, foot],
      [x - span * .78, foot + 1], [x - span, foot - 3], [x - span * .6, foot - 9]], dark);
    polygon(ctx, [[x, top + 1], [x + 1, top + 12], [x - span * .14, foot - 5], [x + 1, foot - 2],
      [x - span * .43, foot - 3], [x - span * .71, foot], [x - span * .91, foot - 3],
      [x - span * .48, foot - 9]], mid);
    rect(ctx, lit, x - span * .31, foot - 8, 3, 1);
    rect(ctx, lit, x - span * .57, foot - 4, 4, 1);
    rect(ctx, '#2e4442', x + span * .38, foot - 1, 4, 1);
  }
}

export function stone(ctx, x, y, scale = 1, tint = 0) {
  const pts = (coords) => coords.map(([dx, dy]) => [x + dx * scale, y + dy * scale]);
  ellipse(ctx, x + 2, y, 9 * scale, 3 * scale, '#172125aa');
  polygon(ctx, pts([[-8,-1],[-7,-6],[-2,-9],[5,-8],[9,-4],[8,1],[2,3],[-3,3]]), '#30383c');
  polygon(ctx, pts([[-8,-2],[-7,-6],[-2,-9],[5,-8],[9,-4],[3,-1],[-3,-1]]), tint ? '#737965' : '#626e64');
  polygon(ctx, pts([[-7,-6],[-2,-9],[5,-8],[2,-6],[-1,-5],[-4,-5],[-5,-3]]), tint ? '#99a17b' : '#7c8672');
  polygon(ctx, pts([[3,-1],[9,-4],[8,1],[2,3]]), '#3e4a47');
}

export function pillar(ctx, x, y, height = 22) {
  ellipse(ctx, x + 3, y + 1, 10, 4, '#192228b3');
  polygon(ctx, [[x-9,y-2],[x,y-6],[x+9,y-2],[x+9,y+2],[x,y+6],[x-9,y+2]], '#3e4e4b');
  for (let base = y - 3; base > y - height; base -= 5) {
    polygon(ctx, [[x-6,base-4],[x,base-7],[x+6,base-4],[x+6,base+1],[x,base+4],[x-6,base+1]], '#454f4b');
    polygon(ctx, [[x-6,base-4],[x,base-1],[x,base+3],[x-6,base]], '#6c7768');
    polygon(ctx, [[x-6,base-4],[x,base-7],[x+6,base-4],[x,base-1]], '#8c9179');
    rect(ctx, '#a2a180', x - 5, base - 3, 3, 1);
  }
  const top = y - height;
  polygon(ctx, [[x-7,top-1],[x,top-5],[x+7,top-1],[x,top+3]], '#979982');
  rect(ctx, '#708361', x - 4, top - 1, 4, 1);
  rect(ctx, '#a9ad83', x - 2, top - 3, 2, 1);
}

export function gate(ctx, x, y) {
  pillar(ctx, x - 15, y - 1, 28);
  pillar(ctx, x + 15, y - 1, 28);
  const arch = [
    [-21,-27],[-20,-34],[-15,-34],[-15,-39],[-10,-39],[-10,-45],[-5,-45],[-5,-48],
    [6,-48],[6,-45],[11,-45],[11,-39],[16,-39],[16,-33],[21,-33],[21,-26],
    [10,-26],[10,-31],[8,-31],[8,-36],[4,-36],[4,-39],[-4,-39],[-4,-36],[-8,-36],
    [-8,-31],[-11,-31],[-11,-27]
  ];
  polygon(ctx, arch.map(([dx, dy]) => [x+dx+2, y+dy+2]), '#384542');
  polygon(ctx, arch.map(([dx, dy]) => [x+dx, y+dy]), '#73786a');
  [[-20,-34,6],[-14,-39,5],[-9,-44,5],[-4,-47,10],[7,-44,4],[12,-38,4],[17,-32,4]].forEach(([dx,dy,w]) => {
    rect(ctx, '#a3a189', x+dx, y+dy, w, 2);
    rect(ctx, '#535f55', x+dx+w-1, y+dy+2, 1, 5);
  });
  rect(ctx, '#667b57', x-7, y-45, 12, 1);
  rect(ctx, '#e9ac6c', x-1, y-44, 2, 2);
  rect(ctx, '#bc915f', x, y-42, 1, 2);
  rect(ctx, '#71905c', x-16, y-36, 7, 1);
  rect(ctx, '#586e53', x-15, y-35, 2, 8);
  rect(ctx, '#5c7356', x+16, y-31, 2, 11);
}

export function flame(ctx, x, y, clock) {
  const flicker = Math.round(Math.sin(clock * 17 + x) * 2);
  rect(ctx, '#383238', x-4, y+3, 8, 2);
  rect(ctx, '#66554c', x-2, y+1, 4, 2);
  rect(ctx, '#bd5839', x-3, y-4, 6, 5);
  rect(ctx, '#d06a3b', x-2, y-8+flicker, 4, 9-flicker);
  rect(ctx, '#f5a457', x-1, y-7, 3, 7);
  rect(ctx, '#f8d88d', x-1, y-3, 2, 4);
  rect(ctx, '#f0a14c', x+2, y-10-flicker, 1, 1);
}
