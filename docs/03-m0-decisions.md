# XENO RECLAIMER — M0 결정 문서 (1차 검토 × GPT 2차 검토 통합)

작성일: 2026-09-19
입력: `01-design-review.md`(1차), `02-gpt-prompt.md`, GPT 2차 검토 결과
출력: M0 구현에 실제로 쓰는 결정.

**2026-09-19 최종 확정:** Q1(A), Q2(L-A), Q3(M-A), Q6(E-A) 사용자 승인. 추가 결정(Dash, Attack Slot, 탄약, Alien Sample, GameplayEffect) 확정. M0 Gate = **READY**. 확정 내용은 12장.

---

## 0. 사실 확인 (2026-09-19, 원문 기준)

| 항목 | GPT 조사 | 내 확인 | 판정 |
|---|---|---|---|
| Godot 최신 안정판 | 4.7.2 | GitHub releases: **4.7.2-stable (2026-08-18)**, 4.7.1(07-14), 4.7(06-18), 4.6.3(05-20) | 일치 |
| Jolt 기본 물리 | 4.6부터 신규 프로젝트 기본 | 2차 자료(godot PR #105737, 4.6 관련 기사)로 확인. 공식 문서는 프록시 차단으로 원문 미확인 | 일치(공식 문서 재확인은 프로젝트 생성 시 `physics/3d/physics_engine` 값으로 즉시 확인) |
| GdUnit4 | v6.2.1, 4.7/4.7.1 명시, 4.7.2 미명시 | README 호환표: master(v6.2.1) = 4.5~4.7.1. **4.7.2 미기재** | 일치. 4.7.2에서 스모크 테스트 필요 |
| Godot .NET 모바일 | Experimental | 공식 문서 프록시 차단. 2차 자료 기준 Android/iOS는 실험적 상태였고 안정 선언 근거를 찾지 못함 | 결론 유지: C# 전환 근거 없음. GDScript |
| Unity Personal | $200k | Unity 약관 요약: 최근 12개월 Total Finances $200,000 USD | 일치 |
| FLUX.1 dev | 모델 비상업, Output은 상업 가능 | 라이선스 원문: 모델은 Non-Commercial Purposes 한정. Output은 "We claim no ownership rights in and to the Outputs" + 경쟁 모델 학습 금지 외 제한 없음 | 일치. 단 상용 프로젝트 제작 과정에서 dev 모델 사용 자체가 비상업 조항에 걸릴 수 있으므로 **schnell(Apache-2.0) 또는 SDXL 계열만 사용** |
| Mixamo | 게임 포함 상업 사용 가능, 로열티 없음 | Adobe FAQ(2차 인용): 무제한 상업 사용, 크레딧 불필요. 단 raw 파일 재배포/에셋팩 판매 금지 | 일치. 사용 가능 |
| Hunyuan3D 2.x | 한국 제외 | **라이선스 원문 §1.l: "Territory" shall mean the worldwide territory, excluding the territory of the European Union, United Kingdom and South Korea.** | GPT 정확. **후보에서 제외** |
| 한국 AI 저작권 | 확정 표현 회피 | 동일 | "확인 필요" 유지. 인간 기여 기록 원칙 채택 |
| Steam AI 공개 | Pre-generated 공개, Live-generated는 가드레일 설명 | 2차 자료 다수 일치(2026-01-17 정책 조정). 공식 페이지는 프록시 차단 | 일치. 우리는 Pre-generated만 해당 |

프록시로 차단된 원문(godotengine.org, docs.godotengine.org, helpx.adobe.com, partner.steamgames.com, unity.com)은 로컬 PC에서 프로젝트 생성 시 한 번 더 확인한다. 결론을 바꿀 가능성은 낮다.

---

## 1. GPT 이견별 판정

### 이견 1 — GDExtension 전환 시점 / 중앙 Swarm Simulation
- GPT 주장: 100마리 실패 시 즉시 GDExtension이 아니라, per-enemy Node/CharacterBody/NavigationAgent를 제거하고 중앙 배열 시뮬레이션 + MultiMesh + Spatial Hash + 틱 분산을 먼저 적용. 벤치마크는 300까지. 100마리 간신히 60FPS면 모바일 대비 여유 부족.
- **판정: 동의.**
- 왜: 1차 검토도 "적끼리 물리 없음, NavigationAgent 없음, 틱 분산"을 원칙으로 세웠지만 클래스 표에서는 `Enemy (CharacterBody3D)`를 남겨 두어 모순이 있었다. GDScript에서 300마리의 진짜 병목은 물리나 렌더가 아니라 **Node 수 × 스크립트 호출 오버헤드**다. 마리당 Node 하나면 `_physics_process` 300회 호출 + Area 오버랩 + 트랜스폼 동기화가 매 프레임 발생한다. 배열 기반 시뮬레이션은 루프 1개에서 처리하고, 렌더는 `MultiMesh.buffer` 한 번 쓰기로 끝난다. GDExtension은 이 구조 위에서 프로파일러가 특정 함수를 지목했을 때만 그 함수를 내린다. 구조가 잘못된 상태에서 C++로 내리면 잘못된 구조가 빨라질 뿐이다.
- 100마리 여유 부족 주장도 동의. 프리미티브 100마리 60FPS는 프로덕션 에셋(스켈레톤, 그림자, VFX)이 들어가면 절반 이하로 떨어진다. PC 통과 기준은 200으로 올린다(6장).
- 최종 반영: **Enemy 아키텍처를 Data-Oriented Hybrid로 변경**(7장). 사용자 확인 필요(결정 L) — 되돌리기 어려운 아키텍처이므로.

### 이견 2 — Dash/Dodge
- GPT 주장: 스킬/보조 공격은 제외하되 Dash는 0.1 핵심 동사. M0-1(총/스웜) → M0-2(Dash) 후 재미 판정.
- **판정: 동의(단, 이미 포함돼 있었다).**
- 왜: 1차 문서 8장 "캐릭터: 이동/대시/재장전/사격", 11장 개발 순서 2번 "Player 이동 + Dash", M0 포함 목록 "이동/대시". Dash는 처음부터 0.1과 M0에 있었다. GPT가 "스킬 제외"를 Dash 제외로 읽은 것으로 보인다. 논리(사격→포위→위험 판단→Dash→재포지셔닝)는 정확하고, Dash 없이 재미를 판정하면 안 된다는 데 동의한다.
- 순서에 대해서는 부분 수정: Dash는 구현 비용이 30줄 수준이라 별도 단계로 뺄 이유가 없다. **M0-1에 Dash를 포함**하고, M0-2는 "감각 패스 + 적 3종"으로 쓴다. 이유: M0-1 벤치마크 중에도 플레이어가 100마리 사이를 빠져나가는 상황을 봐야 조향 규칙을 판단할 수 있다.
- 최종 반영: M0-1에 Dash. 5장.

### 이견 3 — 모바일 조기 Spike
- GPT 주장: PC 전투 규칙 확정 전에 1일 Android 조작 Spike(플레이어 + AR + 30마리 + 가상 스틱)로 aim-to-fire 성립 여부 확인. M0.75.
- **판정: 부분 동의.**
- 왜: 리스크 지적은 맞다. 마우스 정밀 조준으로 튜닝을 끝낸 뒤 스틱 조준을 붙이면 산탄각, 적 속도, 사거리를 다시 잡아야 한다. 그러나 "1일"은 첫 Android 빌드에 대한 과소평가다. Android SDK/JDK/키스토어/기기 USB 디버깅 설정은 처음이면 반나절~1일이 따로 들고, 기기가 없으면 불가능하다(결정 H/I 미답변).
- 더 싼 선행 검증이 있다: **게임패드 오른쪽 스틱**. 가상 스틱과 입력 형태(방향 벡터 + 크기)가 같고, 다른 점은 엄지 가림과 촉각 피드백뿐이다. `InputSource` 추상화에 게임패드를 M0-1부터 넣으면 반나절로 "스틱 조준 + 밀면 발사"가 재미있는지 PC에서 먼저 본다. Steam Deck 대응도 같이 얻는다.
- 최종 반영: M0-1에 게임패드 입력. M0.75 Android Spike는 유지하되 **기기 확보를 전제**로 하고, 성공 기준을 "10분 지속 실행 + 스틱 조준 성립 여부"로 정의(5장). 결정 B는 M0.75 전까지만 답하면 된다.

### 이견 4 — StatModifier 단일 체계
- GPT 주장: 수치 변경(StatModifier)과 행동 효과(GameplayEffect: trigger/condition/effect/params)를 데이터 모델에서 분리. 0.1은 StatModifier만 구현.
- **판정: 동의.**
- 왜: 1차 문서가 "Elite 접사, Legendary 효과까지 StatModifier로"라고 쓴 것은 과장이다. "사망 시 폭발", "3번째 탄환 관통", "Runner 소환"은 stat/op/value로 표현되지 않고, 억지로 넣으면 `stat = "on_death_explosion_radius"` 같은 가짜 스탯이 생긴다. 이건 나중에 반드시 갈아엎게 되는 종류의 부채다.
- 최종 반영: `UpgradeData`/`EnemyData`/미래 `AffixData`는 `modifiers: Array[StatModifier]`와 `effects: Array[GameplayEffect]` 두 배열을 가진다. `GameplayEffect` Resource 클래스는 필드만 정의하고 0.1에는 런타임(트리거 디스패처)이 없다. 보스의 특수기(Charge/Slam/Reinforcement)는 0.1에서 보스 스크립트에 직접 구현하되, 나중에 GameplayEffect로 옮길 수 있게 "trigger: 쿨다운, effect: 함수"로 표를 맞춘다.

### 이견 5 — 탄약
- GPT 주장: 0.1은 탄창 + 재장전 + 무한 예비탄. 예비탄/탄약 픽업은 난이도 Modifier(Ammo Crisis)나 Survival에서 도입.
- **판정: 부분 동의.**
- 왜: M0(총 손맛 검증)에서는 GPT가 옳다. 예비탄 부족은 "총이 재미있는가"와 무관한 변수를 추가하고, 벤치마크 중 탄약이 떨어지면 측정이 끊긴다. 0.1(루프 검증)에서는 1차 논리도 살아 있다: 픽업이 없으면 플레이어가 움직일 이유가 적 회피뿐이고, 상점에서 탄약을 살 이유도 없다. 다만 이건 "재미 규칙"이라 어느 쪽이 맞다고 단정할 수 없고, 데이터 필드(`reserve_max`, -1 = 무한) 하나로 양쪽을 전환할 수 있으므로 아키텍처 비용은 0이다.
- 최종 반영: **M0 = 무한 예비탄 확정.** 0.1은 사용자 결정(결정 C 수정안). 권장은 0.1도 무한 예비탄으로 시작하고 첫 플레이테스트 후 판단.

### 이견 6 — Alien Sample
- GPT 주장: 0.1 성장에 쓰이지 않는 통화를 사망 페널티용으로 추가하지 말 것. 성공 = Run Credit 100% + Clear Bonus, 실패 = Run Credit 50%, 보너스 없음.
- **판정: 동의.**
- 왜: 1차 안의 Alien Sample은 "탈출 긴장감"을 위해 넣었지만, 쓸 곳이 없는 통화는 잃어도 아프지 않다. 페널티는 실제로 쓰는 자원에 걸어야 의미가 있다. Clear Bonus(600)가 Run Credit(약 1,500)의 40%이므로 "실패 = 총수입의 약 1/3"이 되어 긴장감은 충분히 생긴다.
- 최종 반영: 결정 D 수정안. 사용자 확인 필요(UX 규칙).

### 이견 7 — 엔드게임 성장 이름/귀속
- GPT 주장: Slayer Level → Reclamation Rank 등 IP 언어 통일. 귀속은 계정 + Build/Loadout Profile 배분. 다중 캐릭터가 없는데 Character 귀속을 데이터 모델에 먼저 넣지 말 것.
- **판정: 명칭 동의, 귀속 부분 동의.**
- 왜: 명칭은 1차 권장과 같다. 귀속에 대해 GPT의 "존재하지 않는 시스템에 스키마를 맞추지 말라"는 원칙은 맞다. 그러나 1차 문서의 `characters[]` 배열은 Rank 배분용이 아니라 **세이브 스키마의 계정/캐릭터 분리**용이고, 이건 나중에 넣으면 마이그레이션이 가장 비싼 항목이라 유지한다. 둘은 충돌하지 않는다: Rank와 Point는 `account` 아래, 배분은 `account.loadouts[]`(Build Profile), 캐릭터는 `characters[]`에서 `loadout_id`로 참조. 다중 캐릭터가 생기면 캐릭터가 로드아웃을 고르는 것으로 끝난다.
- 최종 반영: 결정 J = "계정 귀속 Rank + Loadout Profile 배분, 세이브에는 `characters[]` 유지". 0.1 미구현. 결정 E(명칭)는 사용자 확인 필요(IP).

### 이견 8 — Hunyuan3D
- GPT 주장: "확인 필요"가 아니라 현재 Community License 기준 한국 제외 → 후보에서 제외.
- **판정: 동의. 원문 확인 완료.**
- 왜: Tencent Hunyuan 3D 2.0 Community License §1.l에서 Territory가 EU, UK, South Korea를 명시적으로 제외한다. 한국에서 개발하는 이상 로컬 파이프라인 후보가 될 수 없다.
- 최종 반영: 에셋 파이프라인 문서에서 제외. 이미지→3D 초안은 TripoSR(MIT) 등 허용 라이선스만.

### GPT 추가 위험 8개
| # | 위험 | 판정 | 반영 |
|---|---|---|---|
| 1 | 프리미티브 벤치마크 ≠ 프로덕션 성능 | 동의 | 0.1 이후 "Art Performance Slice" 마일스톤(M1.5) 신설. 적 1종만 프로덕션 품질로 만들어 300마리 재측정 |
| 2 | 아이소메트릭 가독성 붕괴 | 동의 | M0-2에서 적 3종을 색/크기/실루엣(구/캡슐/박스)으로 강제 구분. 모바일은 M0.75에서 확인 |
| 3 | 단순 조향의 병목 뭉침 | 동의 | 벤치마크 맵에 폭 3m 통로 1개 포함. Flow Field는 0.2 이후 |
| 4 | 오디오 보이스 폭주 | 동의 | M0-2에서 `AudioPool` 보이스 상한 24 + 우선순위(킬 > 피격 > 발사) + 같은 SFX 동시 재생 3개 제한 |
| 5 | 샷건 펠릿 × 적 수 쿼리 비용 | 동의 | Spatial Hash 세그먼트 쿼리로 해결. 8펠릿 × 셀 몇 개 = 수십 회 거리 계산 |
| 6 | 모바일 열 제한 | 동의 | M0.75 성공 기준에 10분 지속 실행 포함 |
| 7 | 로컬 세이브 신뢰 불가 | 동의 | 1차 문서 위험 7과 동일. RunResult 레코드 + "서버 권한 경계" 문단을 VISION에 추가 |
| 8 | 세이브 손상 | 동의 | 1차 문서에 이미 원자 쓰기 + 백업 있음 |

---

## 2. 최종 결정표 A~K

| ID | 질문 | 1차안 | GPT안 | 최종 권장 | 사용자 결정 | 왜 |
|---|---|---|---|---|---|---|
| A | 코드 리포/브랜치 | `crazymanclub` orphan 브랜치 또는 새 리포 | (미언급) | `crazymanclub`에 orphan 브랜치 `godot/main` | **확정(A)** | 기존 사이트 배포(`vercel.json`)를 깨지 않으면서 히스토리 분리. Vercel 프리뷰 배포 영향은 12장 참고 |
| B | 모바일 조준/발사 | 우측 스틱 밀면 발사 + 데이터 기반 조준 보정 | 동일 + M0.75 Spike로 검증 | 동일. M0-1에 게임패드 스틱으로 선행 검증 | **필요**(M0.75 전까지) | 조작 방식은 UX 핵심. 단 M0 아키텍처는 어느 답이든 수용 |
| C | 탄약 구조 | 탄창 + 예비탄 + 픽업 | 탄창 + 재장전 + 무한 예비탄 | **M0: 무한 예비탄 확정.** 0.1: 무한 예비탄으로 시작, 플레이테스트 후 재판단 | M0 확정. 0.1은 그때 결정 | 재미 규칙. `reserve_max = -1` 필드로 전환 비용 0 |
| D | 실패 규칙 | 미션 실패, Credit 50%, Sample 전량 상실 | Run Credit 50%, Clear Bonus 없음, Sample 제거 | GPT안 | M0: Alien Sample 제거 확정(통화는 Credit 하나). 실패 규칙 수치는 M1 전 결정 | UX 규칙. Sample은 쓸 곳이 없어 페널티 효과 없음 |
| E | Slayer 명칭 | Reclaimer 계열로 교체 | Reclamation Rank / Reclaimer Point / Reclaimer Corps | GPT안 + Slayer Mission → Reclamation Operation. 내부 ID(`progression.rank`, `guild.type`, `operation.type`)와 표시 문자열 분리 | **확정(A)** | IP 판단은 사용자 몫. 두 검토 모두 교체 권장 |
| F | Godot 버전 | 생성 시점 최신 안정판 고정 | 4.7.2 | **4.7.2-stable 고정**, 프로토타입 중 업그레이드 금지 | 확정 | GitHub releases 원문 확인. GdUnit4는 4.7.1까지만 명시 → 스모크 테스트 |
| G | 테스트 프레임워크 | GdUnit4 | GdUnit4 v6.2.1, 4.7.2 스모크 테스트 | GdUnit4. 4.7.2에서 실패 시 GUT로 대체 | 불필요 | 구현 세부. 실패 시 대안 명시됨 |
| H | Android 기준 기기 | 3~4년 전 미드레인지 1대 | 실제 보유 기기 확인 후 Reference 확정. 후보 Galaxy A34 5G급. 100마리 30FPS 15분 지속 | 사용자 보유 기기를 Reference로 | **필요** | 임의 확정 금지. 기기가 없으면 M0.75 불가 |
| I | Mac 보유(iOS) | 확인 필요 | (미언급) | 없으면 iOS는 2차 플랫폼에서 "보류"로 격하 | **필요** | iOS 빌드는 macOS 필수 |
| J | 엔드게임 Rank 귀속 | 계정 + 캐릭터별 배분 | 계정 + Build/Loadout Profile 배분 | 계정 Rank + `loadouts[]` 배분. 세이브의 `characters[]`는 유지 | 불필요(0.1 미구현) | 두 안이 충돌하지 않음. 스키마만 기록 |
| K | 난이도 명칭 | 게임 톤에 맞는 고유 명칭 검토 | 프로토타입은 기존 명칭 유지, `difficulty_tier` 정수 + `display_name_key` 분리 | GPT안. 명칭은 0.1 이후 | 불필요 | 데이터가 이름에 종속되지 않으면 언제든 교체 가능 |

---

## 3. 새 결정 L 이후

| ID | 질문 | 선택지 | 권장 | 사용자 결정 | 왜 |
|---|---|---|---|---|---|
| L | Enemy 아키텍처 | A) Data-Oriented Hybrid: 일반 적은 중앙 배열 시뮬레이션 + MultiMesh, 보스/플레이어/픽업만 Node. B) Node per Enemy(CharacterBody3D 없이 Node3D + 수동 이동). C) 전부 Node + CharacterBody3D | **A** | **확정(A)** | 되돌리기 가장 비싼 결정. A는 300마리 가능성이 가장 높지만 "적 = 씬" 직관을 버린다. B는 익숙하지만 200마리에서 Node 오버헤드가 한계. C는 100마리 실패 확률 높음. 두 검토 모두 A |
| M | PC 벤치마크 통과 기준 | A) 200마리 평균 60FPS / 1% Low 45. B) 100마리 60FPS. C) 300마리 60FPS | **A** | **확정(A)**. 10/30/50/100/200/300 전부 측정, 200 = Release Architecture Gate, 300 = Scalability Measurement | M0-1 성공/실패 판정선. 100은 여유 없음, 300은 GDScript 프리미티브에서도 불확실. 300은 측정만 |
| N | 게임패드를 M0-1에 포함 | A) 포함(스틱 조준 선행 검증 + Steam Deck). B) 제외 | **A** | 불필요 | 반나절. `InputSource` 구현체 1개 추가. 결정 B와 묶어서 답해도 됨 |

