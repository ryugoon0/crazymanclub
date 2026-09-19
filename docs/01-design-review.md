# XENO RECLAIMER — 기획 검토 (STEP 1)

작성일: 2026-09-19
상태: 검토 문서. 코드 없음. 승인 후 Prototype 0.1 구현 착수.

표기 규칙
- **확인 필요**: 내가 사실을 단정할 수 없거나, 당신의 환경/의도에 따라 답이 달라지는 항목.
- **결정 요청**: 구현 전에 당신이 골라야 하는 항목. 문서 끝 "결정 요청 목록"에 모아 두었다.

---

## 0. 리포지토리 / 환경 확인 결과

| 항목 | 확인 내용 |
|---|---|
| 세션 바인딩 리포 | `ryugoon0/move-reservation-mvp` (Next.js + Supabase, 이사예약 MVP). 게임과 무관. |
| 지정 브랜치 | `claude/xeno-reclaimer-design-review-zkt16v` |
| `ryugoon0/crazymanclub` | 공개 리포. Next.js 동호회 사이트(`crazymanclub/` 하위). Godot 자산 없음. 승계할 내용 없음이 맞다. |
| Godot 설치 | 이 원격 컨테이너에는 없음. 구현 단계에서 headless Linux 바이너리를 내려받아 스크립트 검증/테스트에 쓸 수 있는지 **확인 필요**(네트워크 정책). |

**결정 요청 A.** 이 세션은 `move-reservation-mvp`에 묶여 있다. 당신은 `crazymanclub`을 쓰라고 했다. 프로토타입 코드는 어디에 둘지 정해 달라.
- 안 1(권장): `crazymanclub`에 **orphan 브랜치**(예: `godot/main`)를 새로 만들어 기존 Next.js 히스토리와 완전히 분리한 상태로 시작. 기존 `main`은 건드리지 않는다.
- 안 2: `crazymanclub/main`을 통째로 교체. 기존 사이트가 Vercel에 배포 중이면 배포가 깨진다(`vercel.json` 존재). 비권장.
- 안 3: 새 리포(예: `xeno-reclaimer`) 생성. 가장 깔끔하지만 리포 생성 권한이 이 세션에 있는지 **확인 필요**.

이 검토 문서는 우선 지정 브랜치(`move-reservation-mvp`)에 커밋했다. 결정되면 그쪽으로 옮긴다.

---

## 1. 전체 기획 평가

한 줄 평: **"검증할 질문"은 정확하고 좁다. 문서의 나머지 90%는 그 질문과 무관하다.**

좋은 점(짧게):
- 첫 목표를 "수십 마리를 직접 쏘는 게 재미있는가"로 못 박은 것. 이게 이 문서에서 가장 가치 있는 문장이다.
- Data Driven, Placeholder 우선, 과최적화 금지, 구현 금지 목록. 1인 개발에서 살아남는 원칙들이다.
- 난이도 재사용 + Modifier로 콘텐츠 비용을 줄이는 전략. 맵 수 대신 규칙 수로 콘텐츠를 만드는 올바른 방향.

문제점:
1. **문서의 무게중심이 라이브 서비스에 있다.** 31개 섹션 중 프로토타입에 필요한 것은 7, 8, 9, 10, 11, 24, 25, 27, 28 정도다. 나머지는 "나중에 막히지 않게"라는 명목으로 지금의 설계 결정을 오염시킬 위험이 크다. 예: Slayer Level 1000+, 6단계 레어리티, 6부위 Bio, 시즌, 길드 보스는 각각 밸런스 인력이 붙어야 돌아가는 시스템이다. 1인 개발자가 "확장 가능하게 설계"하는 것과 "실제로 그 규모를 운영"하는 것은 다른 문제인데, 문서는 둘을 구분하지 않는다.
2. **모바일 병행이 전제인데 모바일 입력 설계가 비어 있다.** "손맛 = 직접 조준"이 핵심 가치인데, 터치에서 직접 조준 + 대시 + 재장전 + 스킬 4개 + 상호작용은 성립하지 않는다. "PC/모바일 밸런스 차이 최소화"라는 목표와 정면 충돌한다. (→ 위험 3)
3. **Swarm 규모 목표(100~300)와 엔진/언어 선택(GDScript, 모바일)이 검증 없이 동시에 확정돼 있다.** 이건 가정이 아니라 측정으로 확인해야 하는 항목이다. STEP 6에 측정이 들어 있긴 하지만, 순서가 늦다. 측정은 프로토타입 첫 주에 해야 한다. (→ 위험 2)
4. **성장 시스템이 너무 많고 서로 겹친다.** Character Level, Slayer Level, Bio Augmentation(6부위), 무기 강화, 무기 랜덤 옵션, 연구 기술, 용병단. 플레이어가 "강해졌다"를 체감하는 통로가 7개면 어느 것도 체감이 안 된다. 프로토타입 성공 기준 9번("강해진 것을 즉시 체감")과 충돌한다.
5. **IP 리스크가 있는 고유명사가 남아 있다.** "SLAYER LEVEL", "SLAYER CORPS". 원작 제목이 "Alien Slayer"다. 메커니즘만 참고한다는 원칙을 세워 놓고 브랜드 핵심 단어를 가져오는 것은 모순이다. (→ 위험 9)
6. **경제 설계가 없다.** Credit 획득량, 무기 가격, 강화 비용 곡선, 난이도별 보상 배율이 하나도 없다. 프로토타입 성공 기준 7~9번(돈 획득 → 구매 → 체감)은 경제 수치 없이는 검증할 수 없다. 프로토타입에서 필요한 건 스프레드시트 한 장이다.
7. **탄약(Ammo)의 존재 여부가 불명확하다.** "Ammo Crisis" 모디파이어와 "Reload"가 있으니 탄약이 있는 것으로 보이지만, 탄약 경제(드롭, 최대치, 무한 여부)가 정의돼 있지 않다. 이건 전투 손맛에 직접 영향을 주는 결정이다.
8. **"실패"의 정의가 없다.** 플레이어가 죽으면? 리스폰? 미션 실패? 획득물 상실? 탈출 못 하면? 루프의 긴장감은 여기서 나오는데 비어 있다.

결론: 기획은 "라이브 서비스 비전 문서"로는 충분하고 "프로토타입 명세"로는 부족하다. 이 검토의 목적은 후자를 채우는 것이다.

---

## 2. 가장 위험한 요소 10개 (심각도 순)

### 위험 1. 범위 — 1인 개발자가 "라이브 서비스 규모의 확장성"을 설계하면서 프로토타입을 만든다
- 증상: 모든 클래스에 "나중에 길드/시즌/크로스세이브가 붙을 수 있게" 추상화 계층이 들어가고, 3개월 뒤에도 총을 쏘는 화면이 없다.
- 대응: 확장성 고려는 **데이터 스키마(ID, 버전, 저장 형식)에만** 허용한다. 코드 구조는 지금 필요한 만큼만. 13장에서 "지금 반드시" 목록을 아주 짧게 제시했다.

