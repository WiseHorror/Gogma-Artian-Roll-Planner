const U32 = 0xffffffff;
const COSTS = {
  rarity8ForgeZenny: 10000,
  rarity8PartsPerForge: 3,
  baseLevels: 5,
  basePointsPerLevel: 3000,
  baseZennyPerLevel: 2000,
  oricalcitePoints: 300,
  gogmaUpgradeDevices: 3,
  gogmaUpgradeZenny: 30000,
  skillResetDevices: 3,
  skillResetPoints: 1500,
  skillResetZenny: 9000,
  gogmaAmendPoints: 6000,
  gogmaAmendZenny: 5000,
};
let lastCalculation = null;
let importedExistingWeapons = [];
let currentExistingReinforcementTier = "gogma";
let currentExistingAttributeForce = null;

const setSkillNames = [
  "Arkveld's Hunger", "Blangonga's Spirit", "Doshaguma's Might",
  "Ebony Odogaron's Power", "Fulgur Anjanath's Will", "Gogmapocalypse",
  "Gore Magala's Tyranny", "Gravios's Protection", "Guardian Arkveld's Vitality",
  "Jin Dahaad's Revolt", "Leviathan's Fury", "Mizutsune's Prowess",
  "Nu Udra's Mutiny", "Omega Resonance", "Rathalos's Flare",
  "Rey Dau's Voltage", "Seregios's Tenacity", "Soul of the Dark Knight",
  "Uth Duna's Cover", "Xu Wu's Vigor", "Zoh Shia's Pulse",
];
const groupSkillNames = [
  "Alluring Pelt", "Buttery Leathercraft", "Flexible Leathercraft",
  "Fortifying Pelt", "Guardian's Protection", "Guardian's Pulse",
  "Imparted Wisdom", "Lord's Favor", "Lord's Fury", "Lord's Soul",
  "Neopteron Alert", "Neopteron Camouflage", "Scale Layering", "Scaling Prowess",
];
const weaponTypeNames = [
  "Great Sword", "Sword & Shield", "Dual Blades", "Long Sword", "Hammer",
  "Hunting Horn", "Lance", "Gunlance", "Switch Axe", "Charge Blade",
  "Insect Glaive", "Bow", "Heavy Bowgun", "Light Bowgun",
];
const weaponIconFiles = [
  "Wilds-GS-2.png", "Wilds-SNS-2.png", "Wilds-DB-2.png", "Wilds-LS-2.png",
  "Wilds-Hammer-2.png", "Wilds-HH-2.png", "Wilds-Lance-2.png", "Wilds-GL-2.png",
  "Wilds-SA-2.png", "Wilds-CB-2.png", "Wilds-IG-2.png", "Wilds-Bow-2.png",
  "Wilds-HBG-2.png", "Wilds-LBG-2.png",
];
const weaponMaterialParts = [
  ["Blade", "Blade", "Tube"], ["Blade", "Tube", "Disc"],
  ["Blade", "Blade", "Disc"], ["Blade", "Tube", "Tube"],
  ["Disc", "Disc", "Tube"], ["Disc", "Device", "Device"],
  ["Blade", "Disc", "Disc"], ["Disc", "Disc", "Device"],
  ["Blade", "Blade", "Device"], ["Blade", "Disc", "Device"],
  ["Blade", "Tube", "Device"], ["Tube", "Tube", "Device"],
  ["Disc", "Tube", "Device"], ["Tube", "Device", "Device"],
];
const attributeNames = ["None", "Fire", "Water", "Thunder", "Ice", "Dragon", "Poison", "Paralysis", "Sleep", "Blast"];
const attributeIconFiles = {
  2: "MHWilds-Fireblight_Icon.png",
  3: "MHWilds-Waterblight_Icon.png",
  4: "MHWilds-Thunderblight_Icon.png",
  5: "MHWilds-Iceblight_Icon.png",
  6: "MHWilds-Dragonblight_Icon.png",
  7: "MHWilds-Poison_Icon.png",
  8: "MHWilds-Paralysis_Icon.png",
  9: "MHWilds-Sleep_Icon.png",
  10: "MHWilds-Blastblight_Icon.png",
};
const infusionNames = ["Attack Infusion", "Affinity Infusion"];
const artianSetOrder = [
  "Doshaguma's Might", "Rathalos's Flare", "Xu Wu's Vigor", "Gravios's Protection",
  "Blangonga's Spirit", "Ebony Odogaron's Power", "Fulgur Anjanath's Will",
  "Uth Duna's Cover", "Rey Dau's Voltage", "Nu Udra's Mutiny",
  "Jin Dahaad's Revolt", "Gore Magala's Tyranny", "Arkveld's Hunger",
  "Guardian Arkveld's Vitality", "Mizutsune's Prowess", "Zoh Shia's Pulse",
  "Leviathan's Fury", "Seregios's Tenacity", "Gogmapocalypse",
  "Soul of the Dark Knight", "Omega Resonance",
];
const artianGroupOrder = [
  "Neopteron Alert", "Neopteron Camouflage", "Flexible Leathercraft",
  "Buttery Leathercraft", "Scaling Prowess", "Scale Layering", "Fortifying Pelt",
  "Alluring Pelt", "Lord's Favor", "Lord's Fury", "Guardian's Pulse",
  "Guardian's Protection", "Imparted Wisdom", "Lord's Soul",
];
const baseNames = {4: "Element Boost I", 6: "Attack Boost I", 7: "Sharpness Boost", 8: "Affinity Boost I"};
const baseSelectorIds = [6, 8, 4, 7];
const gogmaBonusIds = [8, 12, 15, 9, 13, 16, 11, 14, 6, 10];
const gogmaNames = {
  6: "Sharpness Boost", 8: "Attack Boost II", 9: "Affinity Boost II",
  10: "Sharpness/Ammo Boost EX", 11: "Element Boost II", 12: "Attack Boost III",
  13: "Affinity Boost III", 14: "Element Boost EX", 15: "Attack Boost EX",
  16: "Affinity Boost EX",
};
const reinforcementNames = [
  "Attack Boost I", "Affinity Boost I", "Element Boost I", "Sharpness Boost",
  "Attack Boost II", "Affinity Boost II", "Element Boost II",
  "Attack Boost III", "Affinity Boost III", "Attack Boost EX",
  "Affinity Boost EX", "Element Boost EX", "Sharpness/Ammo Boost EX",
];
const reinforcementBaseIds = [6, 8, 4, 7];
const reinforcementGogmaIds = {4: 6, 5: 8, 6: 9, 7: 11, 8: 12, 9: 13, 10: 15, 11: 16, 12: 14, 13: 10};
const materialIconFiles = {
  Blade: "MHWilds-Relic_Blade_Icon_Rare_8.png",
  Tube: "MHWilds-Relic_Tube_Icon_Rare_8.png",
  Disc: "MHWilds-Relic_Disc_Icon_Rare_8.png",
  Device: "MHWilds-Relic_Device_Icon_Rare_8.png",
};