---

## 4. M0 최종 Scope

### IN
- Godot 4.7.2, GDScript, Forward+(PC). 프로젝트 골격, Input Map, Collision Layer, Autoload(`Events`만. `Profile`/`SaveService`는 M1)
- 그레이박스 맵 1개(60×60m 평면, 박스 장애물 6개, 폭 3m 통로 1개, 스폰 포인트 8개)
- 플레이어: 캡슐, WASD 이동(6.0 m/s), Dash(0.2s, 14 m/s, 쿨 1.0s, 무적), 마우스 조준(평면 교차), 게임패드 스틱 조준
- 무기: Assault Rifle 1종(히트스캔, 탄창 30, 재장전 1.6s, 무한 예비탄)
- 적: Drone 1종(M0-1) → Runner, Tank 추가(M0-2). 중앙 시뮬레이션 + MultiMesh
- 조향: Seek + Separation(Spatial Hash) + Arrive(공격 사거리에서 정지) + 원형 장애물 회피. 틱 그룹 분산
- 공격: 적 → 플레이어 근접(윈드업 0.35s). 플레이어 HP 100, 사망 시 즉시 재시작
- 감각(M0-2): 킬 히트스톱(프레임 단위), 카메라 트라우마 셰이크, 피격 플래시(인스턴스 커스텀 데이터), 넉백(시뮬레이션 속도 임펄스), 사망 파편(풀), 혈흔 데칼(단순), 머즐 플래시(라이트 + 빌보드), SFX 플레이스홀더 + 보이스 상한
- HUD: HP, 탄창, 킬 수, FPS/프레임타임, 적 수
- 벤치마크 씬 + 자동 러너(10/30/50/100/200/300, 각 30초, CSV 출력)
- 단위 테스트: SpatialHash, SwarmSim step, StatSheet, DamageCalc
- M0.75(조건부): TouchInput + 가상 스틱 2개 + Android 익스포트 + 10분 지속 실행