### 위험 2. Swarm 성능 — GDScript + 모바일 + 100~300 마리
- 사실: Godot 4의 `CharacterBody3D.move_and_slide()`, `NavigationAgent3D`, `AnimationTree`를 마리당 하나씩 붙이면 PC에서도 100마리 근처에서 프레임이 무너지는 것이 일반적이다(정확한 수치는 하드웨어와 씬 구성에 따라 다르므로 **측정 필요**). 모바일은 그 1/4~1/3 수준으로 잡아야 한다.
- 대응: 프로토타입 1~2주차에 **벤치마크 씬**을 먼저 만든다(10/30/50/100/200). 적은 처음부터 다음 원칙으로 만든다.
  - 적끼리 물리 충돌 없음(레이어 마스크로 제외). 분리(separation)는 공간 해시 기반 소프트 밀어내기로.
  - 내비게이션 에이전트 없음. 오픈 그레이박스 맵에서는 "플레이어 방향 + 분리 + 장애물 회피 레이캐스트" 조향으로 충분. 좁은 통로 맵이 필요해지면 그때 Flow Field 한 장으로 해결(맵당 1회 계산, 마리당 비용 0).
  - AI 틱 분산(N프레임마다 1회, 거리별 주기 차등).
  - 스켈레탈 애니메이션은 근접 소수만. 원거리/다수는 절차적(스케일/바운스)이나 MultiMesh.
  - 그래도 안 되면 적 시뮬레이션만 GDExtension(C++)로 내린다. 엔진 교체보다 훨씬 싸다.

### 위험 3. 모바일 조작 — "직접 조준"이 핵심인데 터치는 직접 조준에 부적합하다
- 사실: 듀얼 스틱 터치는 정밀 조준이 안 된다. 여기에 대시/재장전/스킬 4개/상호작용/무기 교체를 얹으면 화면이 버튼으로 덮인다.
- 대응(결정 요청 B):
  - 모바일은 "오른쪽 스틱 방향 = 조준 + 스틱을 밀고 있으면 발사"를 기본으로 하고, 조준 보정(aim assist: 각도 스냅)을 데이터로 노출한다. PC는 보정 0.
  - 밸런스 "동일"이 아니라 "동일 데이터 + 플랫폼별 보정 계수"로 목표를 재정의한다.
  - 프로토타입 0.1에서는 모바일 입력을 **구현하지 않는다.** 단, 입력을 `Vector2 move / Vector2 aim / bool fire` 추상으로 받게 만들어 나중에 가상 스틱을 붙일 자리만 남긴다.

### 위험 4. 3D 아트 파이프라인 — 1인 개발자의 최대 시간 흡수원
- 사실: 3D 캐릭터 1종 = 모델링 + UV + 텍스처 + 리깅 + 애니메이션 세트(idle/run/attack/hit/death) 이다. 외계인 3종 + 보스 + 플레이어 + 무기 3종을 혼자 만들면 전투 코드보다 오래 걸린다. AI 이미지 생성은 이 파이프라인의 첫 단계(컨셉)만 도와준다.
- 대응: 프로토타입은 프리미티브로 끝까지 간다(성공 기준 6번 "쾌감"은 이펙트/사운드/카메라로 만든다. 모델로 만들지 않는다). 7장에서 현실적 파이프라인 제시.

### 위험 5. 성장 시스템 과다 — 7개의 성장 축
- 대응: 0.1에서는 **무기 구매 + 무기 강화(1축) + Bio 3부위(1축)** 두 축만. Character Level도 0.1에서는 뺀다(XP 필드는 데이터에 남김). Slayer Level, 연구, 용병단은 문서에서 "미래" 섹션으로 격리.

### 위험 6. 경제/밸런스 수치 부재
- 대응: 구현 전에 `data/economy.md` 한 장(무기 가격, 강화 비용 곡선, 적 1마리당 Credit, 미션 클리어 보너스, 예상 회차별 누적 Credit). 스프레드시트 수준이면 된다. 없으면 성공 기준 7~9번을 판정할 수 없다.

### 위험 7. 로컬 세이브 + 미래 랭킹 = 치팅
- 사실: 로컬 세이브 파일은 누구나 수정한다. 나중에 PvE 랭킹을 붙이면 랭킹 상위가 전부 조작 값이 된다. 서버 검증 없는 랭킹은 없는 것보다 나쁘다.
- 대응: 지금 할 일은 하나뿐이다. 미션 결과를 `RunResult`(시드, 킬 수, 시간, 피해량, 사용 장비 스냅샷) 레코드로 남기는 구조를 만든다. 나중에 서버가 이 레코드를 받아 검증(리플레이 또는 통계적 이상치)할 수 있다. 세이브 파일 암호화는 하지 않는다(효과 없고 디버깅만 어렵다).

### 위험 8. 플랫폼 빌드 현실 — iOS는 macOS 필수
- 사실: Godot iOS 익스포트와 App Store 제출은 macOS + Xcode가 필요하다. 개발 PC가 Windows(RTX 3070)라면 iOS는 별도 장비나 클라우드 Mac 서비스가 필요하다. **확인 필요**: Mac 보유 여부.
- Android: Android SDK/JDK/키스토어 설정과 기기별 Vulkan 호환성 문제(특히 구형/저가 기기). Godot의 `Mobile` 렌더러와 `Compatibility`(OpenGL ES 3) 렌더러 중 선택 필요. 저가 기기까지 노리면 Compatibility가 안전하지만 이펙트/조명 표현이 줄어든다. **결정은 벤치마크 후.**

### 위험 9. IP — "Slayer"
- "Alien Slayer"를 참고한 게임에서 "SLAYER LEVEL", "SLAYER CORPS"를 쓰면 메커니즘 참고를 넘어 브랜드 연상 의도로 보일 수 있다. 상표법상 문제가 되는지는 **확인 필요**(법률 자문 영역)지만, 피할 이유는 충분하고 지킬 이유는 없다.
- 대안: RECLAIMER RANK / RECLAMATION LEVEL, RECLAIMER CORPS / SALVAGE GUILD 등. 프로젝트 자체 브랜드(Reclaim)로 통일하는 것이 오히려 IP를 강화한다.
- Normal/Hard/Nightmare/Hell 명명은 Diablo 계열 관용 표현이라 법적 문제는 낮지만 개성도 없다. 게임 톤에 맞춰 바꿔도 된다(예: Contained / Breached / Overrun / Lost / Abyss).

### 위험 10. Godot 4 모바일/툴링 성숙도
- Godot 4.x는 PC에서 안정적이지만 모바일(특히 Android Vulkan)에서 기기별 문제 보고가 꾸준하다. 광고/결제/푸시 같은 라이브 서비스 SDK 통합은 Unity 대비 플러그인 생태계가 얇다. 지금은 문제가 아니지만, "부분유료화 모바일 라이브 서비스"가 진짜 목표라면 이 비용을 나중에 지불하게 된다.
- 대응: 4장 참고. 지금은 Godot 유지. 단, 결제/광고 SDK가 필요한 시점에 재평가할 것을 문서에 명시.

(보너스 위험 11. **재미 검증 지표 부재.** "재미있는가"를 무엇으로 판정할 것인가? 최소한 세션 길이, 재플레이 횟수, 무기별 사용 비율, 사망 지점 같은 로컬 텔레메트리를 0.1부터 파일로 남겨야 판단이 가능하다. 성공 기준 11번은 지표 없이는 감으로 판정하게 된다.)

---

## 3. 개선 제안 (핵심만)

