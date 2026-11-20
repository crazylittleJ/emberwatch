export const ARENA_SIZE = 17;
export const STEP = 1 / 60;
const DIAGONAL = Math.SQRT1_2;
const PLAYER_RADIUS = .27;
const PLAYER_SPEED = 4.3;

export const SKILLS = Object.freeze({
  slash: Object.freeze({
    key: 'Q', name: '餘燼斬', short: '近距扇形', category: '近距 · 扇形斬擊',
    description: '向瞄準方向揮出火焰，擊中扇形範圍內的所有魔物。',
    range: 3.4, halfAngle: Math.PI * .25, damage: 36, cooldown: .7
  }),
  bolt: Object.freeze({
    key: 'E', name: '霜星箭', short: '遠距直線', category: '遠距 · 直線投射',
    description: '發射霜星，命中第一隻魔物時造成傷害並短暫緩速。',
    range: 8, halfWidth: .52, damage: 52, cooldown: 1.25, speed: 16, slow: 1.45
  })
});

export const PROPS = Object.freeze([
  {x: 1, y: 2, art: 'pine'}, {x: 1, y: 4, art: 'pine'}, {x: 0, y: 6, art: 'pine'},
  {x: 4, y: 1, art: 'pine'}, {x: 5, y: 0, art: 'pine'}, {x: 7, y: 1, art: 'pine'},
  {x: 10, y: 1, art: 'pine'}, {x: 12, y: 2, art: 'stone'}, {x: 14, y: 1, art: 'pine'},
  {x: 16, y: 4, art: 'pine'}, {x: 15, y: 5, art: 'pine'}, {x: 16, y: 7, art: 'pine'},
  {x: 16, y: 10, art: 'pine'}, {x: 15, y: 13, art: 'pine'}, {x: 14, y: 15, art: 'pine'},
  {x: 13, y: 16, art: 'stone'}, {x: 10, y: 16, art: 'pine'}, {x: 4, y: 16, art: 'pine'},
  {x: 2, y: 15, art: 'pine'}, {x: 1, y: 14, art: 'pine'}, {x: 1, y: 10, art: 'pine'},
  {x: 2, y: 12, art: 'stone'}, {x: 2, y: 8, art: 'pine'}, {x: 0, y: 12, art: 'pine'},
  {x: 6, y: 15, art: 'stone'}, {x: 14, y: 10, art: 'stone'}, {x: 13, y: 4, art: 'pine'},
  {x: 4, y: 4, art: 'pillar'}, {x: 7, y: 4, art: 'gate'}, {x: 6, y: 3, art: 'torch'},
  {x: 10, y: 4, art: 'torch'}, {x: 12, y: 12, art: 'torch'}, {x: 5, y: 12, art: 'torch'},
  {x: 5, y: 6, art: 'wall'}, {x: 4, y: 7, art: 'wall'}, {x: 11, y: 13, art: 'pillar'},
  {x: 9, y: 14, art: 'wall'}, {x: 8, y: 14, art: 'wall'}
]);

const ENEMIES = Object.freeze([
  {id: 'slime', x: 8.9, y: 8.0, maxHp: 52, speed: 1.72, power: 11, reach: 1.28, windup: .46, cooldown: .92, radius: .33},
  {id: 'golem', x: 12.5, y: 8.15, maxHp: 108, speed: 1.33, power: 22, reach: 1.7, windup: .66, cooldown: 1.18, radius: .42},
  {id: 'bat', x: 5.95, y: 8.3, maxHp: 46, speed: 2.48, power: 9, reach: 1.19, windup: .35, cooldown: .85, radius: .27}
]);
const solid = new Set(PROPS.map(prop => prop.y * ARENA_SIZE + prop.x));

export function hasGround(x, y) {
  const edge = ARENA_SIZE - 1;
  return x >= 0 && y >= 0 && x <= edge && y <= edge &&
    x + y >= 2 && x + y <= 2 * edge - 2 && Math.abs(x - y) <= edge - 2;
}

export function isSolid(x, y) {
  const column = Math.floor(x);
  const row = Math.floor(y);
  return !hasGround(column, row) || solid.has(row * ARENA_SIZE + column);
}

export function createBattle() {
  return {
    clock: 0,
    outcome: 'ready',
    selected: 'slash',
    preview: true,
    aim: {x: .46, y: -.89},
    pointer: null,
    hero: {x: 7.75, y: 10.25, hp: 100, maxHp: 100, facing: 1, stride: 0, moving: false, hurt: 0},
    enemies: ENEMIES.map(enemy => ({...enemy, hp: enemy.maxHp, active: false, delay: 0, wind: 0, hurt: 0, slow: 0, stride: 0})),
    cooldowns: {slash: 0, bolt: 0},
    casts: [],
    effects: []
  };
}

function normalize(x, y) {
  const distance = Math.hypot(x, y);
  return distance > .001 ? {x: x / distance, y: y / distance} : {x: 0, y: 0};
}