### OUT
- 상점, Credit, 드롭/픽업, 강화, Bio, 세이브, 결과 화면, 기지 씬, 미션 흐름(전부 M1)
- Shotgun, Plasma Rifle(M1. 단 `fire_mode`/`pellets`/`projectile` 필드는 M0 스키마에 존재)
- 보스(M1)
- 웨이브 데이터(M0는 "N마리 유지" 연속 스폰만)
- 스킬 1~4, 우클릭, 예비탄/탄약 픽업, Character Level, 레어리티, 난이도, Flow Field, 스켈레탈 애니메이션, 프로덕션 에셋, 텔레메트리(M1), 일시정지 메뉴(Esc = 재시작으로 대체)

---

## 5. M0-1 / M0-2 / M0.75

### M0-1 — 순수 Gun/Swarm (+Dash)
- 목표: "AR로 Drone 100마리 사이를 뚫고 다니며 쏘는 것"이 성립하는지, 그리고 시뮬레이션 구조가 200마리를 버티는지.
- 구현: 4장 IN 중 감각 항목과 Runner/Tank 제외 전부. 벤치마크 씬 포함.
- 성공 기준:
  1. 조작 지연 체감 없음(입력 → 이동/발사 반응 1프레임).
  2. 마우스와 게임패드 스틱 모두로 30초 내 30마리 처치 가능.
  3. 벤치마크 결정 M 통과(권장: 200마리 평균 60FPS, 1% Low 45, RTX 3070 PC).
  4. 300마리 측정치와 병목(시뮬레이션/렌더/물리 ms) 기록.
  5. 테스트 4종 headless 통과.