1. **문서를 둘로 쪼갠다.** `VISION.md`(현재 문서의 장기 내용)와 `PROTOTYPE_0.1.md`(8장의 최종 범위). 코드는 후자만 본다.
2. **입력 추상화.** `InputSource` 계층 하나로 PC/터치/게임패드를 흡수한다(`move: Vector2, aim_dir: Vector2, aim_world: Vector3, fire: bool`). 조준 보정은 데이터 값으로.
3. **Stat/Modifier 시스템을 첫날에 만든다.** 무기 강화, Bio, 미래의 랜덤 옵션, 난이도 Modifier, Elite 접사(affix)가 전부 같은 `StatModifier(stat_id, op, value)` 리스트로 표현된다. 이것 하나가 "확장성"의 80%다. 나머지 확장성은 나중에 해도 된다.
4. **탄약을 넣는다(결정 요청 C).** 이유: 재장전만 있고 탄약이 무한이면 "Ammo Crisis" 모디파이어가 성립하지 않고, 상점/드롭에 긴장감이 없다. 단, 0.1에서는 "미션 내 탄약 픽업 + 주무기 예비탄" 정도의 가벼운 형태.
5. **실패 규칙을 정한다(결정 요청 D).** 권장: 사망 시 미션 실패, 미션 중 획득 Credit의 50%만 보존, Alien Sample은 전량 상실. 탈출(Extraction) 성공 시 전량 보존. 이게 "탈출 슈터"류의 긴장감을 싸게 가져오는 방법이다.
6. **Character Level을 0.1에서 제거.** 성장은 돈으로만. XP는 데이터 필드로 남긴다.
7. **레어리티 6단계 → 초기 3단계.** Normal/Rare/Epic. Legendary 이상은 "고유 효과가 붙는 별도 계층"으로 나중에 추가. 처음부터 6단계면 상위 3단계는 인플레이션 예약이다.
8. **Bio 6부위 → 0.1은 3부위, 정식도 4~5부위 검토.** Spine과 Torso, Brain과 Eyes가 역할이 겹친다.
9. **Slayer Level → 계정 귀속 권장.** 이유: 크로스 세이브/모바일 파견 확인 패턴에서 "계정"이 단위이고, 캐릭터가 1명인 동안 캐릭터 귀속은 의미가 없다. 캐릭터가 여럿이 되면 "계정 단위 총량 + 캐릭터별 배분" 방식(Diablo 3 패러곤과 유사)이 가장 무난하다.
10. **텔레메트리를 0.1에 넣는다.** JSON Lines 로컬 파일. 미션 시작/종료, 사망, 무기 교체, 구매. 20줄이면 된다.

---

## 4. Godot 4를 유지하는 것이 적절한가

**결론: 유지. 단, 조건부.**

유지 근거:
- 무료, 가볍고, GDScript로 반복 속도가 빠르다. 1인 프로토타입에서 "빨리 쏴 보는" 것이 전부인 단계에 맞다.
- Windows/Android 익스포트는 성숙. Resource 기반 데이터(`.tres`)가 Data Driven 요구와 잘 맞고 에디터에서 편집 가능.
- 2D/3D 혼용, 시그널 기반 결합, 씬 조합 방식이 "Manager 남발 금지, 씬 단위 책임" 원칙과 잘 맞는다.
- 라이선스 리스크 없음(MIT). Unity의 2023년 런타임 요금 사태 같은 정책 리스크가 구조적으로 없다.

조건(이 중 하나가 깨지면 재평가):
1. 벤치마크 씬에서 **PC 100마리 60FPS**가 GDScript + 위 최적화 원칙으로 나와야 한다. 안 나오면 먼저 GDExtension으로 적 시뮬레이션만 내린다. 그래도 안 되면 그때 엔진 재평가.
2. Android 중급 기기(예: 3~4년 전 미드레인지, **확인 필요**: 타깃 기기 정의)에서 50마리 30FPS.
3. 결제/광고/푸시 SDK가 필요한 시점(라이브 서비스 착수)에 플러그인 생태계 재평가.

버전: Godot 4.x 최신 안정판. 내 지식 기준 4.4/4.5 계열이 안정판이지만 2026-09 시점의 최신 버전은 **확인 필요**. 프로젝트 생성 시점의 최신 안정판으로 고정하고, 프로토타입 중에는 올리지 않는다.

C#(.NET) 사용 여부: 권장하지 않음. GDScript로 시작한다. Android .NET 익스포트는 지원되지만 iOS는 내 지식 기준 제한적이었다(**확인 필요**). 성능이 문제면 C#보다 GDExtension이 더 확실하다.

물리 엔진: Godot 4.4부터 Jolt가 내장 옵션으로 들어간 것으로 안다(**확인 필요**). 3D 대량 바디에서 기본 GodotPhysics보다 유리하다는 보고가 많다. 벤치마크 씬에서 둘을 비교한다.

---

## 5. 다른 엔진으로 바꿔야 할 이유가 있는가

바꿀 이유가 **생길 수 있는** 조건과, 지금 바꾸지 않는 이유:

| 엔진 | 바꿀 이유 | 지금 바꾸지 않는 이유 |
|---|---|---|
| Unity 6 | 모바일 성숙도(SDK, 기기 호환, 프로파일러), Asset Store(Synty 등 스타일라이즈드 3D 팩), DOTS/Jobs/Burst로 300+ 스웜 처리 용이, 채용/외주 인력 풀 | 무료 티어 매출 한도(내 지식 기준 연 $200k, **확인 필요**), 과거 정책 리스크, 에디터 무겁고 반복 느림, C# 필수, 1인 프로토타입에 과함 |
| Unreal 5 | 그래픽, Niagara | 1인 + 모바일 + 스타일라이즈드 저사양 목표에 정반대. 빌드 시간, 용량, C++/BP 비용 |
| 커스텀/기타 | 없음 | — |

판정: **지금 바꿀 이유 없음.** 유일하게 진지한 대안은 Unity이고, 그 이유는 "300마리 스웜 + 모바일 라이브 서비스 SDK"다. 둘 다 프로토타입 이후 문제다. 프로토타입에서 Godot로 100마리가 검증되면 Godot 유지, 실패하면 그때 GDExtension → Unity 순으로 검토.

엔진 교체 비용을 줄이는 보험: 게임 데이터(무기/적/업그레이드 수치)를 엔진 독립 형식(JSON/CSV)으로도 내보낼 수 있게 `.tres`를 단일 진실로 두되 변환 스크립트를 하나 둔다. 프로토타입에서는 하지 않고, 데이터 종류가 5개를 넘을 때 한다.

---

## 6. 3D Isometric 방식의 장단점

### 장점
- 방향별 스프라이트 시트가 필요 없다. 2D 스프라이트 아이소메트릭은 캐릭터당 8방향 × 애니메이션 종류만큼 그림이 필요하고, 무기 교체까지 반영하면 조합 폭발이 난다. 3D는 모델 1개 + 무기 소켓으로 끝난다.
- 동적 조명, 그림자, 총구 화염 빛, 경고등 점멸이 공짜다. "Stylized Dark Sci-Fi" 무드의 절반은 조명이다.
- 카메라 자유도. 보스전에서 살짝 당기고, 실내에서 살짝 기울이는 것이 파라미터 하나다.
- 피격/넉백/래그돌/파츠 분리 같은 물리적 반응이 자연스럽다.
- 모바일에서 3D 저폴리는 2D 대형 스프라이트 다수보다 오히려 GPU 부담이 적을 수 있다(필레이트 vs 버텍스).