function aimAt(battle) {
  if (!battle.pointer) return;
  const dx = battle.pointer.x - battle.hero.x;
  const dy = battle.pointer.y - battle.hero.y;
  if (Math.hypot(dx, dy) < .14) return;
  battle.aim = normalize(dx, dy);
}

function canStand(x, y, radius) {
  return !isSolid(x - radius, y - radius) && !isSolid(x + radius, y - radius) &&
    !isSolid(x - radius, y + radius) && !isSolid(x + radius, y + radius);
}

function moveBody(body, dx, dy, radius, others) {
  function open(x, y) {
    return canStand(x, y, radius) &&
      others.every(other => other.hp <= 0 || Math.hypot(other.x - x, other.y - y) >= radius + (other.radius ?? PLAYER_RADIUS));
  }
  if (open(body.x + dx, body.y)) body.x += dx;
  if (open(body.x, body.y + dy)) body.y += dy;
}

function lineClear(x, y, toX, toY) {
  const samples = Math.ceil(Math.hypot(toX - x, toY - y) * 9);
  for (let i = 1; i <= samples; i++) {
    const t = i / samples;
    if (isSolid(x + (toX - x) * t, y + (toY - y) * t)) return false;
  }
  return true;
}

function inSlash(source, aim, enemy) {
  const dx = enemy.x - source.x;
  const dy = enemy.y - source.y;
  const distance = Math.hypot(dx, dy);
  return distance <= SKILLS.slash.range && dx * aim.x + dy * aim.y >= Math.cos(SKILLS.slash.halfAngle) * distance;
}

function boltTargets(enemies, source, aim, limit) {
  const targets = [];
  for (const enemy of enemies) {
    if (enemy.hp <= 0) continue;
    const dx = enemy.x - source.x;
    const dy = enemy.y - source.y;
    const along = dx * aim.x + dy * aim.y;
    const across = Math.abs(dx * aim.y - dy * aim.x);
    if (along >= 0 && along <= limit && across <= SKILLS.bolt.halfWidth) targets.push({enemy, along});
  }
  return targets.sort((a, b) => a.along - b.along);
}

export function attackRange(battle) {
  const {hero, aim, selected} = battle;
  if (selected === 'slash') return SKILLS.slash.range;
  const {range} = SKILLS.bolt;
  for (let distance = .12; distance <= range; distance += .12) {
    if (isSolid(hero.x + aim.x * distance, hero.y + aim.y * distance)) return distance - .12;
  }
  return range;
}

export function previewTargets(battle, range = attackRange(battle)) {
  if (!battle.preview || battle.outcome === 'won' || battle.outcome === 'lost') return new Set();
  const {hero, aim, enemies, selected} = battle;
  if (selected === 'bolt') {
    const [target] = boltTargets(enemies, hero, aim, range);
    return new Set(target ? [target.enemy.id] : []);
  }
  return new Set(enemies.filter(enemy => enemy.hp > 0 && inSlash(hero, aim, enemy) &&
    lineClear(hero.x, hero.y, enemy.x, enemy.y)).map(enemy => enemy.id));
}

function effect(battle, kind, x, y, duration, extra = {}) {
  battle.effects.push({kind, x, y, duration, age: 0, ...extra});
}

function damageEnemy(battle, enemy, damage, kind) {
  enemy.hp = Math.max(0, enemy.hp - damage);
  enemy.active = true;
  enemy.hurt = .18;
  if (kind === 'bolt') enemy.slow = SKILLS.bolt.slow;
  effect(battle, kind === 'bolt' ? 'ice-hit' : 'fire-hit', enemy.x, enemy.y, .48, {amount: damage});
  if (enemy.hp === 0) effect(battle, 'fall', enemy.x, enemy.y, .68, {art: enemy.id});
}

function cast(battle) {
  const {hero, aim, selected, cooldowns} = battle;
  if (cooldowns[selected] > 0) return;
  const skill = SKILLS[selected];
  cooldowns[selected] = skill.cooldown;
  if (selected === 'bolt') {
    battle.casts.push({originX: hero.x, originY: hero.y, x: hero.x, y: hero.y, aim: {...aim}, traveled: 0});
    effect(battle, 'release', hero.x, hero.y, .17);
    return;
  }
  effect(battle, 'slash', hero.x, hero.y, .26, {aim: {...aim}});
  for (const enemy of battle.enemies) {
    if (enemy.hp > 0 && inSlash(hero, aim, enemy) && lineClear(hero.x, hero.y, enemy.x, enemy.y)) {
      damageEnemy(battle, enemy, skill.damage, 'slash');
    }
  }
}