- 실패 시: 기준 3 실패 → 프로파일러로 병목 함수 특정 → (a) 틱 주기/이웃 수 조정, (b) 해당 함수만 GDExtension. 이 두 단계 후에도 실패면 엔진 재평가 회의(문서로). 기준 1~2 실패 → 조작 튜닝, 아키텍처 변경 없음.

### M0-2 — Gun Feel + 적 3종
- 목표: "쓸어버리는 쾌감"이 있는가. 켜고 끌 수 있는 감각 요소로 A/B 판정.
- 구현: 히트스톱, 셰이크, 피격 플래시, 넉백, 사망 파편, 혈흔, 머즐 플래시, SFX + 보이스 상한, Runner/Tank 데이터, 틱 그룹별 주기, 접선 편향(뭉침 방지), 실루엣/색 구분, 통로 뭉침 관찰.
- 성공 기준:
  1. 감각 요소 ON이 OFF보다 명백히 재미있다(본인 + 테스터 2인).
  2. 적 3종이 색/속도/실루엣으로 즉시 구분된다.
  3. Runner 50%/Drone 40%/Tank 10% 혼합 100마리에서 프레임 유지.
  4. 테스터 2인 중 2인 "한 판 더".
- 실패 시: 기준 1 실패 → 히트스톱/넉백 수치 재조정 1회 후 재판정. 두 번째도 실패면 **총 손맛 자체를 다시 설계**(RPM, 피해, 탄속 스펙 전면 재검토). 이 지점이 프로젝트의 진짜 Go/No-Go다.

### M0.75 — Android Input Spike (조건: 결정 H 기기 확보)
- 목표: 가상 스틱 aim-to-fire가 성립하는가. 10분 지속 실행 시 프레임과 발열.
- 구현: `TouchInput`(InputSource 구현체), 가상 스틱 2개, Android 익스포트 프리셋(Mobile 렌더러), 스틱 밀면 발사, 조준 보정 각도 파라미터(0/5/10°).
- 성공 기준:
  1. 기준 기기에서 100마리 30FPS 10분 지속.
  2. 스틱 조준으로 30초 내 30마리 처치 가능(보정 10° 이하).
  3. 화면에서 적/총알/플레이어가 구분된다.
- 실패 시: 기준 1 실패 → Compatibility 렌더러 재측정 → 그래도 실패면 모바일 목표 적 수를 50으로 낮추고 문서화. 기준 2 실패 → 보정 각도 상향 또는 Fire Button 방식 병행 테스트 → 결정 B 재논의. 이 스파이크 결과가 0.1 무기 스펙(산탄각, 사거리, 적 속도)의 상한을 정한다.

---

## 6. Benchmark Matrix

측정 프로토콜: 벤치마크 씬, 플레이어 자동 회전 사격(봇), 각 수량 30초, 처음 5초 제외. `Performance.get_monitor()` + `Time.get_ticks_usec()` 구간 측정. CSV로 `user://bench/`에 저장. Godot 4.7의 내장 Profiler로 교차 확인.

| 적 수 | Avg FPS | 1% Low FPS | Frame ms | CPU ms(메인 스레드) | GPU ms | Sim ms | Render 준비 ms | Physics ms | Memory MB | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|
| 10 | | | | | | | | | | 기준선 |
| 30 | | | | | | | | | | |
| 50 | | | | | | | | | | 0.1 성공 기준 5(50마리 공격) |
| 100 | | | | | | | | | | 모바일 목표 수량 |
| 200 | | | | | | | | | | **PC 통과선(결정 M)** |
| 300 | | | | | | | | | | 여유 측정. 통과 조건 아님 |

