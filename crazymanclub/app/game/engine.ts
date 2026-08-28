// 광인회 방치형 레이드 - 게임 로직 / 밸런스 정의
// UI 와 분리해 순수 함수로만 구성한다.

export const SAVE_KEY = "cmc-idle-raid";
export const SAVE_VERSION = 1;

/** 한 스테이지에서 잡아야 하는 일반 몬스터 수. 그 다음이 보스. */
export const KILLS_PER_STAGE = 10;

/** 보스 실패 시 되돌려주는 처치 수 (다시 3마리만 잡으면 재도전). */
export const BOSS_FAIL_REFUND = 3;

/** 오프라인 보상 최대 인정 시간(초)과 효율. */
export const OFFLINE_CAP_SEC = 8 * 3600;
export const OFFLINE_RATE = 0.55;

/* ------------------------------------------------------------------ */
/* 난이도                                                              */
/* ------------------------------------------------------------------ */

export type DifficultyId = "calm" | "mad" | "insane";

export type Difficulty = {
  id: DifficultyId;
  name: string;
  tag: string;
  desc: string;
  /** 몬스터 체력 배수 */
  hpMul: number;
  /** 골드 획득 배수 */
  goldMul: number;
  /** 환생 시 광기석 배수 */
  stoneMul: number;
  /** 보스 제한시간(초) */
  bossTime: number;
};

export const DIFFICULTIES: Difficulty[] = [
  {
    id: "calm",
    name: "평온",
    tag: "입문",
    desc: "몬스터 체력 -30%, 보스 제한시간 40초. 대신 골드 -15%, 광기석 -30%.",
    hpMul: 0.7,
    goldMul: 0.85,
    stoneMul: 0.7,
    bossTime: 40,
  },
  {
    id: "mad",
    name: "광기",
    tag: "표준",
    desc: "기준 밸런스. 보스 제한시간 30초.",
    hpMul: 1,
    goldMul: 1,
    stoneMul: 1,
    bossTime: 30,
  },
  {
    id: "insane",
    name: "광인",
    tag: "도전",
    desc: "몬스터 체력 +90%, 보스 제한시간 22초. 골드 +60%, 광기석 2.2배.",
    hpMul: 1.9,
    goldMul: 1.6,
    stoneMul: 2.2,
    bossTime: 22,
  },
];

export function getDifficulty(id: DifficultyId): Difficulty {
  return DIFFICULTIES.find((d) => d.id === id) || DIFFICULTIES[1];
}

/* ------------------------------------------------------------------ */
/* 동료 (자동 공격)                                                     */
/* ------------------------------------------------------------------ */

export type Hero = {
  id: number;
  name: string;
  role: string;
  baseCost: number;
  baseDps: number;
};

/** 25 레벨마다 곱해지는 각성 배수. */
export const HERO_MILESTONE = 25;
export const HERO_MILESTONE_MUL = 2.2;

/** 레벨 1당 비용 증가율. */
export const HERO_COST_GROWTH = 1.035;

const HERO_SEED: [string, string][] = [
  ["우댕", "검사"],
  ["다올", "궁수"],
  ["해준", "사제"],
  ["삥가", "도적"],
  ["데밀", "마법사"],
  ["연준", "광전사"],
  ["건빵", "정령술사"],
  ["스팸", "흑마법사"],
  ["야수", "용기사"],
  ["MH", "대장군"],
];

export const HEROES: Hero[] = HERO_SEED.map(([name, role], i) => ({
  id: i,
  name,
  role,
  baseCost: 40 * Math.pow(11, i),
  baseDps: 2 * Math.pow(12.5, i),
}));

/** 레벨 level 인 동료의 기본 DPS (전역 배수 적용 전). */
export function heroDps(hero: Hero, level: number): number {
  if (level <= 0) return 0;
  const milestone = Math.pow(HERO_MILESTONE_MUL, Math.floor(level / HERO_MILESTONE));
  return hero.baseDps * level * milestone;
}

/** level -> level+1 로 올리는 비용. */
export function heroCost(hero: Hero, level: number): number {
  return hero.baseCost * Math.pow(HERO_COST_GROWTH, level);
}

/* ------------------------------------------------------------------ */
/* 강화                                                                */
/* ------------------------------------------------------------------ */

export type UpgradeId = "tap" | "critChance" | "critDamage" | "gold";

export type Upgrade = {
  id: UpgradeId;
  name: string;
  desc: string;
  baseCost: number;
  growth: number;
  /** 레벨 상한 (없으면 Infinity) */
  maxLevel: number;
};