function u32(value) { return value >>> 0; }
function rngStep(r) {
  const t = u32(r.x ^ u32(r.x << 15));
  const nextW = u32(r.w ^ (r.w >>> 21) ^ t ^ (t >>> 4));
  return {x: r.y, y: r.z, z: r.w, w: nextW};
}
function initializeRng(seed) {
  let seedState = u32(seed);
  let r = {x: 0x159a55e5, y: 0x1f123bb5, z: 0x05491333, w: 0x05491333};
  for (let iteration = 1; iteration <= 100; iteration++) {
    const mixed = u32((0x65ac9365 >>> (seedState & 3)) ^ seedState);
    seedState = u32(u32(mixed << 4) ^ u32(mixed << 3) ^ (mixed >>> 3) ^ (mixed >>> 4) ^ mixed);
    const t = u32(seedState ^ u32(seedState << 15));
    const nextW = u32(r.z ^ (r.z >>> 21) ^ t ^ (t >>> 4));
    r = {x: r.x, y: r.y, z: r.z, w: nextW};
    if (iteration < 100) r = {x: r.y, y: r.z, z: r.w, w: r.w};
  }
  return r;
}
function advance(r, steps) {
  for (let i = 0; i < steps; i++) r = rngStep(r);
  return r;
}
function sameMultiset(a, b) {
  if (!a || !b || a.length !== b.length) return false;
  const counts = new Map();
  for (const x of a) counts.set(x, (counts.get(x) || 0) + 1);
  for (const x of b) counts.set(x, (counts.get(x) || 0) - 1);
  return [...counts.values()].every((x) => x === 0);
}
function sameGogmaFamilies(a, b) {
  if (a.length !== b.length) return false;
  const counts = new Map();
  for (const id of a) counts.set(familyId(id), (counts.get(familyId(id)) || 0) + 1);
  for (const id of b) counts.set(familyId(id), (counts.get(familyId(id)) || 0) - 1);
  return [...counts.values()].every((count) => count === 0);
}
function skillType(setName, groupName) {
  return `${setName}||${groupName}`;
}
function skillFromIndex(index) {
  const setName = artianSetOrder[Math.floor(index / artianGroupOrder.length)];
  const groupName = artianGroupOrder[index % artianGroupOrder.length];
  return {setName, groupName, key: skillType(setName, groupName)};
}
function predictSkillRoute(capture, desiredKey) {
  let r = initializeRng(u32(capture.weaponType * 1000 + capture.attribute + capture.baseSeed) ^ 0x00ac9365);
  r = advance(r, capture.counterGate < 0x36 ? 0 : capture.skillCounter * 10);
  r = rngStep(r);
  const initial = skillFromIndex(r.w % 294);
  for (let rerolls = 1; rerolls <= 5000; rerolls++) {
    if (!(capture.counterIsNext && rerolls === 1)) r = advance(r, 10);
    if (skillFromIndex(r.w % 294).key === desiredKey) return {initial, distance: rerolls};
  }
  return {initial, distance: null};
}
function deriveMaterialRecipe(attrs) {
  const counts = new Map();
  for (const attr of attrs) if (attr > 1) counts.set(attr, (counts.get(attr) || 0) + 1);
  let finalAttribute = 1;
  let matching = 0;
  for (const [attr, count] of counts.entries()) {
    if (count > matching) { finalAttribute = attr; matching = count; }
  }
  if (matching < 2) finalAttribute = 1;
  return {finalAttribute, hasElementInfusion: matching === 3};
}
function skillAttributeForce(attribute) {
  return [0, 0, 1, 2, 4, 3, 5, 6, 7, 8, 9][attribute];
}
function configuredBasePool(finalAttribute) {
  const order = finalAttribute === 1 ? [6, 7, 8] : [6, 4, 7, 8];
  const limits = {4: 5, 6: 5, 7: 2, 8: 5};
  return order.map((id) => ({id, count: 0, max: limits[id]}));
}
function clonePool(pool) { return pool.map((x) => ({...x})); }
function drawBase(r, poolSource) {
  const pool = clonePool(poolSource);
  const bonuses = [];
  let packed = 0;
  let mult = 1;
  for (let slot = 0; slot < 5; slot++) {
    r = rngStep(r);
    const index = r.w % pool.length;
    const entry = pool[index];
    bonuses.push(entry.id);
    packed += entry.id * mult;
    mult *= 1000;
    entry.count++;
    if (entry.count >= entry.max) pool.splice(index, 1);
  }
  return {r, packed, bonuses};
}
function unpackGogma(packed) {
  const ids = [];
  for (let i = 0; i < 5; i++) {
    ids.push((packed % 1000) - 1);
    packed = Math.floor(packed / 1000);
  }
  return ids;
}
function repeatPenalty(id) { return [10, 14, 15, 16].includes(id) ? 80 : 50; }
function keepFamily(id) {
  if ([8, 12, 15].includes(id)) return [8, 12, 15];
  if ([9, 13, 16].includes(id)) return [9, 13, 16];
  if ([11, 14].includes(id)) return [11, 14];
  if ([6, 10].includes(id)) return [6, 10];
  return [];
}
function familyId(id) {
  if ([8, 12, 15].includes(id)) return 1;
  if ([9, 13, 16].includes(id)) return 2;
  if ([11, 14].includes(id)) return 3;
  if ([6, 10].includes(id)) return 4;
  return 0;
}
function familyLayout(packed) {
  let layout = 0, mult = 1;
  for (const id of unpackGogma(packed)) { layout += familyId(id) * mult; mult *= 5; }
  return layout;
}
function buildGogmaPool(mode, currentId, selected) {
  const candidates = mode === 1 ? keepFamily(currentId) : gogmaBonusIds;
  return candidates.map((id) => {
    const count = selected.filter((x) => x === id).length;
    return {id, weight: Math.max(0, 100 - count * repeatPenalty(id))};
  }).filter((x) => x.weight > 0);
}
function simulateGogma(r, packed, mode) {
  const current = unpackGogma(packed);
  const selected = [];
  let result = 0, mult = 1;
  for (let slot = 0; slot < 5; slot++) {
    const pool = buildGogmaPool(mode, current[slot], selected);
    if (pool.length === 0) return null;
    r = rngStep(r);
    const total = pool.reduce((sum, x) => sum + x.weight, 0);
    let roll = r.w % total;
    let chosen = pool[0].id;
    for (const entry of pool) {
      if (roll < entry.weight) { chosen = entry.id; break; }
      roll -= entry.weight;
    }
    selected.push(chosen);
    result += (chosen + 1) * mult;
    mult *= 1000;
  }
  return {packed: result, ids: selected};
}
function initializeGogma(capture) {
  let r = initializeRng(u32(capture.baseSeed + capture.weaponType * 1000 + capture.attribute) ^ 0x00ac9365);
  return advance(r, capture.counterGate < 0x23 ? 0 : capture.gogmaCounter * 10);
}
function findGogmaRoute(capture, currentValue, target, limit, forceInitialReset = false) {
  let r = initializeGogma(capture);
  let states = forceInitialReset ? [] : [{packed: currentValue, lastReset: null}];
  for (let distance = 1; distance <= limit; distance++) {
    const next = [];
    const seen = new Set();
    const reset = simulateGogma({...r}, currentValue, 0);
    if (!reset) return null;
    if (sameMultiset(reset.ids, target)) return {distance, value: reset.packed, resets: distance, keeps: 0};
    seen.add(familyLayout(reset.packed));
    next.push({packed: reset.packed, lastReset: distance});
    for (const state of states) {
      const keep = simulateGogma({...r}, state.packed, 1);
      if (!keep) continue;
      if (sameMultiset(keep.ids, target)) {
        const resets = state.lastReset || 0;
        return {distance, value: keep.packed, resets, keeps: state.lastReset == null ? distance : distance - state.lastReset};
      }
      const layout = familyLayout(keep.packed);
      if (!seen.has(layout)) {
        seen.add(layout);
        next.push({packed: keep.packed, lastReset: state.lastReset});
      }
    }
    states = next;
    r = advance(r, 10);
  }
  return null;
}
function findKeepGogmaRoute(capture, currentValue, target, limit) {
  let r = initializeGogma(capture);
  let packed = currentValue;
  for (let distance = 1; distance <= limit; distance++) {
    const next = simulateGogma({...r}, packed, 1);
    if (!next) return null;
    if (sameMultiset(next.ids, target)) return {distance, value: next.packed, resets: 0, keeps: distance};
    packed = next.packed;
    r = advance(r, 10);
  }
  return null;
}
function namesForPackedBase(packed) {
  const names = [];
  for (let i = 0; i < 5; i++) {
    const id = packed % 1000;
    names.push(baseNames[id] || `Bonus ${id}`);
    packed = Math.floor(packed / 1000);
  }
  return names.join(" | ");
}
function namesForPackedGogma(packed) {
  return unpackGogma(packed).map((id) => gogmaNames[id] || `Bonus ${id + 1}`).join(" | ");
}
function packGogmaIds(ids) {
  return ids.reduce((packed, id, index) => packed + (id + 1) * (1000 ** index), 0);
}
function namesForCurrentReinforcements(values) {
  const packed = values.currentReinforcementTier === "gogma"
    ? packGogmaIds(values.currentReinforcements)
    : values.currentReinforcements.reduce((total, id, index) => total + id * (1000 ** index), 0);
  return values.currentReinforcementTier === "gogma" ? namesForPackedGogma(packed) : namesForPackedBase(packed);
}
function nameForSkillIndex(index) {
  const skill = skillFromIndex(index);
  return `${skill.setName} / ${skill.groupName}`;
}
function selectedGogmaTarget(indices) {
  return indices.map((index) => reinforcementGogmaIds[index]).filter(Boolean);
}
function selectedBaseTarget(indices) {
  return indices.map((index) => reinforcementBaseIds[index - 1]).filter(Boolean);
}
function reinforcementTargetMode(indices) {
  const hasBaseTier = indices.some((index) => index <= 3);
  const hasGogmaTier = indices.some((index) => index >= 5);
  if (hasBaseTier && hasGogmaTier) {
    throw new Error("Base I bonuses cannot be mixed with Gogma II/III/EX bonuses.");
  }
  return hasGogmaTier ? "gogma" : "base";
}
function calculate(values) {
  const recipe = deriveMaterialRecipe(values.materialAttributes);
  const pool = configuredBasePool(recipe.finalAttribute);
  const targetMode = reinforcementTargetMode(values.desiredReinforcements);
  const useGogma = values.includeReinforcements && targetMode === "gogma";
  const includeBase = values.includeReinforcements && !useGogma;
  const includeGogma = values.includeReinforcements && useGogma;
  const desiredKey = skillType(setSkillNames[values.desiredSetSkill - 1], groupSkillNames[values.desiredGroupSkill - 1]);
  let skillResets = 0;
  let initialSkill = null;
  if (values.includeSkills) {
    const skill = predictSkillRoute({...values, attribute: skillAttributeForce(recipe.finalAttribute)}, desiredKey);
    initialSkill = skill.initial;
    if (skill.initial.key !== desiredKey) {
      if (skill.distance == null) throw new Error("Skill target not found within 5000 resets.");
      skillResets = skill.distance;
    }
  }
  let r = initializeRng(u32(values.baseSeed + values.weaponType * 1000 + values.rarity) ^ 0x00ac9365);
  r = advance(r, values.createCount * 10);
  const baseTarget = selectedBaseTarget(values.desiredReinforcements);
  const gogmaTarget = selectedGogmaTarget(values.desiredReinforcements);
  let best = null;
  const cache = new Map();
  for (let offset = 0; offset < 5000; offset++) {
    const drawn = drawBase(r, pool);
    r = drawn.r;
    const forgeCount = offset + 1;
    let eligible = !includeBase || sameMultiset(drawn.bonuses, baseTarget);
    let amendments = 0, resets = 0, keeps = 0, result = drawn.packed;
    if (eligible && includeGogma && !sameMultiset(unpackGogma(drawn.packed), gogmaTarget)) {
      const routeKey = familyLayout(drawn.packed);
      if (!cache.has(routeKey)) {
        const remaining = best ? Math.max(0, best.total - forgeCount - skillResets - 1) : 5000;
        cache.set(routeKey, findGogmaRoute({...values, attribute: skillAttributeForce(recipe.finalAttribute)}, drawn.packed, gogmaTarget, remaining));
      }
      const route = cache.get(routeKey);
      if (!route) eligible = false;
      else {
        amendments = route.distance; resets = route.resets; keeps = route.keeps; result = route.value;
      }
    }
    if (eligible) {
      const total = forgeCount + skillResets + amendments;
      if (!best || total < best.total) best = {total, forgeCount, baseValue: drawn.packed, amendments, resets, keeps, gogmaValue: result};
    }
    if (best && forgeCount >= best.total) break;
    r = advance(r, 5);
  }
  if (!best) throw new Error("No route found within 5000 target-type forges.");
  return {recipe, best, skillResets, initialSkill, includeGogma, includeBase};
}