측정 항목 정의:
- Sim ms: `SwarmSim.step()` 전체(해시 재구축 + 조향 + 공격 판정).
- Render 준비 ms: `MultiMesh.buffer` 갱신 시간. GPU ms는 `RenderingServer.viewport_get_measured_render_time_gpu()`(4.7에서 사용 가능 여부 **확인 필요**, 불가 시 Frame ms − CPU ms로 추정).
- Physics ms: `Performance.PHYSICS_PROCESS_TIME`. 플레이어와 지형만 물리이므로 작아야 정상. 커지면 설계 위반.
- 통과 판정(PC, RTX 3070, CPU 모델 **확인 필요**): 200마리 Avg ≥ 60, 1% Low ≥ 45, Sim ms ≤ 6.
- Android(M0.75, 기준 기기): 50/100만 측정, 30초가 아니라 10분 지속. 통과: 100마리 Avg ≥ 30, 1% Low ≥ 24, 10분 후 Avg 하락 20% 이내.

---

## 7. M0 Architecture

### 최종 방향: **Data-Oriented Hybrid (결정 L-A)**
- 일반 적(Runner/Drone/Tank): Node 없음. `SwarmSim`이 배열로 소유. `SwarmRenderer`가 타입별 `MultiMeshInstance3D` 1개로 그린다.
- Node로 남는 것: Player(CharacterBody3D), Boss(M1, CharacterBody3D), Pickup(M1), FX(풀링된 GPUParticles3D/데칼), Camera, HUD.
- 물리 엔진(Jolt)이 하는 일: 플레이어 vs 지형뿐. 적은 물리 바디가 아니다.

### Scene
```
Mission (Node3D)                 flow/mission.tscn
├─ Level (Node3D)                levels/greybox_01.tscn — 지형 StaticBody, 장애물(원형 데이터 export), 스폰 포인트
├─ Player (CharacterBody3D)      entities/player/player.tscn
│   ├─ Mesh(Capsule) ├─ Health ├─ WeaponMount → Weapon ├─ AimController ├─ Dash
├─ IsoCamera (Camera3D)          fx/iso_camera.tscn — 추적, 룩어헤드, 트라우마 셰이크
├─ Swarm (Node3D)                swarm/swarm.tscn
│   ├─ SwarmSim (Node)           배열 시뮬레이션. _physics_process에서 step()
│   ├─ SwarmRenderer (Node3D)    타입별 MultiMeshInstance3D + 시체용 MultiMesh
│   └─ SwarmSpawner (Node)       "N마리 유지" 또는 WaveData(M1)
├─ FXPool (Node3D)               fx/ — 파편, 데칼, 머즐, 히트 스파크
├─ AudioPool (Node)              audio/ — 보이스 상한 24, 우선순위
├─ HUD (CanvasLayer)             ui/hud.tscn
└─ MissionState (Node)           M0: 플레이어 사망 → 재시작. M1: 웨이브/보스/탈출/RunResult
```

### Class
```
SwarmSim (Node)
  capacity: int = 512
  pos: PackedVector3Array      vel: PackedVector3Array
  hp: PackedFloat32Array       type: PackedInt32Array      state: PackedByteArray (IDLE/CHASE/WINDUP/ATTACK/STAGGER/DEAD)
  timer: PackedFloat32Array    tick_group: PackedByteArray  flash: PackedFloat32Array
  alive: PackedByteArray       free_list: PackedInt32Array
  types: Array[EnemyData]      hash: SpatialHash
  spawn(type_idx, at) -> idx   kill(idx)   step(dt)
  query_segment(from, to, radius) -> Array[int]      # 히트스캔용
  query_circle(center, r) -> PackedInt32Array         # 스플래시/플레이어 접촉용
  apply_damage(idx, DamageInfo)  apply_impulse(idx, v)
  signal enemy_killed(idx, type_idx, pos)   signal player_hit(damage, from_pos)

SpatialHash (RefCounted)      cell 1.5m, XZ. rebuild(pos, alive), neighbors(idx, r, max_n), cells_along(from, to)
SwarmRenderer (Node3D)        per type: MultiMeshInstance3D; per frame buffer 갱신(Transform3D 12 float + custom 4 float)
SwarmSpawner (Node)           target_count, spawn_points, interval
EnemyData (Resource)          id, hp, speed, damage, attack_range, attack_cooldown, windup, knockback_resist, radius, color, mesh, tick_hz, credit(M1), modifiers[], effects[]
WeaponData (Resource)         id, fire_mode, damage, rpm, magazine, reserve_max(-1), reload_time, spread_deg, pellets, recoil_bloom, projectile(M1), hit_stop_frames{normal, kill}, trauma, sfx, vfx, price(M1), modifiers[]
Weapon (Node3D)               fire()/reload()/tick. hitscan → SwarmSim.query_segment → apply_damage
StatModifier (Resource)       stat: StringName, op: ADD/MUL/OVERRIDE, value
GameplayEffect (Resource)     trigger, condition, effect_id, params: Dictionary   # 0.1 런타임 없음
StatSheet (RefCounted)        base: Dictionary, mods: Array[StatModifier], get(stat), 캐시 무효화
DamageInfo (RefCounted)       amount, source_pos, dir, knockback, is_crit, is_kill(결과)
Health (Node)                 플레이어/보스용. 적은 SwarmSim.hp
InputSource (Node)            move: Vector2, aim_dir: Vector2, aim_world: Vector3, fire/dash/reload/interact: bool, aim_assist_deg: float
  PcInput / GamepadInput (M0-1)   TouchInput (M0.75)
AimController (Node)          마우스: 레이-평면. 스틱: 플레이어 기준 방향 + 보정(가장 가까운 적 각도 스냅, SwarmSim.query_circle)
Dash (Node)                   상태/쿨/무적
IsoCamera (Camera3D)          trauma: float, shake = trauma²
HitStop (Node)                Engine.time_scale 0.05 × N프레임. 큐잉(중첩 시 최대값)
FXPool / AudioPool (Node)     acquire/release. AudioPool: 보이스 상한, 우선순위, 동일 SFX 동시 3개
BenchRunner (Node)            수량 배열 순회, 30초 측정, CSV
Events (Autoload)             enemy_killed, player_died, bench_step_done. 이것만
```

### Resource / Data
- `data/enemies/{drone,runner,tank}.tres`, `data/weapons/ar_basic.tres`. `schema/*.gd`에 `class_name`.
- M0 수치는 GPT 초안 + 9장 수정안. 전부 `.tres`에 있고 코드에 숫자 없음.