export const UPGRADES: Upgrade[] = [
  {
    id: "tap",
    name: "광기의 일격",
    desc: "탭 공격력 +3",
    baseCost: 60,
    growth: 1.14,
    maxLevel: Infinity,
  },
  {
    id: "critChance",
    name: "급소 간파",
    desc: "치명타 확률 +0.6%",
    baseCost: 250,
    growth: 1.28,
    maxLevel: 100,
  },
  {
    id: "critDamage",
    name: "파멸의 각인",
    desc: "치명타 피해 +0.2배",
    baseCost: 400,
    growth: 1.24,
    maxLevel: Infinity,
  },
  {
    id: "gold",
    name: "전리품 감정",
    desc: "골드 획득 +7%",
    baseCost: 500,
    growth: 1.3,
    maxLevel: Infinity,
  },
];

export function upgradeCost(up: Upgrade, level: number): number {
  return up.baseCost * Math.pow(up.growth, level);
}

/* ------------------------------------------------------------------ */
/* 대량 구매                                                            */
/* ------------------------------------------------------------------ */

/** base*growth^level 부터 시작하는 등비수열 n 개 항의 합. */
export function bulkCost(
  base: number,
  growth: number,
  level: number,
  count: number
): number {
  const first = base * Math.pow(growth, level);
  return (first * (Math.pow(growth, count) - 1)) / (growth - 1);
}

/** gold 로 살 수 있는 최대 레벨 수 (maxLevel 상한 반영). */
export function maxAffordable(
  base: number,
  growth: number,
  level: number,
  gold: number,
  maxLevel = Infinity
): number {
  const first = base * Math.pow(growth, level);
  if (gold < first) return 0;
  const n = Math.floor(
    Math.log((gold * (growth - 1)) / first + 1) / Math.log(growth)
  );
  const room = maxLevel === Infinity ? Infinity : Math.max(0, maxLevel - level);
  return Math.max(0, Math.min(n, room));
}

/* ------------------------------------------------------------------ */
/* 몬스터 / 스테이지                                                    */
/* ------------------------------------------------------------------ */

const MOB_NAMES = [
  "광기의 늑대",
  "심연 박쥐",
  "녹빛 슬라임",
  "폐허 골렘",
  "저주받은 사냥꾼",
  "불꽃 도마뱀",
  "서리 정령",
  "그림자 도적",
];

const BOSS_NAMES = [
  "흑룡 카르낙",
  "심연군주 벨제",
  "광란의 거인",
  "폭풍의 마녀",
  "용암 파수꾼",
];

export const BOSS_HP_MUL = 8;
export const BOSS_GOLD_MUL = 12;

/*
 * 난이도 곡선.
 *
 * 체력은 스테이지마다 HP_GROWTH 배로 늘고, HP_RAMP_STAGE 부터는 여기에
 * HP_RAMP 가 추가로 곱해져 성장률 자체가 한 단계 가팔라진다. 보상은 그보다
 * 완만한 GOLD_GROWTH 로 늘기 때문에 회차를 거듭할수록 벽이 생기고, 그 벽은
 * 환생(광기석)으로만 넘을 수 있다.
 *
 * 표준 난이도 기준 시뮬레이션 결과 (탭 없이 방치만 했을 때):
 *   S10 약 3분 · S30 약 5분 · S50 약 9분 · S80 약 21분 · S100 약 56분
 *   1회차 2시간 -> 약 S108, 환생(광기석 96) 후 1시간 -> 약 S165
 */
export const HP_BASE = 9;
export const HP_GROWTH = 1.16;
export const HP_RAMP_STAGE = 25;
export const HP_RAMP = 1.04;
export const GOLD_BASE = 5;
export const GOLD_GROWTH = 1.13;

/** 스테이지별 몬스터 체력. */
export function enemyHp(stage: number, diff: Difficulty, boss: boolean): number {
  const ramp = Math.max(0, stage - HP_RAMP_STAGE);
  const base =
    HP_BASE *
    Math.pow(HP_GROWTH, stage - 1) *
    Math.pow(HP_RAMP, ramp) *
    diff.hpMul;

  return boss ? base * BOSS_HP_MUL : base;
}

/** 스테이지별 처치 보상 (강화/광기석 배수 적용 전). */
export function enemyGold(stage: number, diff: Difficulty, boss: boolean): number {
  const base = GOLD_BASE * Math.pow(GOLD_GROWTH, stage - 1) * diff.goldMul;
  return boss ? base * BOSS_GOLD_MUL : base;
}

export function enemyName(stage: number, kills: number, boss: boolean): string {
  if (boss) return BOSS_NAMES[stage % BOSS_NAMES.length];
  return MOB_NAMES[(stage * 3 + kills) % MOB_NAMES.length];
}

/* ------------------------------------------------------------------ */
/* 환생 (광기석)                                                        */
/* ------------------------------------------------------------------ */