function advanceProjectiles(battle, dt) {
  const {range, speed, damage} = SKILLS.bolt;
  battle.casts = battle.casts.filter(projectile => {
    const {originX, originY, aim, traveled} = projectile;
    const next = Math.min(range, traveled + dt * speed);
    for (const {enemy, along} of boltTargets(battle.enemies, {x: originX, y: originY}, aim, next)) {
      if (along + .26 < traveled) continue;
      const toX = originX + aim.x * along;
      const toY = originY + aim.y * along;
      if (!lineClear(projectile.x, projectile.y, toX, toY)) break;
      damageEnemy(battle, enemy, damage, 'bolt');
      return false;
    }
    const x = originX + aim.x * next;
    const y = originY + aim.y * next;
    if (!lineClear(projectile.x, projectile.y, x, y)) {
      effect(battle, 'release', projectile.x, projectile.y, .2);
      return false;
    }
    projectile.x = x;
    projectile.y = y;
    projectile.traveled = next;
    return next < range;
  });
}

function advanceEnemy(battle, enemy, dt) {
  if (enemy.hp <= 0) return;
  const {hero, enemies} = battle;
  const dx = hero.x - enemy.x;
  const dy = hero.y - enemy.y;
  const distance = Math.hypot(dx, dy);
  enemy.hurt = Math.max(0, enemy.hurt - dt);
  enemy.slow = Math.max(0, enemy.slow - dt);
  enemy.delay = Math.max(0, enemy.delay - dt);
  if (distance < 4.15 && lineClear(enemy.x, enemy.y, hero.x, hero.y)) enemy.active = true;
  if (!enemy.active) return;

  if (enemy.wind > 0) {
    enemy.wind = Math.max(0, enemy.wind - dt);
    if (enemy.wind === 0) {
      effect(battle, 'enemy-strike', enemy.x, enemy.y, .25, {range: enemy.reach});
      if (distance <= enemy.reach && lineClear(enemy.x, enemy.y, hero.x, hero.y)) {
        hero.hp = Math.max(0, hero.hp - enemy.power);
        hero.hurt = .3;
        effect(battle, 'hero-hit', hero.x, hero.y, .47, {amount: enemy.power});
      }
      enemy.delay = enemy.cooldown;
    }
    return;
  }
  if (distance < enemy.reach * .9 && lineClear(enemy.x, enemy.y, hero.x, hero.y)) {
    if (enemy.delay === 0) enemy.wind = enemy.windup;
    return;
  }
  if (enemy.hurt > .09) return;
  const speed = enemy.speed * (enemy.slow > 0 ? .54 : 1);
  const heading = normalize(dx, dy);
  const previousX = enemy.x;
  const previousY = enemy.y;
  moveBody(enemy, heading.x * speed * dt, heading.y * speed * dt, enemy.radius, [hero, ...enemies.filter(other => other !== enemy)]);
  enemy.stride += Math.hypot(enemy.x - previousX, enemy.y - previousY) * 10;
}

// Simulation accepts only commands and elapsed ticks. Rendering and input do not own battle state.
export function simulate(battle, command, dt = STEP) {
  if (command.skill && Object.hasOwn(SKILLS, command.skill)) battle.selected = command.skill;
  if (command.togglePreview) battle.preview = !battle.preview;
  if (command.aim) battle.pointer = command.aim;
  if (command.clearAim) battle.pointer = null;
  aimAt(battle);
  battle.clock += dt;
  battle.effects = battle.effects.filter(item => (item.age += dt) < item.duration);
  if (battle.outcome === 'won' || battle.outcome === 'lost') return;
  const moving = command.moveX || command.moveY;
  if (battle.outcome === 'ready' && (moving || command.cast)) battle.outcome = 'playing';
  if (battle.outcome !== 'playing') return;
  const {hero} = battle;
  hero.hurt = Math.max(0, hero.hurt - dt);
  hero.moving = false;
  if (moving) {
    const direction = normalize(command.moveX, command.moveY);
    const worldX = (direction.y + direction.x) * DIAGONAL;
    const worldY = (direction.y - direction.x) * DIAGONAL;
    const previousX = hero.x;
    const previousY = hero.y;
    moveBody(hero, worldX * PLAYER_SPEED * dt, worldY * PLAYER_SPEED * dt, PLAYER_RADIUS, battle.enemies);
    if (direction.x) hero.facing = Math.sign(direction.x);
    const distance = Math.hypot(hero.x - previousX, hero.y - previousY);
    hero.moving = distance > 0;
    hero.stride += distance * 13;
    aimAt(battle);
  }
  if (battle.pointer && Math.abs(battle.aim.x - battle.aim.y) > .06) hero.facing = Math.sign(battle.aim.x - battle.aim.y);
  for (const id of Object.keys(SKILLS)) battle.cooldowns[id] = Math.max(0, battle.cooldowns[id] - dt);
  if (command.cast) cast(battle);
  advanceProjectiles(battle, dt);
  if (battle.enemies.every(enemy => enemy.hp === 0)) {
    battle.outcome = 'won';
    return;
  }
  for (const enemy of battle.enemies) advanceEnemy(battle, enemy, dt);
  if (hero.hp === 0) battle.outcome = 'lost';
}