### Simulation (step 순서, 매 물리 프레임 60Hz)
1. `hash.rebuild()` (300개 O(n))
2. 틱 그룹 선택: `frame % 4 == tick_group` → 그룹당 조향 갱신(15Hz), 나머지는 이전 `vel` 유지. 플레이어 8m 이내는 매 프레임(60Hz). 타입별 Hz 대신 **거리별 Hz**(더 단순, 효과 동일)
3. 조향(갱신 대상만): seek(플레이어) + separation(이웃 최대 8, r=radius×2) + obstacle repulsion(원형 장애물 리스트) + tangential bias(idx 홀짝으로 ±, M0-2) → `vel`
4. 적분: `pos += vel × dt` (전원, 매 프레임 — 보간 대신 항상 이동. 15Hz 조향이라도 이동은 60Hz라 끊김 없음)
5. 공격: 플레이어까지 거리 ≤ attack_range → WINDUP(0.35s) → 판정 → 쿨다운. 동시 공격 상한 12(가까운 순). Attack Slot 링은 **M0에서 구현하지 않음**. 분리 + Arrive + 상한만으로 뭉침이 문제면 M0-2에서 접선 편향, 그래도 안 되면 M1에서 슬롯
6. 타이머(윈드업, 스태거, 플래시 감쇠)
7. 사망: `alive=0`, free_list 반환, `enemy_killed` 발신 → FXPool 파편 + 시체 MultiMesh(TTL 10s)

GPT 제안 대비 단순화: 타입별 Hz → 거리별 Hz. Attack Slot 링 → 동시 공격 상한 + Arrive. 두 가지 모두 목적(성능, 뭉침 방지)은 같고 코드는 절반.

### Rendering
- 타입별 MultiMesh, `use_custom_data = true`(피격 플래시, 스태거 스쿼시). 셰이더: 커스텀 데이터로 플래시 색, 시간+인스턴스 ID로 바운스(절차 애니메이션). 그림자: M0 OFF, M1.5(Art Slice)에서 측정.
- 시체: 별도 MultiMesh, 최대 200, 링 버퍼.
- PC Forward+, Android Mobile 렌더러(`rendering_method.mobile` 프로젝트 설정 오버라이드).

### Input
- `InputSource` 인터페이스 → `PcInput`(마우스+키보드), `GamepadInput`(M0-1), `TouchInput`(M0.75). Player는 `InputSource`만 본다.
- 조준 보정은 `AimController`에 있고 `aim_assist_deg`는 InputSource가 제공(PC 0, 패드 5, 터치 10 시작값).

### Test
- GdUnit4 v6.2.1, 4.7.2 스모크(설치 후 예제 테스트 1개 실행). 실패 시 GUT.
- 테스트: `SpatialHash`(이웃 정확성 vs 브루트포스), `SwarmSim.step`(고정 시드 100프레임 결정성, seek 방향, separation 최소 거리), `StatSheet`(ADD/MUL 순서), `Weapon` 피해 계산(펠릿, 크리).
- headless: `godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests` (정확한 인자는 설치 시 README로 확인).

### Save
- M0: 없음. M1에서 `SaveService`(JSON, `schema_version`, 원자 쓰기 + 백업, `user://`에서 Resource load 금지). 스키마는 1차 문서 10장 + 결정 J 반영(`account.rank`, `account.loadouts[]`, `characters[].loadout_id`).

---

## 8. M0 구현 순서 (파일 단위)

### M0-1
| # | 파일 | 내용 |
|---|---|---|
| 0 | `project.godot` | 4.7.2, Forward+ / mobile 오버라이드, Jolt 확인, Input Map(1차 문서 10장), 물리 레이어 이름, Autoload `Events` |
| 1 | `core/events.gd` | 시그널 3개 |
| 2 | `schema/stat_modifier.gd`, `schema/gameplay_effect.gd`, `schema/enemy_data.gd`, `schema/weapon_data.gd` | Resource 클래스 |
| 3 | `data/enemies/drone.tres`, `data/weapons/ar_basic.tres` | 9장 수치 |
| 4 | `combat/stat_sheet.gd`, `combat/damage_info.gd`, `tests/test_stat_sheet.gd` | + 테스트 |
| 5 | `swarm/spatial_hash.gd`, `tests/test_spatial_hash.gd` | |
| 6 | `swarm/swarm_sim.gd`, `tests/test_swarm_sim.gd` | spawn/kill/step/query/apply_damage |
| 7 | `swarm/swarm_renderer.gd`, `swarm/enemy_multimesh.gdshader` | MultiMesh + 플래시 셰이더 |
| 8 | `swarm/swarm_spawner.gd`, `swarm/swarm.tscn` | |
| 9 | `levels/greybox_01.tscn` + `levels/level_data.gd` | 지형, 장애물 원형 export, 스폰 포인트, 통로 |
| 10 | `input/input_source.gd`, `input/pc_input.gd`, `input/gamepad_input.gd` | |
| 11 | `entities/player/player.tscn/.gd`, `aim_controller.gd`, `dash.gd`, `combat/health.gd` | |
| 12 | `weapons/weapon.tscn/.gd`, `fx/muzzle_flash.tscn` | 히트스캔 → SwarmSim |
| 13 | `fx/iso_camera.tscn/.gd` | 추적 + 룩어헤드(셰이크는 M0-2) |
| 14 | `ui/hud.tscn/.gd` | HP/탄창/킬/FPS/적 수/Sim ms |
| 15 | `flow/mission.tscn/.gd`, `flow/mission_state.gd` | 조립, 사망 → 재시작 |
| 16 | `levels/benchmark.tscn`, `tools/bench_runner.gd`, `tools/bench_bot.gd` | 자동 측정 + CSV |
| 17 | `docs/xeno-reclaimer/bench/m0-1-pc.md` | 측정 결과 + 병목 기록 |

### M0-2
| # | 파일 | 내용 |
|---|---|---|
| 18 | `fx/hit_stop.gd`, `fx/iso_camera.gd`(trauma) | |
| 19 | `swarm/swarm_sim.gd`(넉백, 스태거, 접선 편향, 거리별 Hz), 셰이더(플래시/스쿼시) | |
| 20 | `fx/fx_pool.gd`, `fx/death_burst.tscn`, `fx/blood_decal.tscn`, `fx/hit_spark.tscn` | |
| 21 | `audio/audio_pool.gd`, `audio/sfx/*.wav`(sfxr) | 보이스 상한 |
| 22 | `data/enemies/runner.tres`, `tank.tres` | 실루엣/색 |
| 23 | `ui/debug_toggles.tscn` | 감각 요소 ON/OFF (F1~F6) |
| 24 | `docs/xeno-reclaimer/bench/m0-2-feel.md` | A/B 판정 기록 |

### M0.75 (결정 H 확보 시)
| # | 파일 | 내용 |
|---|---|---|
| 25 | `input/touch_input.gd`, `ui/virtual_stick.tscn` | |
| 26 | `export_presets.cfg`(Android), 키스토어(리포 밖) | |
| 27 | `docs/xeno-reclaimer/bench/m0-75-android.md` | 10분 지속 측정 |

---

## 9. GPT 수치 초안 검증 (M0/M1 시작값)