function calculateExisting(values) {
  const targetMode = reinforcementTargetMode(values.desiredReinforcements);
  const desiredKey = skillType(setSkillNames[values.desiredSetSkill - 1], groupSkillNames[values.desiredGroupSkill - 1]);
  const currentKey = skillType(setSkillNames[values.currentSetSkill - 1], groupSkillNames[values.currentGroupSkill - 1]);
  const attribute = values.attributeForce != null
    ? values.attributeForce
    : skillAttributeForce(values.existingAttribute);
  let skillResets = 0;
  let reinforcementRoute = null;
  let total = 0;

  if (values.includeSkills && currentKey !== desiredKey) {
    const route = predictSkillRoute({...values, attribute, counterIsNext: true}, desiredKey);
    if (route.distance == null) throw new Error("Skill target not found within 5000 resets.");
    skillResets = route.distance;
    total += skillResets;
  }
  if (values.includeReinforcements) {
    if (targetMode !== "gogma") {
      throw new Error("Existing weapon amendments require a Gogma-tier reinforcement target.");
    }
    const hasGogmaBonuses = values.currentReinforcementTier === "gogma";
    const currentValue = hasGogmaBonuses
      ? packGogmaIds(values.currentReinforcements)
      : values.currentReinforcements.reduce((packed, id, index) => packed + id * (1000 ** index), 0);
    const target = selectedGogmaTarget(values.desiredReinforcements);
    if (hasGogmaBonuses && sameMultiset(unpackGogma(currentValue), target)) {
      reinforcementRoute = {distance: 0, resets: 0, keeps: 0, value: currentValue};
    } else {
      const currentIds = hasGogmaBonuses ? unpackGogma(currentValue) : [];
      reinforcementRoute = hasGogmaBonuses && sameGogmaFamilies(currentIds, target)
        ? findKeepGogmaRoute({...values, attribute}, currentValue, target, 5000)
        : null;
      if (!reinforcementRoute) reinforcementRoute = findGogmaRoute(
        {...values, attribute}, currentValue, target, 5000, !hasGogmaBonuses,
      );
      if (!reinforcementRoute) throw new Error("Reinforcement target not found within 5000 amendments.");
    }
    total += reinforcementRoute.distance;
  }
  return {attribute, skillResets, reinforcementRoute, total, currentKey};
}