export const PRESTIGE_MIN_STAGE = 30;

/** 지금 환생하면 얻는 광기석. */
export function stonesFor(bestStage: number, diff: Difficulty): number {
  if (bestStage < PRESTIGE_MIN_STAGE) return 0;
  return Math.floor(Math.pow((bestStage - 20) / 6, 1.7) * diff.stoneMul);
}

/** 광기석에 의한 전체 피해 배수. */
export function stoneDamageMul(stones: number): number {
  return 1 + 0.05 * stones;
}

/** 광기석에 의한 골드 배수. */
export function stoneGoldMul(stones: number): number {
  return 1 + 0.03 * stones;
}

/* ------------------------------------------------------------------ */
/* 게임 상태                                                            */
/* ------------------------------------------------------------------ */

export type GameState = {
  v: number;
  difficulty: DifficultyId;
  gold: number;
  stage: number;
  bestStage: number;
  killsInStage: number;
  enemyMaxHp: number;
  enemyHp: number;
  enemyName: string;
  isBoss: boolean;
  bossTimeLeft: number;
  heroLevels: number[];
  upgrades: Record<UpgradeId, number>;
  stones: number;
  totalStones: number;
  prestigeCount: number;
  totalKills: number;
  bossFails: number;
  lastSeen: number;
};

export function createState(difficulty: DifficultyId = "mad"): GameState {
  const diff = getDifficulty(difficulty);
  const hp = enemyHp(1, diff, false);

  return {
    v: SAVE_VERSION,
    difficulty,
    gold: 0,
    stage: 1,
    bestStage: 1,
    killsInStage: 0,
    enemyMaxHp: hp,
    enemyHp: hp,
    enemyName: enemyName(1, 0, false),
    isBoss: false,
    bossTimeLeft: 0,
    // 첫 동료는 기본 지급한다. DPS 가 0 이면 자동 진행도 오프라인 보상도
    // 아예 동작하지 않아 방치형 게임이 성립하지 않는다.
    heroLevels: HEROES.map((_, i) => (i === 0 ? 1 : 0)),
    upgrades: { tap: 0, critChance: 0, critDamage: 0, gold: 0 },
    stones: 0,
    totalStones: 0,
    prestigeCount: 0,
    totalKills: 0,
    bossFails: 0,
    lastSeen: Date.now(),
  };
}

/* ------------------------------------------------------------------ */
/* 파생 스탯                                                            */
/* ------------------------------------------------------------------ */

export type Stats = {
  dps: number;
  tapDamage: number;
  critChance: number;
  critMul: number;
  goldMul: number;
  damageMul: number;
};

export function computeStats(s: GameState): Stats {
  const damageMul = stoneDamageMul(s.stones);

  let rawDps = 0;
  for (let i = 0; i < HEROES.length; i++) {
    rawDps += heroDps(HEROES[i], s.heroLevels[i] || 0);
  }
  const dps = rawDps * damageMul;

  // 탭 공격은 기본치 + 총 DPS 의 일부라서 후반에도 의미가 남는다.
  const tapBase = (2 + 3 * s.upgrades.tap) * damageMul;
  const tapDamage = tapBase + dps * 0.08;

  const critChance = Math.min(0.65, 0.05 + 0.006 * s.upgrades.critChance);
  const critMul = 2 + 0.2 * s.upgrades.critDamage;
  const goldMul = (1 + 0.07 * s.upgrades.gold) * stoneGoldMul(s.stones);

  return { dps, tapDamage, critChance, critMul, goldMul, damageMul };
}

/* ------------------------------------------------------------------ */
/* 전투 진행                                                            */
/* ------------------------------------------------------------------ */

/** 다음 적을 등장시킨다 (state 를 직접 수정). */
export function spawnEnemy(s: GameState) {
  const diff = getDifficulty(s.difficulty);
  const boss = s.killsInStage >= KILLS_PER_STAGE;
  const hp = enemyHp(s.stage, diff, boss);

  s.isBoss = boss;
  s.enemyMaxHp = hp;
  s.enemyHp = hp;
  s.enemyName = enemyName(s.stage, s.killsInStage, boss);
  s.bossTimeLeft = boss ? diff.bossTime : 0;
}

export type StepEvent =
  | { kind: "kill"; boss: boolean; gold: number }
  | { kind: "stage"; stage: number }
  | { kind: "bossFail" };

/**
 * dt 초 만큼 전투를 진행한다. state 를 직접 수정하고 발생한 이벤트를 돌려준다.
 */