### 경제 (M1용, M0 미구현)
계산: 250마리 × (Runner 50%×4 + Drone 40%×6 + Tank 10%×16) = 125×4 + 100×6 + 25×16 = **1,500**. + Boss 200 + Clear 600 = **2,300**. GPT 계산 일치.
- 미션 1회 후 2,300 → +1 강화(1,200) 가능 ✔. 잔액 1,100.
- 강화만 했을 때 3회 후: 1,100 + 2,300×2 = 5,500 → Shotgun(5,500) 정확히 가능 ✔. 단 Bio 1개(1,800)를 샀으면 5회차. "3회 전후"는 성립하되 선택 압박이 있다. 의도된 트레이드오프로 수용.
- 실패 시 750(1,500×50%). 성공 대비 1/3. 페널티 체감 충분.
- **문제 1: +8%/단계는 체감이 없다.** AR 22 → +1에서 23.76. Runner 66HP는 3발 → 3발, Drone 132HP는 6발 → 6발. 브레이크포인트가 하나도 안 움직인다. 성공 기준 9("즉시 체감")를 강화가 아니라 무기 구매만 만족시키게 된다.
  - 수정안: 단계당 **+10%**, 적 HP를 브레이크포인트에 맞춰 조정. Runner **52**(기본 3발 → +2에서 26.4×2=52.8 ≥ 52 → 2발), Drone **105**(기본 5발 → +2에서 4발), Tank 660 유지(DPS 기반 체감). +2 강화(누적 3,200 Credit, 미션 2회)에서 "한 발 덜 쏜다"를 체감한다.
- **문제 2: 250마리/미션의 근거.** 10~15분에 250마리 = 분당 17~25킬. 호드 게임으로 무난하지만 M0-1 벤치마크에서 "플레이어가 실제로 죽이는 속도"를 측정한 뒤 확정. 웨이브 5개 × 50 + 보스 리인포스먼트.

### 무기
| 항목 | AR | Shotgun | Plasma | 판정 |
|---|---|---|---|---|
| DPS(탄창 내) | 220 | 235(8펠릿 전부 적중) | 360 + 스플래시 | Plasma가 9,500짜리 최종 무기라면 타당. 단 Plasma 스플래시가 다수 적중이면 실효 DPS 500+ → M1 플레이테스트에서 하향 여지 |
| 지속 DPS(재장전 포함) | 143 | 162 | 250 | 역할 차이 명확 |
| 히트스톱 ms | 0/8 | 12/25 | 5/15 | **문제: ms 단위는 60FPS에서 1프레임(16.7ms) 미만이라 실행 불가.** `Engine.time_scale` 방식은 프레임 단위로 양자화된다. 수정: **프레임 단위**. AR 킬 1프레임, Shotgun 일반 1 / 킬 3, Plasma 일반 0 / 킬 2. 히트스톱 대신 로컬 반응(플래시/스쿼시/넉백)을 AR의 주 피드백으로 쓰는 GPT 원칙은 동의 |
| Recoil(°) | 0.6 | 4.0 | 1.0 | 아이소메트릭 마우스 조준에서 카메라 킥은 조준을 방해한다. Recoil = **산탄 블룸**(연사 시 spread 증가, 정지 시 회복)으로 정의. 값은 블룸 증가량 |
| Plasma 28 m/s | | | | Runner 7.2 m/s 대비 4배. 10m에서 0.36s 리드. 아이소메트릭에서 리드 사격은 재미 요소가 될 수 있으나 스틱 조준에서는 명중률이 크게 떨어진다 → M0.75 결과 후 32~36 m/s 상향 여지 |
| Shotgun 14° | | | | 8펠릿 14°면 5m에서 폭 1.2m. 근접 다수 적중 OK |

### 적 / 플레이어
- **플레이어 이동 속도가 정의돼 있지 않다.** Runner 7.2 m/s가 의미를 가지려면 플레이어 속도가 필요. 시작값: **플레이어 6.0 m/s**, Dash 14 m/s × 0.2s(2.8m) 쿨 1.0s. Runner는 플레이어보다 빠름(Dash로만 떨쳐냄), Drone 느림, Tank 매우 느림.
- **피해량 문제.** Runner 8/0.8s × 동시 공격 12 = 120 DPS → HP 100이 1초 만에 죽는다. Dash 반응 시간이 없다. 수정: 모든 적 공격에 **윈드업 0.35s**(텔레그래프: 스쿼시/색 변화), Runner 피해 **6**, 동시 공격 상한 **8**. 최악 48 DPS → 포위 시 2초. 플레이어 회복은 M0 없음(M1 Torso Bio에서 재생 검토).
- HP: Runner 52, Drone 105, Tank 660, Boss 5,280(M1). AR 지속 DPS 143 기준 보스 37초 + 리인포스먼트. 적정.
- 보스 행동 3종(Charge/Slam/Reinforcement) 동의. M1.
- 스폰 비율 50/40/10 동의.

### 조향
GPT 안(Attack Slot 링 + 타입별 Hz)은 목적에 비해 M0에 과하다. 대체안은 7장 Simulation 참고: 동시 공격 상한 + Arrive + 거리별 Hz + 접선 편향. 링은 이 조합이 실패했을 때 M1.

---

## 10. 구현 전 사용자 질문 (최대 10개)

이미 답한 항목(F Godot 4.7.2, G GdUnit4, J, K, N)은 묻지 않는다. "전부 권장안대로"라고 답해도 된다.

**Q1. [A] 코드를 둘 곳**
- A안: `crazymanclub`에 orphan 브랜치 `godot/main` (기존 `main`/Vercel 배포 무영향)
- B안: 새 리포 `xeno-reclaimer` (이 세션에 리포 생성 권한이 있는지 확인 필요)
- C안: `crazymanclub/main` 교체 (기존 사이트 배포 깨짐)
- 추천: **A**. 왜: 즉시 가능하고 되돌리기 쉽다.

**Q2. [L] Enemy 아키텍처**
- A안: Data-Oriented Hybrid(중앙 배열 + MultiMesh, 보스/플레이어만 Node)
- B안: Node per Enemy(Node3D + 수동 이동, CharacterBody 없음)
- C안: 전부 CharacterBody3D
- 추천: **A**. 왜: 300마리 목표에 유일하게 현실적. 대가는 "적 = 씬" 직관 상실과 에디터에서 적 하나를 드래그해 배치할 수 없다는 것. 두 검토 모두 A.

**Q3. [M] M0-1 벤치마크 통과선(RTX 3070 PC)**
- A안: 200마리 평균 60FPS, 1% Low 45
- B안: 100마리 60FPS
- C안: 300마리 60FPS
- 추천: **A**. 왜: 100은 프로덕션 에셋 후 여유가 없고, 300은 GDScript에서 실패 확률이 높아 실패가 정보를 주지 못한다. 300은 측정만.

**Q4. [C] 0.1 탄약 구조** (M0는 무한 예비탄으로 확정)
- A안: 0.1도 무한 예비탄. 탄약 부족은 난이도 Modifier로 나중에
- B안: 0.1부터 예비탄 + 미션 내 탄약 픽업
- 추천: **A**. 왜: 루프 검증 변수를 줄인다. 필드 하나로 전환 가능.

**Q5. [D] 사망/실패 규칙**
- A안: 미션 실패, Run Credit 50% 보존, Clear Bonus 없음 (Alien Sample 0.1 제거)
- B안: Run Credit 0%
- C안: Run Credit 100%, Clear Bonus만 상실
- 추천: **A**. 왜: 성공 대비 1/3 수입. 아프지만 진행은 된다.