function csvCell(value) {
  return `"${String(value ?? "").replaceAll("\"", "\"\"")}"`;
}
function downloadText(filename, text, mimeType) {
  const blob = new Blob([text], {type: mimeType});
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.append(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}
function selectedTargetText(indices) {
  return indices.map((index) => reinforcementNames[index - 1] || `Bonus ${index}`).join(" | ");
}
function skillResetDeviceCost(values) {
  return COSTS.skillResetDevices;
}
function fullPlanCosts(result, values = getValues()) {
  const amendments = result.best.resets + result.best.keeps;
  const reachesGogma = values.includeSkills || result.includeGogma;
  const basePoints = COSTS.baseLevels * COSTS.basePointsPerLevel;
  const forgeZenny = result.best.forgeCount * COSTS.rarity8ForgeZenny;
  const baseZenny = COSTS.baseLevels * COSTS.baseZennyPerLevel;
  const upgradeZenny = reachesGogma ? COSTS.gogmaUpgradeZenny : 0;
  const skillPoints = result.skillResets * COSTS.skillResetPoints;
  const skillZenny = result.skillResets * COSTS.skillResetZenny;
  const amendPoints = amendments * COSTS.gogmaAmendPoints;
  const amendZenny = amendments * COSTS.gogmaAmendZenny;
  return {
    basePoints,
    skillPoints,
    amendPoints,
    totalZenny: forgeZenny + baseZenny + upgradeZenny + skillZenny + amendZenny,
    forgeParts: result.best.forgeCount * COSTS.rarity8PartsPerForge,
    upgradeDevices: (reachesGogma ? COSTS.gogmaUpgradeDevices : 0)
      + result.skillResets * skillResetDeviceCost(values),
  };
}
function existingWeaponCosts(result, values = getValues()) {
  const amendments = result.reinforcementRoute ? result.reinforcementRoute.distance : 0;
  return {
    skillPoints: result.skillResets * COSTS.skillResetPoints,
    amendPoints: amendments * COSTS.gogmaAmendPoints,
    totalZenny: result.skillResets * COSTS.skillResetZenny + amendments * COSTS.gogmaAmendZenny,
    upgradeDevices: result.skillResets * skillResetDeviceCost(values),
  };
}
function formatNumber(value) {
  return Math.floor(Number(value) || 0).toLocaleString("en-US");
}
function appendBasePredictionRows(rows, overallStep, values, result) {
  if (!result.includeBase && !result.includeGogma) return overallStep;
  let r = initializeRng(u32(values.baseSeed + values.weaponType * 1000 + values.rarity) ^ 0x00ac9365);
  r = advance(r, values.createCount * 10);
  const pool = configuredBasePool(result.recipe.finalAttribute);
  const target = selectedTargetText(values.desiredReinforcements);
  for (let step = 1; step <= result.best.forgeCount; step++) {
    const drawn = drawBase(r, pool);
    r = drawn.r;
    rows.push([
      ++overallStep, step, "Base Artian reinforcements",
      step === result.best.forgeCount ? "Forge and keep" : "Forge and discard",
      namesForPackedBase(drawn.packed), target, 0, COSTS.rarity8ForgeZenny, 0,
      COSTS.rarity8PartsPerForge, 0,
    ]);
    r = advance(r, 5);
  }
  return overallStep;
}
function appendSkillPredictionRows(rows, overallStep, values, result) {
  if (!values.includeSkills || result.skillResets <= 0) return overallStep;
  let r = initializeRng(u32(values.weaponType * 1000 + skillAttributeForce(result.recipe.finalAttribute) + values.baseSeed) ^ 0x00ac9365);
  r = advance(r, values.counterGate < 0x36 ? 0 : values.skillCounter * 10);
  r = rngStep(r);
  const target = `${setSkillNames[values.desiredSetSkill - 1]} / ${groupSkillNames[values.desiredGroupSkill - 1]}`;
  for (let step = 1; step <= result.skillResets; step++) {
    r = advance(r, 10);
    rows.push([
      ++overallStep, step, "Gogma set and group skills", "Reset skills",
      nameForSkillIndex(r.w % 294), target, 0, COSTS.skillResetZenny,
      COSTS.skillResetPoints, 0, skillResetDeviceCost(values),
    ]);
  }
  return overallStep;
}
function appendGogmaPredictionRows(rows, overallStep, values, result) {
  const distance = result.best.resets + result.best.keeps;
  if (!result.includeGogma || distance <= 0) return overallStep;
  let r = initializeGogma({...values, attribute: skillAttributeForce(result.recipe.finalAttribute)});
  let packed = result.best.baseValue;
  const target = selectedTargetText(values.desiredReinforcements);
  for (let step = 1; step <= distance; step++) {
    const mode = step <= result.best.resets ? 0 : 1;
    const next = simulateGogma({...r}, packed, mode);
    if (!next) break;
    packed = next.packed;
    rows.push([
      ++overallStep, step, "Gogma reinforcements",
      mode === 0 ? "Amend (Reset Bonuses)" : "Amend (Keep Bonuses)",
      namesForPackedGogma(packed), target, 0, COSTS.gogmaAmendZenny,
      COSTS.gogmaAmendPoints, 0, 0,
    ]);
    r = advance(r, 10);
  }
  return overallStep;
}
function appendExistingSkillPredictionRows(rows, overallStep, values, result) {
  if (!values.includeSkills || result.skillResets <= 0) return overallStep;
  let r = initializeRng(u32(values.weaponType * 1000 + result.attribute + values.baseSeed) ^ 0x00ac9365);
  r = advance(r, values.counterGate < 0x36 ? 0 : values.skillCounter * 10);
  r = rngStep(r);
  const target = `${setSkillNames[values.desiredSetSkill - 1]} / ${groupSkillNames[values.desiredGroupSkill - 1]}`;
  for (let step = 1; step <= result.skillResets; step++) {
    if (step > 1) r = advance(r, 10);
    rows.push([
      ++overallStep, step, "Gogma set and group skills", "Reset skills",
      nameForSkillIndex(r.w % 294), target, 0, COSTS.skillResetZenny,
      COSTS.skillResetPoints, 0, skillResetDeviceCost(values),
    ]);
  }
  return overallStep;
}
function appendExistingGogmaPredictionRows(rows, overallStep, values, result) {
  const route = result.reinforcementRoute;
  if (!values.includeReinforcements || !route || route.distance <= 0) return overallStep;
  let r = initializeGogma({...values, attribute: result.attribute});
  let packed = values.currentReinforcementTier === "gogma"
    ? packGogmaIds(values.currentReinforcements)
    : values.currentReinforcements.reduce((total, id, index) => total + id * (1000 ** index), 0);
  const target = selectedTargetText(values.desiredReinforcements);
  for (let step = 1; step <= route.distance; step++) {
    const mode = step <= route.resets ? 0 : 1;
    const next = simulateGogma({...r}, packed, mode);
    if (!next) break;
    packed = next.packed;
    rows.push([
      ++overallStep, step, "Gogma reinforcements",
      mode === 0 ? "Amend (Reset Bonuses)" : "Amend (Keep Bonuses)",
      namesForPackedGogma(packed), target, 0, COSTS.gogmaAmendZenny,
      COSTS.gogmaAmendPoints, 0, 0,
    ]);
    r = advance(r, 10);
  }
  return overallStep;
}
function exportCsv() {
  const out = document.getElementById("result");
  if (!lastCalculation) {
    out.textContent = "Calculate a plan before exporting CSV.";
    return;
  }
  const {mode, values, result} = lastCalculation;
  const rows = [[
    "Row", "Stage step", "Stage", "Action", "Predicted result", "Target",
    "Base reinforcement points", "Zenny", "Gogma material points",
    "Rarity-8 Artian parts", "Tarred Devices (matching focus)",
  ]];
  let overallStep = 0;
  let costs;
  if (mode === "existing") {
    rows.push([
      ++overallStep, "", "Existing weapon", "Current state",
      `${setSkillNames[values.currentSetSkill - 1]} / ${groupSkillNames[values.currentGroupSkill - 1]} | ${namesForCurrentReinforcements(values)}`,
      "", 0, 0, 0, 0, 0,
    ]);
    overallStep = appendExistingSkillPredictionRows(rows, overallStep, values, result);
    overallStep = appendExistingGogmaPredictionRows(rows, overallStep, values, result);
    costs = existingWeaponCosts(result, values);
  } else {
    overallStep = appendBasePredictionRows(rows, overallStep, values, result);
    overallStep = appendSkillPredictionRows(rows, overallStep, values, result);
    overallStep = appendGogmaPredictionRows(rows, overallStep, values, result);
    costs = fullPlanCosts(result, values);
  }
  rows.push([
    ++overallStep, "", mode === "existing" ? "Existing weapon plan" : "New weapon plan", "Estimated totals", "Complete known costs",
    "", costs.basePoints || 0, costs.totalZenny, costs.amendPoints,
    costs.forgeParts || 0, costs.upgradeDevices || 0,
  ]);
  downloadText(
    "GogmaArtianRollPlannerPredictions.csv",
    rows.map((row) => row.map(csvCell).join(",")).join("\n") + "\n",
    "text/csv;charset=utf-8",
  );
}

function option(select, label, value) {
  const opt = document.createElement("option");
  opt.textContent = label;
  opt.value = value;
  select.append(opt);
}
function fillSelect(id, names, base = 0) {
  const select = document.getElementById(id);
  names.forEach((name, i) => option(select, name, i + base));
}
function buildMaterials() {
  const wrap = document.getElementById("materials");
  wrap.innerHTML = "";
  const weapon = Number(document.getElementById("weaponType").value);
  weaponMaterialParts[weapon].forEach((part, i) => {
    const box = document.createElement("div");
    box.className = "material-card";
    box.innerHTML = `<div class="card-title"><img class="part-icon-img" src="img/${materialIconFiles[part]}" alt="">${part}</div><label><span class="field-label"><img id="matAttrIcon${i}" class="field-icon-img" alt="">Element</span><select id="matAttr${i}"></select></label><label><span class="field-label"><img class="field-icon-img" src="img/MHWilds-Sword_Skill_Item_Icon.png" alt="">Bonus</span><select id="matInf${i}"></select></label>`;
    wrap.append(box);
    fillSelect(`matAttr${i}`, attributeNames, 1);
    fillSelect(`matInf${i}`, infusionNames, 1);
    document.getElementById(`matAttr${i}`).addEventListener("change", () => updateAttributeIcon(i));
    updateAttributeIcon(i);
  });
}
function updateAttributeIcon(index) {
  const select = document.getElementById(`matAttr${index}`);
  const icon = document.getElementById(`matAttrIcon${index}`);
  if (!select || !icon) return;
  const file = attributeIconFiles[Number(select.value)];
  icon.src = file ? `img/${file}` : "";
  icon.classList.toggle("is-empty", !file);
  icon.alt = file ? `${attributeNames[Number(select.value) - 1]} icon` : "";
}
function updateWeaponIcon() {
  const weapon = Number(document.getElementById("weaponType").value);
  const icon = document.getElementById("weaponIcon");
  if (!icon) return;
  icon.src = `img/${weaponIconFiles[weapon]}`;
  icon.alt = `${weaponTypeNames[weapon]} icon`;
}
function buildReinforcements() {
  const wrap = document.getElementById("reinforcements");
  for (let i = 0; i < 5; i++) {
    const label = document.createElement("label");
    label.className = "reinforcement";
    label.innerHTML = `<span class="field-label"><span class="mini-icon" aria-hidden="true">B${i + 1}</span>Bonus ${i + 1}</span>`;
    const select = document.createElement("select");
    select.id = `reinforcement${i}`;
    reinforcementNames.forEach((name, index) => option(select, name, index + 1));
    label.append(select);
    wrap.append(label);
  }
}
function buildCurrentReinforcements(tier = "gogma", values = []) {
  const wrap = document.getElementById("currentReinforcements");
  const currentIds = tier === "gogma" ? [6, 8, 9, 10, 11, 12, 13, 14, 15, 16] : [4, 6, 7, 8];
  const names = tier === "gogma" ? gogmaNames : baseNames;
  currentExistingReinforcementTier = tier;
  wrap.innerHTML = "";
  for (let i = 0; i < 5; i++) {
    const label = document.createElement("label");
    label.className = "reinforcement";
    label.innerHTML = `<span class="field-label"><span class="mini-icon" aria-hidden="true">B${i + 1}</span>Current bonus ${i + 1}</span>`;
    const select = document.createElement("select");
    select.id = `currentReinforcement${i}`;
    currentIds.forEach((id) => option(select, names[id], id));
    if (values[i] != null) select.value = values[i];
    label.append(select);
    wrap.append(label);
  }
}
function existingWeaponLabel(weapon, index) {
  const values = {...weapon, currentReinforcementTier: weapon.currentReinforcementTier || "gogma"};
  return `#${index + 1} ${weaponTypeNames[weapon.weaponType] || "Weapon"} / ${attributeNames[weapon.existingAttribute - 1] || "Attribute"} / ${setSkillNames[weapon.currentSetSkill - 1]} / ${groupSkillNames[weapon.currentGroupSkill - 1]} / ${namesForCurrentReinforcements(values)}`;
}
function setExistingWeaponCatalog(weapons, selectedIndex) {
  importedExistingWeapons = Array.isArray(weapons) ? weapons : [];
  const field = document.getElementById("existingWeaponCatalogField");
  const select = document.getElementById("existingWeaponCatalog");
  select.innerHTML = "";
  importedExistingWeapons.forEach((weapon, index) => option(select, existingWeaponLabel(weapon, index), index));
  field.hidden = importedExistingWeapons.length === 0;
  if (importedExistingWeapons.length > 0) {
    select.value = Math.min(Math.max(Number(selectedIndex) || 0, 0), importedExistingWeapons.length - 1);
  }
}
function applyExistingWeapon(weapon) {
  if (!weapon) return;
  document.getElementById("weaponType").value = weapon.weaponType;
  updateWeaponIcon();
  document.getElementById("existingAttribute").value = weapon.existingAttribute;
  currentExistingAttributeForce = weapon.attributeForce != null ? Number(weapon.attributeForce) : null;
  document.getElementById("currentSetSkill").value = weapon.currentSetSkill;
  document.getElementById("currentGroupSkill").value = weapon.currentGroupSkill;
  buildCurrentReinforcements(weapon.currentReinforcementTier || "gogma", weapon.currentReinforcements || []);
}
function getValues() {
  return {
    planMode: document.querySelector('input[name="planMode"]:checked').value,
    baseSeed: Number(document.getElementById("baseSeed").value),
    skillCounter: Number(document.getElementById("skillCounter").value),
    gogmaCounter: Number(document.getElementById("gogmaCounter").value),
    counterGate: Number(document.getElementById("counterGate").value),
    createCount: Number(document.getElementById("createCount").value),
    weaponType: Number(document.getElementById("weaponType").value),
    rarity: 7,
    materialAttributes: [0, 1, 2].map((i) => Number(document.getElementById(`matAttr${i}`).value)),
    materialInfusions: [0, 1, 2].map((i) => Number(document.getElementById(`matInf${i}`).value)),
    desiredReinforcements: [0, 1, 2, 3, 4].map((i) => Number(document.getElementById(`reinforcement${i}`).value)),
    desiredSetSkill: Number(document.getElementById("desiredSetSkill").value),
    desiredGroupSkill: Number(document.getElementById("desiredGroupSkill").value),
    includeSkills: document.getElementById("includeSkills").checked,
    includeReinforcements: document.getElementById("includeReinforcements").checked,
    existingAttribute: Number(document.getElementById("existingAttribute").value),
    attributeForce: currentExistingAttributeForce,
    currentSetSkill: Number(document.getElementById("currentSetSkill").value),
    currentGroupSkill: Number(document.getElementById("currentGroupSkill").value),
    currentReinforcements: [0, 1, 2, 3, 4].map((i) => Number(document.getElementById(`currentReinforcement${i}`).value)),
    currentReinforcementTier: currentExistingReinforcementTier,
  };
}
function setValues(v) {
  for (const key of ["baseSeed", "skillCounter", "gogmaCounter", "counterGate", "createCount"]) {
    if (v[key] != null) document.getElementById(key).value = v[key];
  }
  if (v.weaponType != null) document.getElementById("weaponType").value = v.weaponType;
  buildMaterials();
  updateWeaponIcon();
  (v.materialAttributes || [4, 4, 4]).forEach((x, i) => document.getElementById(`matAttr${i}`).value = x);
  [0, 1, 2].forEach(updateAttributeIcon);
  (v.materialInfusions || [1, 1, 1]).forEach((x, i) => document.getElementById(`matInf${i}`).value = x);
  (v.desiredReinforcements || [10, 10, 8, 13, 11]).forEach((x, i) => document.getElementById(`reinforcement${i}`).value = x);
  if (v.desiredSetSkill != null) document.getElementById("desiredSetSkill").value = v.desiredSetSkill;
  if (v.desiredGroupSkill != null) document.getElementById("desiredGroupSkill").value = v.desiredGroupSkill;
  if (v.includeSkills != null) document.getElementById("includeSkills").checked = Boolean(v.includeSkills);
  if (v.includeReinforcements != null) document.getElementById("includeReinforcements").checked = Boolean(v.includeReinforcements);
  if (v.existingAttribute != null) document.getElementById("existingAttribute").value = v.existingAttribute;
  currentExistingAttributeForce = v.attributeForce != null ? Number(v.attributeForce) : null;
  if (v.currentSetSkill != null) document.getElementById("currentSetSkill").value = v.currentSetSkill;
  if (v.currentGroupSkill != null) document.getElementById("currentGroupSkill").value = v.currentGroupSkill;
  buildCurrentReinforcements(v.currentReinforcementTier || "gogma", v.currentReinforcements || [15, 15, 12, 16, 10]);
  if (Array.isArray(v.existingWeapons)) {
    setExistingWeaponCatalog(v.existingWeapons, v.selectedExistingWeapon);
  } else if (v.planMode === "new") {
    setExistingWeaponCatalog([], 0);
  }
  if (v.planMode) {
    const radio = document.querySelector(`input[name="planMode"][value="${v.planMode}"]`);
    if (radio) radio.checked = true;
  }
  updatePlanMode();
  if (Array.isArray(v.existingWeapons) && importedExistingWeapons.length > 0) {
    applyExistingWeapon(importedExistingWeapons[Number(document.getElementById("existingWeaponCatalog").value)]);
  }
}
function setImportStatus(message, tone = "") {
  const status = document.getElementById("importStatus");
  status.textContent = message;
  status.className = `import-status ${tone}`.trim();
}
function importJsonText(text, source = "values") {
  try {
    const values = JSON.parse(text);
    setValues(values);
    document.getElementById("importText").value = JSON.stringify(values, null, 2);
    setImportStatus(`Imported ${source}.`, "ok");
  } catch (err) {
    setImportStatus(`Could not import ${source}: ${err.message}`, "bad");
  }
}
function importFile(file) {
  if (!file) return;
  if (!file.name.toLowerCase().endsWith(".json") && file.type !== "application/json") {
    setImportStatus(`Skipped ${file.name}: expected a JSON file.`, "bad");
    return;
  }
  const reader = new FileReader();
  reader.addEventListener("load", () => importJsonText(String(reader.result || ""), file.name));
  reader.addEventListener("error", () => setImportStatus(`Could not read ${file.name}.`, "bad"));
  reader.readAsText(file);
}
function firstJsonFile(fileList) {
  return Array.from(fileList || []).find((file) => file.name.toLowerCase().endsWith(".json") || file.type === "application/json");
}
function renderResult() {
  const out = document.getElementById("result");
  try {
    const values = getValues();
    const result = values.planMode === "existing" ? calculateExisting(values) : calculate(values);
    lastCalculation = {mode: values.planMode, values, result};
    const lines = [];
    if (values.planMode === "existing") {
      lines.push(`Current weapon: ${attributeNames[values.existingAttribute - 1]} ${weaponTypeNames[values.weaponType]}`);
      lines.push(`Current skills: ${setSkillNames[values.currentSetSkill - 1]} / ${groupSkillNames[values.currentGroupSkill - 1]}`);
      lines.push(`Current reinforcements: ${namesForCurrentReinforcements(values)}`);
      if (values.includeSkills) {
        lines.push(result.skillResets > 0 ? `Reset Skills ${result.skillResets} time(s).` : "Current skills already match the target.");
      }
      if (values.includeReinforcements) {
        const route = result.reinforcementRoute;
        if (route.resets > 0) lines.push(`Amend (Reset Bonuses) ${route.resets} time(s).`);
        if (route.keeps > 0) lines.push(`Amend (Keep Bonuses) ${route.keeps} time(s).`);
        if (route.distance === 0) lines.push("Current reinforcements already match the target.");
        lines.push(`Gogma result: ${namesForPackedGogma(route.value)}`);
      }
      lines.push(`Planned RNG actions: ${result.total}`);
      const costs = existingWeaponCosts(result, values);
      const materialPoints = costs.amendPoints;
      lines.push(`Estimated cost: ${formatNumber(materialPoints / COSTS.oricalcitePoints)} Oricalcite (${formatNumber(materialPoints)} material points) + ${formatNumber(costs.upgradeDevices)} matching-focus Tarred Devices + ${formatNumber(costs.totalZenny)}z`);
      out.textContent = lines.join("\n");
      return;
    }
    lines.push(`Forged attribute: ${attributeNames[result.recipe.finalAttribute - 1]}${result.recipe.hasElementInfusion ? " + Element Infusion" : ""}`);
    lines.push(`Forge ${result.best.forgeCount} rarity-8 ${weaponTypeNames[getValues().weaponType]} weapon(s); keep weapon ${result.best.forgeCount}.`);
    lines.push(`Base result: ${namesForPackedBase(result.best.baseValue)}`);
    if (getValues().includeSkills) {
      lines.push(`Upgrade initial skills: ${result.initialSkill.setName} / ${result.initialSkill.groupName}`);
      lines.push(result.skillResets > 0 ? `Reset Skills ${result.skillResets} time(s).` : "Upgrade skills already match.");
    }
    if (result.includeGogma) {
      if (result.best.resets > 0) lines.push(`Amend (Reset Bonuses) ${result.best.resets} time(s).`);
      if (result.best.keeps > 0) lines.push(`Amend (Keep Bonuses) ${result.best.keeps} time(s).`);
      lines.push(`Gogma result: ${namesForPackedGogma(result.best.gogmaValue)}`);
    }
    lines.push(`Planned RNG actions: ${result.best.total}`);
    const costs = fullPlanCosts(result, values);
    const materialPoints = costs.basePoints + costs.amendPoints;
    lines.push(`Estimated material cost: ${formatNumber(costs.forgeParts)} Artian parts + ${formatNumber(materialPoints / COSTS.oricalcitePoints)} Oricalcite (${formatNumber(materialPoints)} material points) + ${formatNumber(costs.upgradeDevices)} matching-focus Tarred Devices + ${formatNumber(costs.totalZenny)}z`);
    out.textContent = lines.join("\n");
  } catch (err) {
    lastCalculation = null;
    out.textContent = err.message;
  }
}
function updatePlanMode() {
  const mode = document.querySelector('input[name="planMode"]:checked').value;
  document.getElementById("newWeaponInputs").hidden = mode !== "new";
  document.getElementById("existingWeaponInputs").hidden = mode !== "existing";
  document.getElementById("forgeCounterField").hidden = mode !== "new";
  document.getElementById("calculateButton").textContent = "Calculate plan";
  lastCalculation = null;
}
function init() {
  fillSelect("weaponType", weaponTypeNames, 0);
  fillSelect("desiredSetSkill", setSkillNames, 1);
  fillSelect("desiredGroupSkill", groupSkillNames, 1);
  fillSelect("existingAttribute", attributeNames, 1);
  fillSelect("currentSetSkill", setSkillNames, 1);
  fillSelect("currentGroupSkill", groupSkillNames, 1);
  buildMaterials();
  buildReinforcements();
  buildCurrentReinforcements();
  setValues({
    baseSeed: 8524433, skillCounter: 186, gogmaCounter: 45, counterGate: 200,
    createCount: 33, weaponType: 10, materialAttributes: [4, 4, 4],
    materialInfusions: [1, 1, 1], desiredReinforcements: [10, 10, 8, 13, 11],
    desiredSetSkill: 7, desiredGroupSkill: 10, existingAttribute: 2,
    currentSetSkill: 7, currentGroupSkill: 10, currentReinforcements: [15, 15, 12, 16, 10],
  });
  updateWeaponIcon();
  document.getElementById("weaponType").addEventListener("change", () => {
    buildMaterials();
    updateWeaponIcon();
  });
  document.querySelectorAll('input[name="planMode"]').forEach((input) => input.addEventListener("change", updatePlanMode));
  document.getElementById("existingWeaponCatalog").addEventListener("change", (event) => {
    applyExistingWeapon(importedExistingWeapons[Number(event.target.value)]);
  });
  document.getElementById("existingAttribute").addEventListener("change", () => {
    currentExistingAttributeForce = null;
  });
  document.getElementById("calculateButton").addEventListener("click", renderResult);
  document.getElementById("exportCsvButton").addEventListener("click", exportCsv);
  document.getElementById("sampleButton").addEventListener("click", () => renderResult());
  document.getElementById("importButton").addEventListener("click", () => importJsonText(document.getElementById("importText").value));
  document.getElementById("chooseFileButton").addEventListener("click", () => document.getElementById("fileInput").click());
  document.getElementById("fileInput").addEventListener("change", (event) => importFile(firstJsonFile(event.target.files)));

  const dropZone = document.getElementById("dropZone");
  for (const eventName of ["dragenter", "dragover"]) {
    dropZone.addEventListener(eventName, (event) => {
      event.preventDefault();
      dropZone.classList.add("is-dragging");
    });
  }
  for (const eventName of ["dragleave", "drop"]) {
    dropZone.addEventListener(eventName, () => dropZone.classList.remove("is-dragging"));
  }
  dropZone.addEventListener("drop", (event) => {
    event.preventDefault();
    importFile(firstJsonFile(event.dataTransfer.files));
  });
  document.addEventListener("paste", (event) => {
    const file = firstJsonFile(event.clipboardData.files);
    if (file) {
      event.preventDefault();
      importFile(file);
    }
  });
}
init();
