"use client";

import {
  useCallback,
  useEffect,
  useReducer,
  useRef,
  useState,
  type PointerEvent as ReactPointerEvent,
} from "react";
import Link from "next/link";
import s from "./game.module.css";
import {
  BOSS_FAIL_REFUND,
  createState,
  computeStats,
  DIFFICULTIES,
  DifficultyId,
  fmt,
  fmtTime,
  getDifficulty,
  GameState,
  HEROES,
  HERO_COST_GROWTH,
  heroDps,
  KILLS_PER_STAGE,
  maxAffordable,
  bulkCost,
  offlineReward,
  OfflineReward,
  PRESTIGE_MIN_STAGE,
  SAVE_KEY,
  SAVE_VERSION,
  step,
  stonesFor,
  tap,
  UPGRADES,
  UpgradeId,
  upgradeCost,
} from "./engine";

const TICK_MS = 100;
const SAVE_MS = 5000;

const FACES: Record<string, string> = {
  "광기의 늑대": "🐺",
  "심연 박쥐": "🦇",
  "녹빛 슬라임": "🟢",
  "폐허 골렘": "🗿",
  "저주받은 사냥꾼": "🏹",
  "불꽃 도마뱀": "🦎",
  "서리 정령": "❄️",
  "그림자 도적": "🥷",
};

const HERO_ICONS = ["⚔️", "🏹", "✨", "🗡️", "🔮", "🪓", "🌪️", "☠️", "🐲", "🎖️"];
const UPGRADE_ICONS: Record<UpgradeId, string> = {
  tap: "👊",
  critChance: "🎯",
  critDamage: "💥",
  gold: "💰",
};

type Pop = { id: number; x: number; y: number; text: string; crit: boolean };
type Toast = { id: number; text: string };
type BulkMode = 1 | 10 | "max";
type Tab = "heroes" | "upgrades" | "prestige" | "stats";

/** 진행 중인 회차만 초기화한다 (광기석과 누적 기록은 유지). */
function resetRun(prev: GameState, difficulty: DifficultyId): GameState {
  const next = createState(difficulty);
  next.stones = prev.stones;
  next.totalStones = prev.totalStones;
  next.prestigeCount = prev.prestigeCount;
  next.totalKills = prev.totalKills;
  next.bossFails = prev.bossFails;
  return next;
}

function loadState(): GameState | null {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return null;

    const parsed = JSON.parse(raw) as GameState;
    if (!parsed || parsed.v !== SAVE_VERSION) return null;

    // 저장 이후 동료가 추가돼도 깨지지 않도록 길이를 맞춘다.
    const fresh = createState(parsed.difficulty);
    const levels = HEROES.map((_, i) => parsed.heroLevels?.[i] ?? 0);
    const upgrades = { ...fresh.upgrades, ...(parsed.upgrades || {}) };
    return { ...fresh, ...parsed, heroLevels: levels, upgrades };
  } catch {
    return null;
  }
}