**Q6. [E] "Slayer" 명칭 교체**
- A안: Reclamation Rank / Reclaimer Point / Reclaimer Corps로 교체
- B안: Slayer 유지
- 추천: **A**. 왜: 참고 원작 제목 단어. IP 원칙과 브랜드 일관성. 0.1 코드에는 안 나오지만 문서/ID 명명에 즉시 영향.

**Q7. [H] Android 테스트 기기** — 실제 보유 기기 모델명을 알려 달라
- A안: Galaxy A34 5G급(2023 미드레인지)을 보유 → Reference 확정
- B안: 다른 기기 보유 → 모델명 (Reference로 지정)
- C안: 없음 → M0.75 보류, 모바일 목표는 0.2로 이월
- 추천: 보유 기기 그대로. 왜: 임의 확정 금지. 기기 없이는 M0.75 불가.

**Q8. [I] Mac 보유 여부**
- A안: 있음 → iOS 2차 플랫폼 유지
- B안: 없음 → iOS "보류"로 격하, Android만 모바일 목표
- 추천: 사실대로. 왜: iOS 익스포트/제출은 macOS 필수.

**Q9. [B] 모바일 조준/발사 방식** (M0.75 전까지 답하면 됨. M0-1은 게임패드 스틱으로 선행 검증)
- A안: 오른쪽 스틱 방향 조준 + 스틱을 밀고 있으면 발사 + 조준 보정(각도 스냅)
- B안: 오른쪽 스틱 조준 + 별도 Fire 버튼
- C안: 가장 가까운 적 자동 조준 + Fire 버튼(모바일 한정 옵션)
- 추천: **A**(C는 옵션으로 병행 가능). 왜: 손가락 수 최소, 트윈스틱 관습. M0.75에서 A가 실패하면 C를 옵션으로.

---

## 11. 마지막 Gate

| 조건 | 상태 |
|---|---|
| A~K 결정 완료 | A, E, F, G, J, K 확정. C/D는 M0분 확정, 0.1분은 M1 전 결정. B/H/I는 M0.75 전 결정 |
| 새 필수 결정(L, M) | 확정 |
| M0 IN/OUT 확정 | 확정(4장 + 12장) |
| Godot 버전 | 4.7.2-stable 고정. 바이너리 `4.7.2.stable.official.ed1daf0bf`로 실행 확인 |
| Enemy 아키텍처 | L-A 확정 |
| Input 기준 | M0-1: 마우스 + 게임패드 |
| Benchmark 성공 조건 | M-A 확정 |
| 사용자 질문 해결 | Q1/Q2/Q3/Q6 해결. Q4/Q5는 M1 전, Q7/Q8/Q9는 M0.75 전 |

**M0 구현 준비 상태: READY**

---

## 12. 최종 확정 사항 (2026-09-19, 사용자 승인)

### Q1 코드 위치 — A안
- `crazymanclub`에 orphan 브랜치 `godot/main`. 기존 `main`과 히스토리/파일을 공유하지 않는다. Godot 프로젝트는 브랜치 루트에 둔다(서브폴더 아님) → 나중에 `git push <new-repo> godot/main:main` 한 줄로 히스토리를 유지한 채 리포 분리 가능.
- 검증 결과: 리포에 GitHub Actions 없음(`.github/` 부재). Vercel 프로젝트 `crazymanclub`이 이 리포에 연결돼 있음(Vercel API로 확인). Vercel은 기본값으로 모든 브랜치 푸시에 프리뷰 배포를 시도하므로 `godot/main` 푸시 시 **프리뷰 빌드가 실행되고 실패할 가능성이 높다**(Next.js 앱이 없으므로). 프로덕션(`main`)에는 영향 없음. 프로젝트 설정(Root Directory, 브랜치별 배포 설정)은 API 권한 부족(403)으로 읽지 못함. 처리 방안은 사용자 보고 후 결정.

### Q2 Enemy 아키텍처 — A안
- 일반 적: 중앙 배열 시뮬레이션(`positions/velocities/hp/states/enemy_types/attack_cooldowns` + M0 최소 데이터) → Steering/Separation/Attack → MultiMesh. 잡몹에 CharacterBody3D/NavigationAgent3D/AnimationTree/Scene Node를 개별 생성하지 않는다. 플레이어/보스만 Node.
- 범용 ECS/프레임워크 금지. GDExtension은 지금 도입하지 않는다. 순서: GDScript → 중앙 시뮬레이션 → MultiMesh → 공간 분할/틱 최적화 → 프로파일러 → 실제 병목 확인 → 필요한 함수만 GDExtension 검토.

### Q3 벤치마크 — A안
- 공식 Gate: PC 200마리 Avg ≥ 60 FPS, 1% Low ≥ 45. 측정은 10/30/50/100/200/300 전부. 200 = Release Architecture Gate, 300 = Scalability Measurement(필수 아님, 기록 필수).
- 기록 항목: Avg FPS, 1% Low, Frame Time, Main Thread Time, Enemy Simulation Time, Rendering Time, Physics Time, Memory, Draw Calls, GPU Usage(가능한 범위). 하드웨어: RTX 3070 8GB + CPU 모델(자동 수집 `OS.get_processor_name()`).
- Android Gate는 별도.

### Q6 명칭 — A안
- Slayer Level → Reclamation Rank, Slayer Point → Reclaimer Point, Slayer Corps → Reclaimer Corps, Slayer Mission → Reclamation Operation. 내부 ID와 UI 문자열 분리(`progression.rank`, `guild.type`, `operation.type`).

### 추가 확정
- **Dash**: M0-1 포함. 스킬 시스템이 아니라 플레이어 기본 전투 이동. 수치는 플레이테스트 값.
- **Attack Slot Ring**: M0 미구현. Arrive + Separation + 동시 공격 상한 + 거리 기반 갱신 주기부터.
- **탄약**: M0 = 탄창 + 재장전 + 무한 예비탄. 픽업/예비탄 관리는 0.1에서 재결정.
- **Alien Sample**: M0 제거. 통화는 Credit 하나.
- **GameplayEffect**: M0는 StatModifier 최소 구현. 개념은 분리(StatModifier = 수치, GameplayEffect = 트리거 행동). 범용 프레임워크 미구현.

### 진행 원칙(사용자 지정)
한 번에 전체 구현 금지, 마일스톤 단위, 각 단계 실행 확인, 에러 남긴 채 진행 금지, 프리미티브 적극 사용, 아트/백엔드/PvP/길드/시즌/오픈월드 착수 금지, 불필요한 프레임워크 금지, 측정 없는 최적화 금지.
질문 규칙: 아키텍처 변경, 범위 확대, 핵심 조작 변경, 플러그인/외부 의존성 추가, 세이브 스키마 장기 구조, 네이티브 코드, 에셋 라이선스, 유료 서비스, 리포/브랜치 전략, 되돌리기 어려운 선택은 A/B/(C)/추천/이유를 갖춰 먼저 질문.