export function step(s: GameState, dt: number, stats: Stats): StepEvent[] {
  const events: StepEvent[] = [];

  if (s.isBoss) {
    s.bossTimeLeft -= dt;

    if (s.bossTimeLeft <= 0 && s.enemyHp > 0) {
      // 제한시간 초과 - 일반 몬스터 사냥으로 되돌아가 골드를 더 모은다.
      s.bossFails += 1;
      s.killsInStage = Math.max(0, KILLS_PER_STAGE - BOSS_FAIL_REFUND);
      spawnEnemy(s);
      events.push({ kind: "bossFail" });
      return events;
    }
  }

  if (stats.dps > 0) {
    s.enemyHp -= stats.dps * dt;
  }

  // 한 틱에 여러 마리가 죽을 수 있으므로 반복 처리한다.
  let guard = 0;
  while (s.enemyHp <= 0 && guard < 500) {
    guard++;
    events.push(...killEnemy(s, stats));
    if (s.isBoss) break; // 보스를 잡으면 다음 스테이지 첫 몬스터부터 다시 시작
  }

  return events;
}

/** 현재 적을 처치 처리한다. */
export function killEnemy(s: GameState, stats: Stats): StepEvent[] {
  const diff = getDifficulty(s.difficulty);
  const events: StepEvent[] = [];
  const boss = s.isBoss;
  const gold = enemyGold(s.stage, diff, boss) * stats.goldMul;

  s.gold += gold;
  s.totalKills += 1;
  events.push({ kind: "kill", boss, gold });

  if (boss) {
    s.stage += 1;
    s.killsInStage = 0;
    if (s.stage > s.bestStage) s.bestStage = s.stage;
    events.push({ kind: "stage", stage: s.stage });
  } else {
    s.killsInStage += 1;
  }

  const overkill = s.enemyHp; // 음수 - 다음 적에게 이월
  spawnEnemy(s);
  if (overkill < 0 && !s.isBoss) s.enemyHp += overkill;

  return events;
}

/** 탭 공격. 실제 입힌 피해와 치명타 여부를 돌려준다. */
export function tap(s: GameState, stats: Stats): { damage: number; crit: boolean } {
  const crit = Math.random() < stats.critChance;
  const damage = stats.tapDamage * (crit ? stats.critMul : 1);

  s.enemyHp -= damage;
  if (s.enemyHp <= 0) killEnemy(s, stats);

  return { damage, crit };
}

/* ------------------------------------------------------------------ */
/* 오프라인 보상                                                        */
/* ------------------------------------------------------------------ */

export type OfflineReward = { seconds: number; gold: number; kills: number };

export function offlineReward(s: GameState, now: number): OfflineReward | null {
  const stats = computeStats(s);
  if (stats.dps <= 0) return null;

  const seconds = Math.min(OFFLINE_CAP_SEC, Math.max(0, (now - s.lastSeen) / 1000));
  if (seconds < 60) return null;

  const diff = getDifficulty(s.difficulty);
  const hp = enemyHp(s.stage, diff, false);
  const killsPerSec = stats.dps / hp;
  const kills = killsPerSec * seconds * OFFLINE_RATE;
  const gold = kills * enemyGold(s.stage, diff, false) * stats.goldMul;

  if (gold <= 0) return null;
  return { seconds, gold, kills };
}

/* ------------------------------------------------------------------ */
/* 숫자 표기                                                            */
/* ------------------------------------------------------------------ */

const UNITS = [
  "", "K", "M", "B", "T", "aa", "ab", "ac", "ad", "ae",
  "af", "ag", "ah", "ai", "aj", "ak", "al", "am", "an", "ao",
];

export function fmt(n: number): string {
  if (!isFinite(n)) return "∞";
  if (n < 0) return "0";

  // 광기석·레벨처럼 정수인 값에 소수점을 붙이지 않는다.
  if (n < 1000) {
    return Number.isInteger(n) || n >= 10 ? String(Math.floor(n)) : n.toFixed(1);
  }

  let tier = Math.floor(Math.log10(n) / 3);
  if (tier >= UNITS.length) tier = UNITS.length - 1;

  let scaled = n / Math.pow(1000, tier);

  // 반올림 때문에 "1000K" 같은 표기가 나오면 한 단위 위로 올린다.
  if (scaled >= 999.995 && tier < UNITS.length - 1) {
    tier += 1;
    scaled = n / Math.pow(1000, tier);
  }

  return `${scaled.toFixed(scaled < 10 ? 2 : scaled < 100 ? 1 : 0)}${UNITS[tier]}`;
}

export function fmtTime(sec: number): string {
  const s = Math.max(0, Math.floor(sec));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const r = s % 60;
  if (h > 0) return `${h}시간 ${m}분`;
  if (m > 0) return `${m}분 ${r}초`;
  return `${r}초`;
}