export default function GamePage() {
  const ref = useRef<GameState | null>(null);
  const [, render] = useReducer((x: number) => x + 1, 0);

  const [ready, setReady] = useState(false);
  const [tab, setTab] = useState<Tab>("heroes");
  const [bulk, setBulk] = useState<BulkMode>(1);
  const [pops, setPops] = useState<Pop[]>([]);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [offline, setOffline] = useState<OfflineReward | null>(null);
  const [diffOpen, setDiffOpen] = useState(false);
  const [pendingDiff, setPendingDiff] = useState<DifficultyId | null>(null);
  const [confirm, setConfirm] = useState<"prestige" | "reset" | null>(null);
  const seq = useRef(0);

  /* ---------------- 초기화 ---------------- */

  useEffect(() => {
    const loaded = loadState();

    if (loaded) {
      const reward = offlineReward(loaded, Date.now());
      if (reward) {
        loaded.gold += reward.gold;
        setOffline(reward);
      }
      loaded.lastSeen = Date.now();
      ref.current = loaded;
    } else {
      ref.current = createState("mad");
      setDiffOpen(true);
    }

    setReady(true);
  }, []);

  /* ---------------- 저장 ---------------- */

  const save = useCallback(() => {
    const state = ref.current;
    if (!state) return;
    state.lastSeen = Date.now();
    try {
      localStorage.setItem(SAVE_KEY, JSON.stringify(state));
    } catch {
      /* 저장 공간이 없으면 조용히 넘어간다 */
    }
  }, []);

  useEffect(() => {
    if (!ready) return;

    const id = setInterval(save, SAVE_MS);
    const onHide = () => {
      if (document.visibilityState === "hidden") save();
    };

    document.addEventListener("visibilitychange", onHide);
    window.addEventListener("pagehide", save);

    return () => {
      clearInterval(id);
      document.removeEventListener("visibilitychange", onHide);
      window.removeEventListener("pagehide", save);
      save();
    };
  }, [ready, save]);

  /* ---------------- 토스트 ---------------- */

  const pushToast = useCallback((text: string) => {
    const id = ++seq.current;
    setToasts((t) => [...t.slice(-2), { id, text }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 1600);
  }, []);

  /* ---------------- 게임 루프 ---------------- */

  useEffect(() => {
    if (!ready) return;

    let last = Date.now();

    const id = setInterval(() => {
      const state = ref.current;
      if (!state) return;

      const now = Date.now();
      // 탭이 백그라운드로 갔다 오면 dt 가 커지므로 상한을 둔다.
      const dt = Math.min(1, (now - last) / 1000);
      last = now;

      const events = step(state, dt, computeStats(state));

      for (const ev of events) {
        if (ev.kind === "stage") pushToast(`스테이지 ${ev.stage} 진입!`);
        if (ev.kind === "bossFail") {
          pushToast(`보스 토벌 실패 · ${BOSS_FAIL_REFUND}마리 후 재도전`);
        }
      }

      render();
    }, TICK_MS);

    return () => clearInterval(id);
  }, [ready, pushToast]);

  /* ---------------- 탭 공격 ---------------- */

  function onTap(e: ReactPointerEvent<HTMLDivElement>) {
    const state = ref.current;
    if (!state) return;

    const stats = computeStats(state);
    const { damage, crit } = tap(state, stats);

    const rect = e.currentTarget.getBoundingClientRect();
    const id = ++seq.current;
    const pop: Pop = {
      id,
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
      text: fmt(damage),
      crit,
    };

    setPops((p) => [...p.slice(-11), pop]);
    setTimeout(() => setPops((p) => p.filter((x) => x.id !== id)), 700);
    render();
  }

  /* ---------------- 구매 ---------------- */

  function buyHero(index: number) {
    const state = ref.current;
    if (!state) return;

    const hero = HEROES[index];
    const level = state.heroLevels[index];
    const count =
      bulk === "max"
        ? maxAffordable(hero.baseCost, HERO_COST_GROWTH, level, state.gold)
        : bulk;

    if (count <= 0) return;

    const cost = bulkCost(hero.baseCost, HERO_COST_GROWTH, level, count);
    if (cost > state.gold) return;

    state.gold -= cost;
    state.heroLevels[index] = level + count;
    render();
  }

  function buyUpgrade(id: UpgradeId) {
    const state = ref.current;
    if (!state) return;

    const up = UPGRADES.find((u) => u.id === id)!;
    const level = state.upgrades[id];
    if (level >= up.maxLevel) return;

    const count =
      bulk === "max"
        ? maxAffordable(up.baseCost, up.growth, level, state.gold, up.maxLevel)
        : Math.min(bulk, up.maxLevel - level);

    if (count <= 0) return;

    const cost = bulkCost(up.baseCost, up.growth, level, count);
    if (cost > state.gold) return;

    state.gold -= cost;
    state.upgrades[id] = level + count;
    render();
  }

  /* ---------------- 환생 / 난이도 / 초기화 ---------------- */

  function doPrestige() {
    const state = ref.current;
    if (!state) return;

    const gained = stonesFor(state.bestStage, getDifficulty(state.difficulty));
    if (gained <= 0) return;

    const next = resetRun(state, state.difficulty);
    next.stones += gained;
    next.totalStones += gained;
    next.prestigeCount += 1;

    ref.current = next;
    setConfirm(null);
    setTab("heroes");
    pushToast(`광기석 ${fmt(gained)}개 획득!`);
    save();
    render();
  }

  function applyDifficulty(id: DifficultyId) {
    const state = ref.current;
    if (!state) return;

    if (state.difficulty === id) {
      setDiffOpen(false);
      setPendingDiff(null);
      return;
    }

    ref.current = resetRun(state, id);
    setDiffOpen(false);
    setPendingDiff(null);
    setTab("heroes");
    pushToast(`난이도 [${getDifficulty(id).name}] 로 새 회차 시작`);
    save();
    render();
  }

  function hardReset() {
    try {
      localStorage.removeItem(SAVE_KEY);
    } catch {
      /* noop */
    }
    ref.current = createState("mad");
    setConfirm(null);
    setTab("heroes");
    setDiffOpen(true);
    render();
  }

  /* ---------------- 렌더 ---------------- */

  const state = ref.current;

  // ref 안의 객체를 제자리에서 수정하므로 메모이제이션 없이 매 렌더 계산한다.
  // (동료 10명 합산이라 비용이 거의 없다)
  const stats = state ? computeStats(state) : null;

  if (!ready || !state || !stats) {
    return (
      <main className={s.shell}>
        <div className={s.loading}>불러오는 중...</div>
      </main>
    );
  }

  const diff = getDifficulty(state.difficulty);
  const hpPercent = Math.max(0, Math.min(100, (state.enemyHp / state.enemyMaxHp) * 100));
  const timerPercent = state.isBoss
    ? Math.max(0, Math.min(100, (state.bossTimeLeft / diff.bossTime) * 100))
    : 0;
  const face = state.isBoss ? "🐉" : FACES[state.enemyName] || "👾";
  const stoneGain = stonesFor(state.bestStage, diff);

  return (
    <main className={s.shell}>
      <div className={s.topBar}>
        <Link className={s.back} href="/">
          ← 출석판
        </Link>

        <button className={s.diffChip} onClick={() => setDiffOpen(true)}>
          난이도 · {diff.name}
        </button>
      </div>

      <div className={s.resources}>
        <div className={s.resource}>
          <span className={s.icon}>💰</span>
          <div>
            <span className={s.label}>골드</span>
            <span className={`${s.value} ${s.goldValue}`}>{fmt(state.gold)}</span>
          </div>
        </div>

        <div className={s.resource}>
          <span className={s.icon}>🔮</span>
          <div>
            <span className={s.label}>광기석</span>
            <span className={`${s.value} ${s.stoneValue}`}>{fmt(state.stones)}</span>
          </div>
        </div>
      </div>

      <section className={`${s.battle} ${state.isBoss ? s.boss : ""}`}>
        {toasts.map((t) => (
          <div className={s.toast} key={t.id}>
            {t.text}
          </div>
        ))}

        <div className={s.stageRow}>
          <div>
            <span className={s.stageLabel}>스테이지</span>{" "}
            <span className={s.stageNum}>{state.stage}</span>
          </div>

          <div className={s.killDots}>
            {Array.from({ length: KILLS_PER_STAGE }).map((_, i) => (
              <span
                key={i}
                className={`${s.killDot} ${i < state.killsInStage ? s.on : ""}`}
              />
            ))}
          </div>
        </div>

        <div className={s.enemy} onPointerDown={onTap}>
          <div className={s.enemyFace}>{face}</div>

          <div className={s.enemyName}>
            {state.enemyName}
            {state.isBoss && <span className={s.bossTag}>BOSS</span>}
          </div>

          <div className={s.hpBar}>
            <div className={s.hpFill} style={{ width: `${hpPercent}%` }} />
            <div className={s.hpText}>
              {fmt(Math.max(0, state.enemyHp))} / {fmt(state.enemyMaxHp)}
            </div>
          </div>

          {pops.map((p) => (
            <div
              className={`${s.pop} ${p.crit ? s.crit : ""}`}
              key={p.id}
              style={{ left: p.x, top: p.y }}
            >
              {p.text}
            </div>
          ))}
        </div>

        {state.isBoss && (
          <div className={s.bossTimer}>
            <span>⏱ {state.bossTimeLeft.toFixed(1)}초</span>
            <div className={s.timerBar}>
              <div className={s.timerFill} style={{ width: `${timerPercent}%` }} />
            </div>
          </div>
        )}

        <p className={s.tapHint}>몬스터를 탭하면 추가 피해를 줍니다</p>
      </section>

      <div className={s.dpsRow}>
        <div className={s.dpsCard}>
          <span>초당 피해</span>
          <strong>{fmt(stats.dps)}</strong>
        </div>

        <div className={s.dpsCard}>
          <span>탭 피해</span>
          <strong>{fmt(stats.tapDamage)}</strong>
        </div>

        <div className={s.dpsCard}>
          <span>최고 기록</span>
          <strong>{state.bestStage}</strong>
        </div>
      </div>

      <nav className={s.tabs}>
        {(
          [
            ["heroes", "동료"],
            ["upgrades", "강화"],
            ["prestige", "환생"],
            ["stats", "기록"],
          ] as [Tab, string][]
        ).map(([id, label]) => (
          <button
            key={id}
            className={`${s.tab} ${tab === id ? s.active : ""}`}
            onClick={() => setTab(id)}
          >
            {label}
          </button>
        ))}
      </nav>

      <div className={s.tabBody}>
        {(tab === "heroes" || tab === "upgrades") && (
          <div className={s.bulkRow}>
            <span className={s.bulkLabel}>구매 단위</span>
            <div className={s.bulkBtns}>
              {([1, 10, "max"] as BulkMode[]).map((m) => (
                <button
                  key={String(m)}
                  className={`${s.bulkBtn} ${bulk === m ? s.active : ""}`}
                  onClick={() => setBulk(m)}
                >
                  {m === "max" ? "MAX" : `x${m}`}
                </button>
              ))}
            </div>
          </div>
        )}

        {tab === "heroes" &&
          HEROES.map((hero, i) => {
            const level = state.heroLevels[i];
            const prevOwned = i === 0 || state.heroLevels[i - 1] > 0;
            const count =
              bulk === "max"
                ? maxAffordable(hero.baseCost, HERO_COST_GROWTH, level, state.gold)
                : bulk;
            const cost = bulkCost(hero.baseCost, HERO_COST_GROWTH, level, Math.max(1, count));
            const affordable = prevOwned && count > 0 && cost <= state.gold;
            const dps = heroDps(hero, level) * stats.damageMul;

            return (
              <div
                className={`${s.row} ${prevOwned ? "" : s.locked}`}
                key={hero.id}
              >
                <div className={s.avatar}>{HERO_ICONS[i]}</div>

                <div className={s.rowMain}>
                  <div className={s.rowTitle}>
                    {hero.name}
                    <span className={s.lv}>Lv.{level}</span>
                  </div>
                  <div className={s.rowSub}>
                    {prevOwned
                      ? level > 0
                        ? `${hero.role} · 초당 ${fmt(dps)}`
                        : `${hero.role} · 영입 대기`
                      : `${HEROES[i - 1].name} 영입 후 해금`}
                  </div>
                </div>

                <button
                  className={s.buy}
                  disabled={!affordable}
                  onClick={() => buyHero(i)}
                >
                  {level === 0 ? "영입" : `강화 x${Math.max(1, count)}`}
                  <small>💰 {fmt(cost)}</small>
                </button>
              </div>
            );
          })}

        {tab === "upgrades" &&
          UPGRADES.map((up) => {
            const level = state.upgrades[up.id];
            const maxed = level >= up.maxLevel;
            const count = maxed
              ? 0
              : bulk === "max"
              ? maxAffordable(up.baseCost, up.growth, level, state.gold, up.maxLevel)
              : Math.min(bulk, up.maxLevel - level);
            const cost = bulkCost(up.baseCost, up.growth, level, Math.max(1, count));
            const affordable = !maxed && count > 0 && cost <= state.gold;

            return (
              <div className={s.row} key={up.id}>
                <div className={s.avatar}>{UPGRADE_ICONS[up.id]}</div>

                <div className={s.rowMain}>
                  <div className={s.rowTitle}>
                    {up.name}
                    <span className={s.lv}>Lv.{level}</span>
                  </div>
                  <div className={s.rowSub}>
                    {up.id === "critChance"
                      ? `치명타 ${(stats.critChance * 100).toFixed(1)}% (최대 65%)`
                      : up.id === "critDamage"
                      ? `치명타 피해 ${stats.critMul.toFixed(1)}배`
                      : up.id === "gold"
                      ? `골드 획득 ${((1 + 0.07 * level) * 100).toFixed(0)}%`
                      : up.desc}
                  </div>
                </div>

                <button
                  className={s.buy}
                  disabled={!affordable}
                  onClick={() => buyUpgrade(up.id)}
                >
                  {maxed ? "MAX" : `강화 x${Math.max(1, count)}`}
                  {!maxed && <small>💰 {fmt(cost)}</small>}
                </button>
              </div>
            );
          })}

        {tab === "prestige" && (
          <>
            <div className={s.note}>
              <strong>환생</strong>하면 골드·동료·강화가 모두 사라지는 대신
              <strong> 광기석</strong>을 얻습니다. 광기석 1개당 모든 피해
              +5%, 골드 획득 +3% 가 영구히 적용됩니다.
              <span className={s.big}>🔮 {fmt(stoneGain)}</span>
              지금 환생 시 획득량 (최고 스테이지 {state.bestStage} 기준)
            </div>

            <button
              className={s.wide}
              disabled={stoneGain <= 0}
              onClick={() => setConfirm("prestige")}
            >
              {stoneGain > 0
                ? `환생하고 광기석 ${fmt(stoneGain)}개 받기`
                : `스테이지 ${PRESTIGE_MIN_STAGE} 도달 시 환생 가능`}
            </button>

            <div className={s.note}>
              <div className={s.statList}>
                <div>
                  <span>보유 광기석</span>
                  <b>{fmt(state.stones)}</b>
                </div>
                <div>
                  <span>현재 피해 배수</span>
                  <b>x{stats.damageMul.toFixed(2)}</b>
                </div>
                <div>
                  <span>환생 횟수</span>
                  <b>{state.prestigeCount}회</b>
                </div>
              </div>
            </div>
          </>
        )}

        {tab === "stats" && (
          <>
            <div className={s.note}>
              <div className={s.statList}>
                <div>
                  <span>난이도</span>
                  <b>
                    {diff.name} (체력 x{diff.hpMul} · 골드 x{diff.goldMul})
                  </b>
                </div>
                <div>
                  <span>현재 / 최고 스테이지</span>
                  <b>
                    {state.stage} / {state.bestStage}
                  </b>
                </div>
                <div>
                  <span>누적 처치</span>
                  <b>{fmt(state.totalKills)}</b>
                </div>
                <div>
                  <span>보스 실패</span>
                  <b>{state.bossFails}회</b>
                </div>
                <div>
                  <span>누적 광기석</span>
                  <b>{fmt(state.totalStones)}</b>
                </div>
                <div>
                  <span>치명타</span>
                  <b>
                    {(stats.critChance * 100).toFixed(1)}% ·{" "}
                    {stats.critMul.toFixed(1)}배
                  </b>
                </div>
              </div>
            </div>

            <button className={s.ghost} onClick={() => setDiffOpen(true)}>
              난이도 변경
            </button>

            <button className={s.ghost} onClick={() => setConfirm("reset")}>
              처음부터 다시 시작
            </button>
          </>
        )}
      </div>

      {/* ---------------- 모달 ---------------- */}

      {offline && (
        <div className={s.overlay}>
          <div className={s.modal}>
            <h2>자리를 비운 사이</h2>
            <p>
              {fmtTime(offline.seconds)} 동안 동료들이 사냥을 이어갔습니다.
              (효율 55%, 최대 8시간)
            </p>

            <div className={s.note}>
              <div className={s.statList}>
                <div>
                  <span>처치</span>
                  <b>{fmt(offline.kills)}</b>
                </div>
                <div>
                  <span>획득 골드</span>
                  <b>💰 {fmt(offline.gold)}</b>
                </div>
              </div>
            </div>

            <div className={s.modalBtns} style={{ marginTop: 12 }}>
              <button className={s.primary} onClick={() => setOffline(null)}>
                수령하기
              </button>
            </div>
          </div>
        </div>
      )}

      {diffOpen && (
        <div className={s.overlay}>
          <div className={s.modal}>
            <h2>난이도 선택</h2>
            <p>
              난이도는 몬스터 체력, 보스 제한시간, 보상량을 바꿉니다. 높은
              난이도일수록 환생 보상인 광기석을 훨씬 많이 얻습니다.
            </p>

            <div className={s.diffList}>
              {DIFFICULTIES.map((d) => {
                const selected = (pendingDiff ?? state.difficulty) === d.id;
                return (
                  <button
                    key={d.id}
                    className={`${s.diffCard} ${selected ? s.on : ""}`}
                    onClick={() => setPendingDiff(d.id)}
                  >
                    <div className={s.diffHead}>
                      {d.name}
                      <span className={s.diffTag}>{d.tag}</span>
                    </div>
                    <p>{d.desc}</p>
                  </button>
                );
              })}
            </div>

            {pendingDiff && pendingDiff !== state.difficulty && (
              <div className={s.warn}>
                난이도를 바꾸면 현재 회차가 초기화됩니다. 골드·동료·강화는
                사라지고 광기석과 누적 기록은 유지됩니다.
              </div>
            )}

            <div className={s.modalBtns}>
              <button
                onClick={() => {
                  setDiffOpen(false);
                  setPendingDiff(null);
                }}
              >
                닫기
              </button>
              <button
                className={s.primary}
                onClick={() => applyDifficulty(pendingDiff ?? state.difficulty)}
              >
                {pendingDiff && pendingDiff !== state.difficulty
                  ? "이 난이도로 시작"
                  : "확인"}
              </button>
            </div>
          </div>
        </div>
      )}

      {confirm === "prestige" && (
        <div className={s.overlay}>
          <div className={s.modal}>
            <h2>환생하시겠습니까?</h2>
            <p>
              골드, 동료, 강화가 모두 초기화되고 스테이지 1부터 다시
              시작합니다. 대신 광기석 {fmt(stoneGain)}개를 영구히 획득합니다.
            </p>

            <div className={s.modalBtns}>
              <button onClick={() => setConfirm(null)}>취소</button>
              <button className={s.primary} onClick={doPrestige}>
                환생하기
              </button>
            </div>
          </div>
        </div>
      )}

      {confirm === "reset" && (
        <div className={s.overlay}>
          <div className={s.modal}>
            <h2>처음부터 다시 시작</h2>
            <p>
              광기석과 누적 기록을 포함한 모든 저장 데이터가 삭제됩니다. 되돌릴
              수 없습니다.
            </p>

            <div className={s.modalBtns}>
              <button onClick={() => setConfirm(null)}>취소</button>
              <button className={s.primary} onClick={hardReset}>
                전부 삭제
              </button>
            </div>
          </div>
        </div>
      )}
    </main>
  );
}