### 단점
- 파이프라인이 무겁다(위험 4). 모델링/리깅/애니메이션 3종 기술이 모두 필요.
- 탑다운 각도에서 가독성이 떨어진다. 실루엣이 약하면 적 3종이 구분되지 않는다. 색/크기/이펙트로 강제 구분해야 한다.
- 스키닝 비용. 100마리 스켈레탈 애니메이션은 모바일에서 무겁다(위험 2).
- 원작류의 "2D 도트 감성"과는 멀어진다. 이건 IP 차별화 측면에서 오히려 장점일 수 있다.

### 권장
- **3D 저폴리 + 플랫/셀 셰이딩 + 최소 텍스처(버텍스 컬러/팔레트 텍스처).** 모델링 난이도와 렌더 비용을 동시에 낮춘다.
- 카메라: `Camera3D` 원근(Perspective), FOV 낮게(25~35°), 피치 약 50~60°, 요 45°. 완전 직교(Orthographic)는 깊이감이 죽고 이펙트가 밋밋하다. 위치 고정 + 플레이어 추적 + 조준 방향으로 약간 오프셋(look-ahead). 값은 데이터.
- 조준: 마우스 → 카메라 레이 → 플레이어 가슴 높이 평면과 교차(`Plane.intersects_ray`). 물리 레이캐스트 불필요.
- 중간 대안(2.5D: 3D 환경 + 빌보드 스프라이트)은 권장하지 않는다. 두 파이프라인을 모두 유지해야 한다.

---

## 7. RTX 3070을 활용한 현실적인 Asset Pipeline

전제: RTX 3070은 VRAM 8GB. SDXL 계열은 원활, 최신 대형 모델(Flux 등)은 양자화(fp8/GGUF)로 돌릴 수 있는 수준. 이미지-투-3D 모델도 소형은 가능.

### 원칙
1. **프로토타입 0.1에서는 AI 에셋을 쓰지 않는다.** 프리미티브 + 컬러 + 이펙트. 아트가 전투 검증을 늦추면 안 된다는 당신의 원칙 그대로.
2. AI는 **컨셉과 텍스처 소재**에 쓴다. 최종 3D 모델은 사람이 만든다(또는 CC0 소스 + 수정).
3. 상용 사용 가능 여부는 도구가 아니라 **모델(가중치) 라이선스**를 봐야 한다.

### 단계별 도구 (무료/로컬 우선)

| 단계 | 도구 | 라이선스 메모 |
|---|---|---|
| 컨셉 아트(외계인, 무기, UI 무드) | ComfyUI + SDXL 계열 체크포인트 | SD 1.5/SDXL 기본 가중치는 CreativeML OpenRAIL-M(상업 가능, 사용 제한 조항 있음). 커뮤니티 파인튜닝 체크포인트는 개별 라이선스 **확인 필요**. Flux.1 dev는 비상업, schnell은 Apache-2.0(내 지식 기준, **확인 필요**). |
| 텍스처/데칼(금속, 녹, 혈흔, 경고 표지) | ComfyUI 타일링 생성 → Material Maker(MIT, 무료) 또는 Blender에서 정리 | 위와 동일 |
| 3D 모델링 | Blender(GPL, 산출물은 자유) | — |
| 이미지→3D 초안 | TripoSR(MIT) 등 소형 모델. 초안 블록아웃 용도로만 | Tencent Hunyuan3D 계열은 라이선스에 지역 제한(내 지식 기준 EU/영국/한국 제외)이 있었음. 한국에서 개발한다면 **사용 전 반드시 확인 필요**. |
| 리깅/애니메이션 | Blender Rigify, Mixamo(Adobe 계정, 무료) | Mixamo 이용약관상 게임 사용 가능으로 알려져 있으나 약관 변경 여부 **확인 필요**. 외계 생물(비인간형)은 Mixamo 부적합 → 직접 리깅. |
| 저폴리 무료 팩(플레이스홀더 이상) | Kenney(CC0), Quaternius(CC0), Godot Asset Library | CC0는 상업 사용 자유 |
| VFX | Godot GPUParticles3D + 셰이더. 텍스처 시트는 AI/직접 | — |
| SFX | jsfxr/sfxr(무료), Freesound(CC 라이선스 개별 확인), 직접 녹음/합성 | CC-BY는 크레딧 표기, CC-NC는 상업 불가 |
| UI 아이콘 | AI 컨셉 → 벡터 정리(Inkscape) | 위와 동일 |

### 법적 주의
- 순수 AI 생성 이미지는 한국/미국에서 저작권 보호가 인정되지 않는 것으로 알려져 있다(**확인 필요**, 법률 자문). 즉 남이 베껴도 막을 수 없다. 최종 에셋은 사람의 수정이 들어가야 한다.
- Steam은 AI 생성 콘텐츠 사용 여부를 스토어 페이지에 공개하도록 요구한다(내 지식 기준, **확인 필요**).
- 학습 데이터 논란이 있는 모델의 산출물을 "그대로" 쓰는 것은 브랜드 리스크. 컨셉 → 직접 제작 파이프라인을 유지하는 이유다.

### 현실적 순서
1. 0.1: 프리미티브.
2. 0.2: 외계인 3종 실루엣을 AI 컨셉 30장 → 3장 선정 → Blender 저폴리(마리당 목표 1~2일) → 절차적 애니메이션(뼈 최소).
3. 0.3: 플레이어/무기 3종 모델, 환경 모듈 키트 10개(벽/바닥/문/파이프/컨테이너), 데칼.
4. 이후: 재사용 가능한 모듈 키트를 늘리는 방향. 맵마다 새 에셋을 만들지 않는다.

---

## 8. Prototype 0.1 범위 최종안

목표 질문: **"수십 마리의 Alien을 직접 총으로 쓸어버리는 것이 재미있는가?"**
목표 플레이 시간: 10~15분(미션 2~3회 반복 포함).

### 포함
| 항목 | 내용 |
|---|---|
| 캐릭터 | 1명, 캡슐. 이동/대시/재장전/사격 |
| 조작(PC) | WASD, 마우스 조준, LMB 사격, Space 대시, R 재장전, E 상호작용, Esc 일시정지 |
| 맵 | 그레이박스 1개(약 60×60m, 장애물 몇 개, 출구/탈출 지점 1개) |
| 무기 | 3종. Assault Rifle(기준), Shotgun(펠릿 다발, 근접 폭발력), Plasma Rifle(느린 투사체, 관통, 높은 피해). Minigun은 예열/열 메커니즘이 추가 시스템이라 제외 |
| 적 | 3종. Runner(빠름/약함), Drone(기준), Tank(느림/강함/넉백 저항). 전부 프리미티브 + 색 |
| 보스 | 1종. Tank 데이터 확장(HP 큼, 돌진 특수기 1개). 새 클래스 아님 |
| 스폰 | 웨이브 데이터 기반. 웨이브 5개 → 보스 → 탈출 |
| 전투 감각 | 히트스톱, 카메라 셰이크, 머즐 플래시(라이트+빌보드), 피격 플래시, 넉백, 사망 시 파츠 튐(프리미티브 파편), 혈흔 데칼(단순), 탄피 없음(0.2) |
| 사운드 | 무기 3종 발사음, 피격음, 사망음, 재장전음. 플레이스홀더(sfxr) |
| 탄약 | 주무기 탄창 + 예비탄. 미션 내 탄약 픽업 |
| 드롭 | Credit(자석 픽업), 탄약. 아이템 드롭 없음 |
| 실패 | 사망 시 미션 실패, Credit 50% 보존(결정 요청 D) |
| 기지(Base) | Control 씬 1개. 상점(무기 구매), 무기 강화(등급 5단계, 단순 % 증가), Bio 업그레이드 3종(Arms: 재장전/반동, Legs: 이속/대시 쿨, Torso: HP/방어) |
| 저장 | JSON, `user://`, 스키마 버전 |
| 텔레메트리 | 로컬 JSONL |
| 벤치마크 씬 | 적 10/30/50/100/200 스폰, FPS/틱 시간 표시 |

