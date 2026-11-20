import { createRequire } from 'node:module';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const require = createRequire(import.meta.url);
const { createCanvas } = require('@napi-rs/canvas');
const toolPath = fileURLToPath(new URL('.', import.meta.url));
const assets = resolve(toolPath, '../assets');

// Load the original drawing functions without altering the archived source.
async function drawingModule(name, extraExports) {
  const base = new URL('./reference/', import.meta.url);
  let source = await readFile(new URL(name, base), 'utf8');
  source = source.replace(/from '(\.\/[^']+)'/g, (_, path) => "from '" + new URL(path, base) + "'");
  source += '\nexport {' + extraExports + '};';
  return import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));
}
const { backdrop, drawFloor, drawProp, toScreen } =
  await drawingModule('arena.mjs', 'backdrop, drawFloor, drawProp');
const { paintIcon, sprite, SPRITES } = await drawingModule('art.mjs', 'SPRITES');
const { PROPS } = await import('./reference/combat.mjs');

const writes = [];
function makePng(path, width, height, render) {
  const canvas = createCanvas(width, height);
  render(canvas.getContext('2d'), canvas);
  writes.push(writeFile(resolve(assets, path), canvas.toBuffer('image/png')));
}
makePng('terrain/background.png', 576, 340, backdrop);
makePng('terrain/ground.png', 576, 340, drawFloor);
for (const name of ['hero', 'slime', 'golem', 'bat']) {
  const width = SPRITES[name][0].length;
  const height = SPRITES[name].length;
  for (const flash of [false, true]) {
    makePng('sprites/' + name + (flash ? '_hit' : '') + '.png', width, height,
      ctx => sprite(ctx, name, Math.floor(width / 2), height, { flash }));
  }
}
for (const name of ['logo', 'slash', 'bolt']) {
  makePng('ui/' + name + '.png', 26, 26, (_, canvas) => paintIcon(canvas, name));
}
for (const prop of PROPS) {
  const [x, y] = toScreen(prop.x + .5, prop.y + .5);
  const variants = prop.art === 'torch' ? [-2, -1, 0, 1, 2] : [null];
  for (const flicker of variants) {
    const suffix = flicker === null ? '' : '_' + (flicker + 2);
    const phase = flicker === null ? 0 : Math.asin(flicker / 2);
    makePng('props/' + prop.x + '_' + prop.y + suffix + '.png', 80, 80, ctx => {
      ctx.translate(40 - x, 60 - y);
      drawProp(ctx, prop, (phase - x) / 17);
    });
  }
}
await Promise.all(writes);
console.log('Exported', writes.length, 'pixel-art PNGs.');