### 제외(0.1)
스킬 1~4, 우클릭 보조 공격, Character Level/XP 표시, 아이템 드롭/레어리티/랜덤 옵션, 난이도 선택, 모바일 입력, 미션 선택 화면(미션 1개 고정), 스토리 텍스트, 설정 화면(볼륨 정도만), 컨트롤러.

### 성공 기준(28장 그대로 + 측정 가능하게)
- 1~4: 플레이 테스트 3인 이상 "조작 불편" 없음.
- 5: 동시 50마리에서 PC 60FPS 유지.
- 6: 테스터에게 "한 번 더 할래?" 물었을 때 3인 중 2인 이상 예.
- 7~9: 미션 1회 보상으로 첫 강화 1회 가능, 3회 반복으로 두 번째 무기 구매 가능. 무기 교체 후 킬 속도 차이 체감.
- 10: 보스 처치 → 탈출 → 결과 화면.
- 11: 텔레메트리에서 1인당 미션 3회 이상 자발 반복.

---

## 9. 프로젝트 폴더 / Scene Architecture

Godot 권장 방식은 "기능(feature) 단위로 씬과 스크립트를 같은 폴더에" 두는 것이다. 당신의 예시 구조(`core/ player/ weapons/ ...`)는 거의 그대로 쓸 수 있고, 몇 가지만 손본다.

```
res://
  project.godot
  addons/                 # GdUnit4 또는 GUT (테스트), 그 외 최소
  core/                   # Autoload. 3개를 넘기지 않는다
    events.gd             #   글로벌 시그널 버스 (enemy_died, credits_changed, mission_ended ...)
    profile.gd            #   플레이어 영구 상태 (메모리). Save와 분리
    save_service.gd       #   JSON 직렬화/역직렬화/마이그레이션
  data/                   # .tres 리소스 인스턴스 (콘텐츠). 코드 없음
    weapons/  enemies/  upgrades/  waves/  missions/  economy/
  schema/                 # Resource 클래스 정의 (WeaponData.gd 등). data/가 참조
  entities/
    player/               # player.tscn, player.gd, aim_controller.gd, player_input.gd
    enemies/              # enemy.tscn (공통 1개), enemy.gd, enemy_brain.gd, separation.gd
    projectiles/          # projectile.tscn, hitscan.gd
    pickups/              # credit_pickup.tscn, ammo_pickup.tscn
  combat/                 # health.gd, hurtbox.gd, damage_info.gd, stat_sheet.gd, stat_modifier.gd
  weapons/                # weapon.tscn, weapon.gd (WeaponData를 읽어 동작)
  systems/                # wave_director.gd, spawner.gd, object_pool.gd, loot_dropper.gd, telemetry.gd
  levels/                 # mission_01_greybox.tscn, benchmark.tscn
  flow/                   # main.tscn (씬 전환 루트), base.tscn (기지), mission.tscn (전투 컨테이너), result.tscn
  ui/                     # hud.tscn, shop.tscn, upgrade_panel.tscn, pause.tscn
  fx/                     # camera_shake.gd, hit_stop.gd, muzzle_flash.tscn, blood_decal.tscn, death_burst.tscn
  audio/                  # sfx 파일 + audio_player_pool.gd
  input/                  # input_source.gd, pc_input.gd, (touch_input.gd: 0.2)
  tests/                  # 단위 테스트 (stat_sheet, save 마이그레이션, 경제 계산)
  tools/                  # 에디터 스크립트 (데이터 검증, CSV→tres 등, 필요할 때)
docs/                     # VISION.md, PROTOTYPE_0.1.md, economy.md, 이 문서
```

원 예시와의 차이:
- `data/`(리소스 인스턴스)와 `schema/`(리소스 클래스)를 분리. 콘텐츠 폴더에 코드가 섞이지 않는다.
- `player/ enemies/ items/`를 `entities/` 아래로 모음. `world/` → `levels/`. `missions/` → 흐름은 `flow/`, 데이터는 `data/missions/`.
- `effects/` → `fx/`. `prototype/` 폴더는 두지 않는다. 프로토타입 코드가 "나중에 버릴 코드"가 되면 결국 안 버려지고 본 코드가 된다. 처음부터 본 구조로.
- `systems/`에 Manager 대신 역할 이름을 쓴다(`WaveDirector`, `LootDropper`). "Manager"가 이름에 들어가면 God Object가 되는 경향이 있다.

### Scene Tree (런타임)

```
Main (Node)                          flow/main.tscn — 씬 전환만 담당
├─ [Autoload] Events, Profile, SaveService
├─ CurrentScene (Node)               Base 또는 Mission 중 하나
│
│  Base (Control)                    flow/base.tscn
│  ├─ ShopPanel  ├─ UpgradePanel  ├─ MissionStartButton
│
│  Mission (Node3D)                  flow/mission.tscn
│  ├─ Level (Node3D)                 levels/mission_01_greybox.tscn (인스턴스)
│  │   ├─ Geometry / NavMesh(0.1 없음) / SpawnPoints / ExtractionZone
│  ├─ Player (CharacterBody3D)       entities/player/player.tscn
│  │   ├─ Body(Mesh) ├─ Hurtbox(Area3D) ├─ Health ├─ WeaponMount(Node3D) → Weapon
│  │   ├─ AimController ├─ PlayerInput(InputSource) ├─ DashController
│  ├─ IsoCamera (Camera3D)           fx/iso_camera.tscn (추적 + 셰이크)
│  ├─ WaveDirector (Node)            systems/ — WaveData 읽고 Spawner 호출
│  ├─ Spawner (Node)                 ObjectPool에서 Enemy 꺼내 배치
│  ├─ Enemies (Node3D)               풀에서 나온 적들의 부모
│  ├─ Projectiles (Node3D)
│  ├─ Pickups (Node3D)
│  ├─ FX (Node3D)
│  ├─ HUD (CanvasLayer)              ui/hud.tscn
│  └─ MissionState (Node)            웨이브/보스/탈출 상태 머신, RunResult 생성
│
└─ Overlay (CanvasLayer)             Pause, Result, 화면 전환 페이드
```

책임 규칙:
- `Main`은 씬 로드/언로드만. 게임 로직 없음.
- `Mission`이 전투의 루트. 미션이 끝나면 `RunResult`를 `Events.mission_ended`로 쏘고 `Main`이 `Base`로 전환.
- `Profile`은 영구 데이터의 유일한 메모리 소유자. UI는 `Profile`을 읽고, 변경은 `Profile`의 메서드로만(`spend_credits`, `own_weapon`, `upgrade`). 저장은 `SaveService.save(Profile.to_dict())`.
- `Enemy`는 `EnemyData`를 받아 스스로 설정. 적 종류별 스크립트 없음.
- `Weapon`은 `WeaponData` + `StatSheet`(플레이어 보정 포함)로 최종 수치 계산.

---

## 10. 주요 Class / Resource 설계

### Resource (schema/)
```
WeaponData (Resource)
  id: StringName            # 안정 ID. 표시명과 분리. 절대 변경 금지
  display_name_key: String  # 로컬라이즈 키
  category: WeaponCategory  # enum
  fire_mode: enum {HITSCAN, PROJECTILE}
  damage: float
  rpm: float
  magazine: int
  reserve_max: int
  reload_time: float
  spread_deg: float
  pellets: int              # Shotgun용, 기본 1
  recoil: float
  projectile: ProjectileData (nullable)
  penetration: int
  crit_chance: float
  crit_mult: float
  price: int
  upgrade_curve: UpgradeCurve   # 단계별 비용/보너스
  sfx_fire / vfx_muzzle: 리소스 경로
  (rarity, weight, heat: 필드만 예약. 0.1 미사용)

ProjectileData: speed, lifetime, radius, gravity(0), vfx
EnemyData: id, display_name_key, hp, damage, move_speed, attack_range, attack_cooldown,
           armor, knockback_resist, xp, credit_min/max, loot_table, brain: BrainType,
           special: SpecialAbility (nullable), mesh/color, size
UpgradeData (Bio/Weapon 공용): id, slot (ARMS/LEGS/TORSO/WEAPON), max_level,
           cost_curve: Curve 또는 Array[int], modifiers_per_level: Array[StatModifier]
StatModifier: stat: StringName, op: enum {ADD, MUL, OVERRIDE}, value: float
WaveData: entries: Array[{enemy_id, count, interval, delay}], trigger: enum {TIME, CLEAR}
MissionData: id, level_scene, waves: Array[WaveData], boss: EnemyData, reward_bonus,
           difficulty_modifiers: Array[StatModifier] (0.1 빈 배열)
LootTable: entries: Array[{item_id, weight, min, max}]
EconomyData: credit_scale, death_retain_ratio, 등 전역 상수
```

### 핵심 클래스 (스크립트)
```
StatSheet (RefCounted)       base 값 + StatModifier 목록 → get(stat) 캐시. 플레이어/무기/적 공용
DamageInfo (RefCounted)      amount, source, position, direction, knockback, is_crit, damage_type
Health (Node)                max/current, take(DamageInfo) → damaged/died 시그널. 무적 프레임
Hurtbox (Area3D)             owner 그룹/레이어. Health로 위임
InputSource (Node)           move, aim_dir, aim_world, fire, dash, reload, interact 제공. 구현체: PcInput
Player (CharacterBody3D)     InputSource 소비. 이동/대시 상태. WeaponMount에 현재 Weapon
AimController (Node)         마우스 → 평면 교차 → 조준점. 조준 보정 훅
Weapon (Node3D)              WeaponData + 소유자 StatSheet → 발사/재장전/탄약. Hitscan 또는 Projectile 생성
Projectile (Node3D)          풀링. 매 프레임 레이캐스트 이동(물리 바디 아님). 관통 카운트
Enemy (CharacterBody3D)      EnemyData 적용. EnemyBrain 상태(CHASE/ATTACK/STAGGER/DEAD). 틱 분산
Separation (static)          공간 해시 기반 소프트 분리. Enemies 컨테이너가 1회/프레임 갱신
ObjectPool (Node)            씬별 풀. acquire/release. 적/투사체/픽업/FX 공용
WaveDirector (Node)          MissionData.waves 진행. 보스 트리거. Events.wave_started 등
Spawner (Node)               스폰 포인트 선택 + 풀에서 꺼내 초기화
LootDropper (Node)           Enemy.died → LootTable 굴려 Pickup 스폰
Pickup (Area3D)              자석 흡수. Profile 아닌 MissionState의 임시 지갑에 가산
MissionState (Node)          웨이브/보스/탈출/사망 → RunResult 확정
RunResult (RefCounted)       seed, kills{enemy_id:n}, credits_earned, time, damage_dealt/taken, weapon_id, result
Profile (Autoload)           credits, owned_weapons[], equipped_weapon_id, weapon_levels{}, bio_levels{}, missions_cleared[], version
SaveService (Autoload)       to/from JSON, schema_version, migrate(), 원자적 쓰기(임시 파일 → rename)
Telemetry (Node)             JSONL append
HitStop / CameraShake (Node) 전투 감각. 강도는 WeaponData/EnemyData 값
```

### Input Map
```
move_left / move_right / move_up / move_down   (A D W S, 게임패드 좌스틱)
fire_primary   (LMB)          fire_secondary (RMB, 0.1 미바인딩)
dash           (Space)        reload         (R)
interact       (E)            skill_1..4     (1~4, 0.1 미바인딩, 맵에는 등록)
pause          (Esc)          debug_bench    (F3, 디버그 빌드만)
```
마우스 조준은 액션이 아니라 `AimController`가 마우스 위치를 직접 읽는다. 터치는 0.2에서 `TouchInput`이 같은 `InputSource` 인터페이스를 구현.

### Collision Layer (3D)
```
1  WORLD          정적 지형
2  PLAYER         플레이어 바디 (mask: WORLD)
3  ENEMY          적 바디 (mask: WORLD, PLAYER). 적끼리 충돌 없음
4  PLAYER_HURT    플레이어 Hurtbox (Area)
5  ENEMY_HURT     적 Hurtbox (Area)
6  PLAYER_SHOT    플레이어 투사체/히트스캔 (mask: WORLD, ENEMY_HURT)
7  ENEMY_SHOT     적 공격 판정 (mask: PLAYER_HURT)
8  PICKUP         픽업 (mask: PLAYER)
9  INTERACT       상호작용 (mask: PLAYER)
10 BOSS           보스 전용 필요 시 (0.1 미사용)
```
원칙: 마스크는 최소로. 적-적 충돌은 물리로 하지 않는다(위험 2). 조준 평면은 물리 레이어가 아니라 수학 평면.

### Save Architecture
```
user://saves/profile.json       (원자적 쓰기: profile.json.tmp → rename)
user://saves/profile.bak.json   (직전 버전 1개 보관)
user://settings.json            (볼륨 등, 프로필과 분리)
user://telemetry/YYYYMMDD.jsonl

profile.json
{
  "schema_version": 1,
  "saved_at_unix": 1789000000,
  "account": { "account_id": "local-<uuid>", "created_at_unix": ... },
  "wallet": { "credit": 1200 },                       # 통화는 딕셔너리 (확장)
  "characters": [ {
      "character_id": "c1",
      "equipped_weapon_id": "ar_basic",
      "weapon_levels": { "ar_basic": 2 },
      "bio_levels": { "arms": 1, "legs": 0, "torso": 1 },
      "stats": { "missions_cleared": 3, "kills": 412 }
  } ],
  "inventory": { "weapons": [ { "instance_id": "...", "def_id": "ar_basic", "level": 2, "affixes": [] } ] },
  "progress": { "missions_cleared": ["m01"], "unlocked_difficulties": {"m01": ["normal"]} },
  "runs": [ /* 최근 RunResult N개 */ ]
}
```
규칙:
- **`user://`에서 `Resource`를 `load()`하지 않는다.** Godot의 리소스 로더는 스크립트를 실행할 수 있어 조작된 세이브 파일로 코드 실행이 가능하다. JSON만.
- 콘텐츠는 `def_id`(문자열)로만 참조. 리소스 경로를 저장하지 않는다(경로 이동 시 세이브가 깨진다).
- 로드 시 `schema_version`으로 마이그레이션 함수 체인.
- 캐릭터가 1명이어도 `characters[]`로 시작. 계정/캐릭터 분리는 나중에 되돌리기 가장 비싼 결정이다.
- 클라우드 세이브 대비 필드는 `saved_at_unix`, `account_id` 두 개면 지금은 충분하다. 충돌 해결 정책은 그때.

---

## 11. 개발 순서

당신의 순서(Player Movement → ... → Save)는 타당하다. 두 가지만 바꾼다. **벤치마크를 앞으로**, **전투 감각(feel) 패스를 적 사망 직후에**.

```
 0. 프로젝트 생성, 폴더, Input Map, Collision Layer, Autoload 3개, 테스트 애드온
 1. 그레이박스 레벨 + IsoCamera (추적, 룩어헤드)
 2. Player 이동 + Dash                         ← 성공 기준 1
 3. AimController (마우스 → 평면)                ← 성공 기준 2
 4. StatSheet / StatModifier / DamageInfo / Health (단위 테스트 포함)
 5. WeaponData + Weapon (Hitscan AR 1종) + 머즐 플래시 + 탄약/재장전
 6. EnemyData + Enemy (Drone 1종) + 추적 + 근접 공격 + Hurtbox
 7. ObjectPool + Spawner + 간단 스폰 루프
 8. 사망 처리 + 풀 반환
 9. ★ 감각 패스: 히트스톱, 셰이크, 피격 플래시, 넉백, 사망 파편, SFX 플레이스홀더   ← 성공 기준 6
10. ★ 벤치마크 씬: 10/30/50/100/200 → 프로파일. 여기서 적 구조(물리/분리/틱)를 확정   ← 성공 기준 5
11. Runner, Tank 추가 (데이터만) + Separation
12. Shotgun, Plasma Rifle (투사체 경로)          ← 성공 기준 3
13. Credit/탄약 드롭 + 픽업 + MissionState 임시 지갑
14. WaveDirector + WaveData + 탈출 지점 + 사망/실패 규칙
15. Main/Base/Mission 흐름 전환 + Result 화면 + RunResult
16. Profile + Shop (구매/장착)                   ← 성공 기준 7, 8
17. 무기 강화 + Bio 3종 (UpgradeData → StatModifier)   ← 성공 기준 9
18. Boss (EnemyData 확장 + 돌진 특수기)           ← 성공 기준 10
19. SaveService (JSON, 버전, 원자 쓰기, 테스트)
20. Telemetry + 경제 수치 1차 조정 + 플레이 테스트   ← 성공 기준 11
21. (0.2) TouchInput, Android 빌드, 모바일 벤치마크
```

---

## 12. 첫 번째 구현 Milestone

**M0 — "30마리를 쓸어본다"** (개발 순서 0~10)

포함: 캡슐 플레이어, 이동/대시, 마우스 조준, AR 1종(히트스캔), Drone 1종, 스폰 루프, 사망, 감각 패스, 벤치마크 씬.
제외: 상점, 저장, 보스, 웨이브, 무기 2종, 적 2종.

완료 조건:
1. 실행하면 30초 안에 30마리 이상 스폰되고 전부 죽일 수 있다.
2. PC 100마리 벤치마크에서 60FPS(측정치와 병목을 문서에 기록).
3. 히트스톱/셰이크/넉백/사망 이펙트가 켜고 끌 수 있고, 켠 쪽이 확실히 더 재미있다(당신이 직접 판단).
4. `StatSheet`, `Health`, 세이브 마이그레이션 골격에 단위 테스트가 있다.
5. 자동 검사: `godot --headless --check-only`(스크립트 파싱)와 테스트 러너가 CI 없이 로컬 한 줄로 돈다.

이 마일스톤이 재미없으면 나머지(상점, 성장, 보스)는 재미를 만들어 주지 못한다. 그래서 M0가 먼저다.

**M1 — "루프"** (11~20): 3무기, 3적, 웨이브, 보스, 기지, 상점, 강화, 저장, 텔레메트리. = Prototype 0.1 완성.

---

## 13. Live Service까지 확장할 때 지금 반드시 고려해야 하는 데이터 구조

"지금 반드시"의 기준: **나중에 바꾸면 세이브 마이그레이션이나 전면 리팩터가 필요한 것만.** 그 외는 전부 나중.

1. **안정 ID.** 모든 콘텐츠(무기/적/업그레이드/미션/통화)는 `StringName` ID로 참조. 표시명/경로와 분리. ID는 변경 금지, 폐기 시 `deprecated` 표시.
2. **세이브 스키마 버전 + 마이그레이션 체인.** 첫 릴리스부터.
3. **계정 / 캐릭터 분리.** `account { characters[] }`. 크로스 세이브, Slayer Level(계정 귀속), 파견은 모두 계정 단위.
4. **통화를 딕셔너리로.** `wallet { credit, premium, alien_core, season_token ... }`. 숫자 하나로 시작하면 나중에 전부 손댄다.
5. **아이템은 정의(def)와 인스턴스 분리.** `instance_id, def_id, level, affixes[], seed`. 랜덤 옵션은 `seed`에서 재생성 가능하게 → 세이브 용량과 검증에 유리.
6. **StatModifier 단일 체계.** 강화/Bio/랜덤 옵션/난이도 모디파이어/Elite 접사가 모두 같은 표현. 여기서 갈리면 밸런스 도구를 두 번 만든다.
7. **RunResult 레코드.** 미션 결과를 구조화된 데이터로. 랭킹/검증/텔레메트리/시즌 미션 판정의 원천.
8. **시간은 UTC unix 정수.** 파견(`started_at, duration_s, claimed`), 시즌, 일일 보상 전부. 로컬 시간 저장은 반드시 사고가 난다.
9. **로컬라이즈 키.** 표시 문자열은 처음부터 키(`WEAPON_AR_BASIC_NAME`). 한국어/영어 동시 출시 가능성이 조금이라도 있으면 지금.
10. **텔레메트리 이벤트 스키마.** `{ts, event, session_id, payload}`. 나중에 서버로 보낼 때 형식이 같아야 한다.

지금 하지 않는 것(명시적으로): 서버 인증, 암호화, 클라우드 충돌 해결, 길드 스키마, 시즌 스키마, 결제 영수증, 파견 로직. 위 10개가 지켜지면 이것들은 "추가"이지 "변경"이 아니다.

Backend 비교(프로토타입 후 재검토용, 지금 결정 아님):
- Supabase: 계정/세이브/랭킹 테이블/Edge Function까지 무난. 이미 Next.js 프로젝트에서 써 본 스택. Godot용 공식 SDK는 없고 REST/Realtime을 직접 호출(커뮤니티 플러그인 존재, 품질 **확인 필요**).
- Firebase: 모바일 생태계 강함, Godot 통합은 역시 커뮤니티 플러그인.
- PlayFab/Nakama: 게임 특화(리더보드, 길드, 인벤토리). Nakama는 자체 호스팅 가능.
- 판정 보류. "랭킹 + 클라우드 세이브"만 필요할 때는 Supabase로 충분. 길드 보스/비동기 레이드가 붙으면 게임 특화 백엔드 재검토.

---

## 14. 놓친 아이디어 또는 시스템

1. **탄약 경제와 무기 교체 리듬.** 위에서 다룸. 두 무기 슬롯(주/보조)과 탄약 부족이 무기 교체를 강제하면 "무기별 차별화"가 자연스럽게 체감된다.
2. **탈출 리스크.** 죽으면 잃는 것이 있어야 "귀환"이 이벤트가 된다. Alien Sample 상실 규칙(결정 요청 D).
3. **약점(Weak Point).** Eyes 부위가 "Weak Point"를 언급하는데 약점 시스템 정의가 없다. Tank의 등, 보스의 코어 같은 히트존이 있으면 조준 손맛이 생긴다. 0.2 후보.
4. **Elite 접사.** 난이도 모디파이어와 같은 StatModifier로 "Elite Runner(Fast + Regeneration)"를 만들 수 있다. 콘텐츠 비용 0에 가깝다.
5. **미션 계약(Contract) 랜덤 모디파이어.** 같은 맵을 매번 다른 규칙 조합으로. 로그라이트 요소를 아주 싸게 얻는다. 난이도 재사용 전략의 자연 확장.
6. **킬 콤보/멀티킬 피드백.** 대량 처치 쾌감의 절반은 숫자와 소리다. 콤보 카운터 + 피치 상승 SFX. 구현 비용 낮음.
7. **접근성/조준 보조.** 모바일뿐 아니라 PC에서도 옵션으로. 컨트롤러/Steam Deck 지원 시 필수.
8. **컨트롤러 지원.** Steam 출시 시 Steam Deck 검증을 위해 사실상 필수. InputSource 추상화로 비용 낮음.
9. **데미지 숫자 표시 토글.** 로트 RPG 사용자는 기대한다. 보고 싶지 않은 사람도 있다.
10. **일시정지/설정/재시작 흐름.** 문서에 없지만 0.1 테스트에 필요.
11. **재미 검증 지표.** 텔레메트리(위).
12. **피티(Pity) 시스템.** 랜덤 옵션/레어리티 도입 시 처음부터. 나중에 붙이면 경제 재조정이 필요하다.
13. **적 밀도 연출: "스폰 위치의 의미".** 통풍구, 벽 균열, 바닥 구멍에서 쏟아지는 연출은 프리미티브로도 가능하고 스웜 게임의 정체성이 된다.
14. **환경 위험물(폭발 통, 전기 패널).** 다수 적 처치의 두 번째 축. 무기 외 도구를 하나 준다. 0.2 후보.

---

## 15. 과도하거나 삭제해야 할 요소

| 요소 | 판정 | 이유 |
|---|---|---|
| Slayer Level 1000+ | **보류(정식 이후)** | 무한 성장은 난이도 Modifier 설계를 무력화한다. 파라곤류는 콘텐츠가 고갈된 뒤 붙이는 시스템. 이름도 변경(위험 9) |
| Bio 6부위 | **3~4로 축소** | Spine/Torso, Brain/Eyes 역할 중복 |
| 레어리티 6단계 | **3단계로 시작** | Mythic/Ancient는 인플레이션 예약 |
| Character Level + Slayer Level 이중 레벨 | **하나로** | 성장 축 7개 문제 |
| 연구 기술, 용병단 성장 | **0.x 제외** | 파견과 함께 나중에 |
| 스킬 1~4 | **0.1 제외** | 손맛 검증에 불필요. 총이 재미없으면 스킬은 안 살린다 |
| 우클릭 보조 공격 | **0.1 제외** | 위와 같음 |
| Minigun의 Heat 시스템 | **Plasma Rifle로 대체** | 탄창/재장전과 열 두 체계를 동시에 만들 이유 없음. 무기 카테고리별로 하나만 |
| WeaponData의 weight/heat/rarity | **필드 예약, 미사용** | 데이터에는 남기되 코드가 읽지 않음 |
| 무기 30~100종 목표 | **표현 변경** | "카테고리 9 × 변형"으로. 데이터 드리븐이면 수는 결과이지 목표가 아니다 |
| Star Map 3행성 | **1맵 1미션** | 0.1 |
| 실시간 PvP | **문서에서 "검토 안 함"으로 격상** | "추후 검토"로 남겨두면 아키텍처 논의가 계속 오염된다. 필요하면 그때 문서를 다시 연다 |
| Guild Research/Expedition | **삭제(Guild Boss만 남김)** | 길드 기능 6개는 운영 인력 문제 |
| Open Zone | **비전 문서로 이동** | 미션 기반 구조의 성공이 전제 |
| "PC/모바일 밸런스 동일" | **"동일 데이터 + 플랫폼 보정"으로 재정의** | 위험 3 |
| Cross Save (프로토타입) | **데이터 필드 2개만** | `saved_at_unix`, `account_id` |
| `prototype/` 폴더 | **삭제** | 버릴 코드는 안 버려진다 |

---

## 결정 요청 목록 (구현 전 필요)

| # | 질문 | 내 권장 |
|---|---|---|
| A | 코드를 둘 리포/브랜치 | `crazymanclub`에 orphan 브랜치 `godot/main`. 또는 새 리포 |
| B | 모바일 조준/발사 방식 | 오른쪽 스틱 밀면 발사 + 데이터 기반 조준 보정. 0.1 미구현 |
| C | 탄약 존재 여부 | 있음(탄창 + 예비탄 + 미션 내 픽업) |
| D | 사망/실패 규칙 | 미션 실패, Credit 50% 보존, Sample 전량 상실. 탈출 성공 시 전량 |
| E | "Slayer" 명칭 교체 | Reclaimer 계열로 교체 |
| F | Godot 버전 고정 | 프로젝트 생성 시점 최신 안정판. 프로토타입 중 업그레이드 금지 |
| G | 테스트 프레임워크 | GdUnit4 또는 GUT 중 하나(내 권장: GdUnit4, 단 최신 Godot 호환 **확인 필요**) |
| H | 타깃 Android 기기 기준 | 3~4년 전 미드레인지 1대를 기준 기기로 지정 |
| I | Mac 보유 여부(iOS) | **확인 필요** |

확인 필요로 표시한 사실 항목(내가 단정하지 않은 것): Godot 최신 안정 버전, Jolt 내장 여부/기본값, .NET iOS 지원 상태, Unity 무료 티어 한도, Flux 라이선스, Hunyuan3D 지역 제한, Mixamo 약관, 한국 AI 생성물 저작권, Steam AI 공개 정책, GdUnit4 호환, Supabase Godot 플러그인 품질. 각각 구현 착수 시점에 공식 문서로 확인한다.

---

승인되면 결정 요청 A~H 답에 맞춰 M0(개발 순서 0~10)부터 시작한다.
