# 진행 상태 (M0 → M1 / Prototype 0.1)

갱신: 2026-11-06 · 브랜치 `godot/main` · Godot 4.7.2 · 테스트 70개 통과

2026-11-06 클라우드 세션 재검증(Godot 4.7.2-stable Linux, Jolt, 헤드리스): `tools/check.sh` 스모크 OK + 65/65 통과, `tools/autoplay.tscn` 8배속 완주(보스 131.1s, 탈출 174.9s, 킬 189, 크레딧 992+600, best_combo 12, 세이브 ok). 코드 변경 없음.

## 단계별 상태
| 단계 | 상태 | 검증 |
|---|---|---|
| 0 프로젝트 골격 | 완료 | 스모크 체크 |
| M0-1 Gun/Swarm + Dash + 벤치마크 | 코드 완료 | 테스트, 헤드리스 실행, Xvfb 스크린샷 |
| M0-2 Gun Feel + 적 3종 + 토글 | 코드 완료 | 테스트, 스크린샷 `docs/shots/m0-2-*.png` |
| M0-1 성능 Gate (200마리, RTX 3070) | **PASS** | i7-10700F + RTX 3070, Forward+, 1600x900, vsync off: 200마리 avg 981.0 fps, 1% low 150.6. 300마리 avg 736.4, 1% low 108.8. `docs/bench/bench_20260919-135236_pc.md`. 첫 런(`bench_20260919-123413_pc`)의 1% low 열은 계측 아티팩트라 무효 |
| M0-2 재미 판정 | **미판정** | 사람 필요. 사용자 위임("직접 해줘")으로 M1 진행 |
| M1 루프 (웨이브→보스→탈출→결과→기지→상점/강화/Bio→세이브) | **코드 완료** | 헤드리스 autoplay 완주(191킬, 보스, 탈출, 세이브), 스크린샷 `docs/shots/m1-*.png` |
| M0.75 Android Spike | 보류 | 결정 H(기기), I(Mac) 미답 |
| Prototype 0.1 성공 기준 1~11 | 1~5, 7~10 코드상 충족. 6(쾌감), 11(재플레이 욕구)은 사람 판정 | |

## M1에 들어간 것
- 데이터: 미션 m01(웨이브 5개, 약 236마리 + 보스 리인포스먼트 12초마다 Runner 6), Boss Broodmother(5,280 HP, 돌진/내려찍기/소환), Shotgun(5,500), Plasma Rifle(9,500, 투사체+스플래시+관통 1), 무기 강화 5단계(+10% 복리, 1,200→8,000), Bio 3부위 3단계(1,800/3,000/5,000), 경제(사망 시 50% 보존)
- 시스템: WaveDirector, PickupSystem(자석 크레딧), ProjectileSystem, Boss 노드, ExtractionZone, RunResult, Profile/SaveService(JSON, 버전, 원자 쓰기, 백업 복구), Content 레지스트리, Telemetry(JSONL)
- 화면: Base(상점/강화/Bio/출격), Result, Main 흐름. 메인 씬은 `flow/main.tscn`. `flow/mission.tscn`은 F6 단독 실행 가능(Esc 재시작).
- 도구: `tools/autoplay.tscn`(봇 완주 검증), `tools/capture.tscn`(Xvfb 스크린샷)

## 봇 완주 기록 (헤드리스, 8배속, AR +0, Bio 0)
| 항목 | 값 |
|---|---|
| 웨이브 1~5 종료 | 5.8s / 22.7s / 42.3s / 83.0s / 133.4s |
| 보스 처치 → 탈출 | 179.7s → 184.7s |
| 킬 | Drone 74, Runner 106, Tank 10, Boss 1 = 191 |
| 크레딧 | 런 994 + 보너스 600 = 1,594 (봇은 원을 그리며 돌아 젬을 다 못 줍는다) |
| 첫 강화(1,200) | 1회차 후 가능 ✔ |

### 무기별 완주 시간 (같은 봇, 같은 미션)
| 무기 | 완주 | 보스 도달 | 런 크레딧 |
|---|---|---|---|
| Assault Rifle +0 | 185s | 133s | 994 |
| Shotgun +2 | 152s | 110s | 1,144 |
| Plasma Rifle +0 | 106s | 65s | 1,056 |
가격 순서(0 / 5,500 / 9,500)와 위력 순서가 일치한다. "강해진 것을 즉시 체감"(성공 기준 9)의 수치적 근거.

경제 가설 대비: 킬 191/250, 런 크레딧 994/1,500. 사람이 젬을 더 주우면 1,200~1,400 예상. Shotgun(5,500)은 3~4회차. 목표 범위 안.

## 봇이 잡은 버그
- `CharacterBody3D.wall_min_slide_angle` 기본 15° 때문에 벽에 거의 정면으로 걸으면 멈춤 → 0으로. 실제 조작감에 직접 영향.
- 보스 사망 프레임에 해제된 참조 접근 → `is_instance_valid` 가드.
- 관통 투사체가 같은 적을 연속 프레임에 재타격 → 마지막 타격 인덱스 스킵.

## 3070 육안 검증이 잡은 버그
헤드리스 단언으로는 통과하지만 실제로 렌더하면 드러나는 것들. 셋 다 `tools/capture.tscn`으로 재현·확인했다.

- **HUD 콤보 라벨이 한 물리 틱 뒤처짐** → 수정(b5e84df). `Mission._physics_process`가 부모라 `SwarmSim`보다 먼저 돌아서, `hud.set_combo`가 그 틱의 킬보다 먼저 직전 값을 밀어넣었다. 증거: 한 프레임 안에 `KILLS 6`(킬 시점 직접 갱신)와 `COMBO x5`가 공존. 킬 핸들러에서도 밀어주도록 수정.
- **Base/Result 화면이 0×0이라 배경이 그려지지 않음** → 수정. `flow/main.gd`가 화면을 plain `Node` 밑에 붙이는데, `set_anchors_preset(PRESET_FULL_RECT)`는 앵커만 설정하므로 부모 Control 사각형이 없으면 크기가 0으로 남는다. 캡처 도구가 `result rect (0,0) size (0,0) · viewport (1600,900)`을 찍어 확증. 두 화면 모두 `_fit_to_viewport()`로 뷰포트 크기를 직접 받고 `size_changed`에 연결.
- **Result 화면 내용이 중앙 정렬되지 않고 왼쪽이 잘림** → 위 수정으로 해결. 폭 0인 `CenterContainer` 안에서 중앙 정렬하니 가장 긴 줄(`kills ... best combo xN`)이 음수 x로 밀려 첫 글자가 화면 밖으로 나갔다. 매 판 보는 화면이라 눈에 띄는 결함이었다.

스크린샷: `docs/shots/m1-base.png`(수정 후, 1600x900), `docs/shots/m1-result.png`(실제 봇 완주의 진짜 `RunResult`), `docs/shots/m1-combo.png`.
`m1-base.png`는 봇 런 이후 상태(CREDIT 1726, runs 1)다 — 캡처 실행이 `user://` 세이브에 기록되기 때문이며, 상점 루프 참조용으로는 오히려 낫다.

## RTX 3070 Gate 실측 (2026-09-19, xeno-3070 Remote Control 세션이 실행)
`docs/bench/bench_20260919-135236_pc.md` — 계측 수정 후 재측정본.

| enemies | avg fps | 1% low (wall) | frame ms | max ms | sim ms/tick | ticks | gpu ms | draw calls |
|---|---|---|---|---|---|---|---|---|
| 10 | 1635.8 | 525.3 | 0.61 | 3.11 | 0.158 | 1800 | 0.22 | 11 |
| 30 | 1582.5 | 434.1 | 0.63 | 3.53 | 0.532 | 1800 | 0.23 | 12 |
| 50 | 1517.3 | 360.7 | 0.66 | 4.44 | 0.920 | 1800 | 0.23 | 12 |
| 100 | 1330.4 | 253.5 | 0.75 | 5.62 | 1.917 | 1800 | 0.24 | 12 |
| 200 | 981.0 | 150.6 | 1.02 | 8.89 | 4.140 | 1800 | 0.24 | 12 |
| 300 | 736.4 | 108.8 | 1.36 | 13.21 | 6.291 | 1800 | 0.25 | 12 |

해석: GPU 0.22~0.25ms로 적 수와 무관. 비용은 전부 CPU의 sim이고 적 수에 선형(0.158 → 6.291ms/tick, 300마리에서 16.67ms 물리 예산의 38%). 드로우콜 11~12 고정, 메모리 93~94MB 고정. 1% low는 525 → 109로 **매끄럽게 단조 감소하며 절벽이 없다.** 최악 프레임도 13.21ms(75 FPS). 300마리에서도 여유가 크다. 프로덕션 에셋(스켈레톤, 그림자)이 들어가면 GPU 열이 커지므로 M1.5 Art Slice에서 재측정.

### 계측 버그 3건 (첫 런에서 발견, 수정 완료)
첫 런(`bench_20260919-123413_pc`)이 보고한 "300마리에서 1% low 719 → 192 절벽"은 **실제 현상이 아니라 계측 아티팩트였다.** 워크플로 분석(가설 35개, 적대적 검증 3중)과 3070 재측정으로 확인.

1. **1% low가 엔진이 평활화한 delta를 읽었다.** `bench_runner.gd`가 `_process(delta)`의 delta를 기록했는데, Godot는 이 값을 물리 틱에 맞춰 평활화한다. 그 결과 1% low가 `(1/60)/12 = 1.3889ms = 720 fps`에 고정된다. 재측정에서 delta 계열은 719.9 / 720.0 / 719.9 / 720.0 / 714.3 / 252.0으로 **예측대로 720에 핀**, wall-clock 계열은 525 → 109로 매끄럽다. 엔진 지식 없이 리포만으로도 증명된다: 200마리에서 worst-1% 표본은 295프레임인데 물리 틱을 품은 프레임은 1800개이고 tick당 sim만 4.14ms이므로, 보고된 1.3889ms는 산술적으로 불가능하다. → `_wall` 배열(raw `Time.get_ticks_usec()`) 추가.
2. **sim_ms가 물리 틱이 아니라 렌더 프레임마다 샘플링됐다.** `last_step_usec`는 틱마다만 바뀌는데 프레임마다 읽어서, 각 틱이 "그 뒤에 몇 프레임이 따라왔는지"로 가중됐다(10마리 27배 → 300마리 12배). 부하가 오를수록 비싼 스텝이 **과소** 평가되는 방향의 편향. → `sim.frame` 변화 시에만 샘플링. 재측정에서 `ticks`가 전 구간 정확히 1800(30초 × 60Hz).
3. **`main_ms` / `physics_ms`는 평균이 아니라 초당 최댓값이다.** `Performance.TIME_PROCESS` 계열은 1초에 한 번 그 초의 MAX로 갱신된다. 증거: 첫 런의 `main_thread_ms` 1.161 > `frame_ms` 0.617 — 프레임 부분집합의 평균이라면 불가능. → `main_ms_peak` / `physics_ms_peak`로 개명. 이 두 열을 빼서 "non-sim 오버헤드"를 계산하면 안 된다.

avg_fps와 측정 창 길이는 검증 결과 정상이었다(delta/wall 평균이 전 구간 유효숫자 4자리까지 일치, `window_wall_s` 전 구간 30.0). 평활화가 총 시간을 보존하기 때문이며, 손상된 것은 꼬리뿐이다.

**`neighbors()` 배열 할당이 스파이크 원인**이라던 이전 추정은 **근거 없음으로 철회한다.** 그것을 뒷받침하던 유일한 측정치가 계측 아티팩트였다. 해당 호출부는 `max_neighbors = 8`로 상한이 있어 적 수에 선형이고 임계점이 없다. "측정 없는 최적화 금지" 규칙에 따라 손대지 않는다.

## 사람이 해야 남는 것
2. 감각 토글 A/B로 M0-2 재미 판정. 특히 히트스톱 프레임 수, 넉백 5.0(샷건), 카메라 트라우마
3. 첫 플레이테스트 후 결정 C(0.1 탄약), D(실패 규칙 수치) 재확인
4. 결정 H/I → M0.75

## 0.2 진행
- 콤보 카운터: 완료(`combat/combo_tracker.gd`, 커밋 327c2ee). 연속 킬 시간창(1.5s) 트래킹, HUD/결과화면 표시, `RunResult.best_combo` 기록. 테스트 4개 추가(65/65 통과), 헤드리스 봇 완주로 확인(best_combo 14).
  - 3070 육안 검증 완료: `docs/shots/m1-combo.png`. 이 과정에서 **HUD 콤보 라벨이 한 물리 틱 뒤처지는 버그**를 발견·수정했다. `mission.gd`의 `_physics_process`는 부모라 `SwarmSim`보다 먼저 돌고(139행 주석), `hud.set_combo`가 그 틱의 킬보다 먼저 실행돼 직전 값을 밀어넣고 있었다. 증거: 같은 스크린샷에서 `KILLS 6`(킬 시점에 직접 갱신)인데 `COMBO x5`. 킬 핸들러에서도 밀어주도록 한 줄 추가. 표시 전용이라 봇 완주 `best_combo 14`는 변동 없음.

## 아트 드래프트 1차 (2026-11-06): 프로시저럴 로우폴리 바디 + 포트레이트
캡슐/구/박스 플레이스홀더를 5종 캐릭터 바디로 교체했다. 이미지 생성 도구와 사용 가능한 외부 에셋이 없어 **전부 Godot 안에서 절차적으로 생성**(SurfaceTool, 볼록 프리미티브 조립, 플랫 셰이딩)했다. 100% 자체 제작이라 라이선스 문제가 없다. 스타일: Stylized Dark Sci-Fi 로우폴리, 아이소 카메라에서 읽히는 실루엣, 타입 색은 기존 가독성 키 그대로 유지하고 어두운/밝은 톤과 발광 포인트(눈/벤트/바이저)를 더했다.

| 캐릭터 | 삼각형 | 한 줄 묘사 |
|---|---|---|
| Player (`assets/models/player.res` + `player_rifle.res`) | 520 + 136 | 건메탈 장갑에 주황 액센트, 발광 바이저 헬멧, 어깨 패드, 등 파워팩, 오른손 라이플 |
| Drone (600 예산) | 426 | 웅크린 2족 벌레, 큰 디지티그레이드 다리, 낫 팔, 하악, 등 3장 밝은 갑판 |
| Runner (600) | 402 | 낮고 긴 몸, 뒤로 쓸린 긴 다리 6개, 뾰족한 머리, 채찍 꼬리 |
| Tank (900) | 540 | 상체가 큰 역사다리꼴 괴수, 거대한 어깨 패드+가시, 팔뚝 방패, 어깨 사이에 묻힌 작은 머리, 등 발광 벤트 |
| Boss Broodmother (3000) | 1,478 | 알주머니(연분홍 발광) 달린 거대 복부, 아치형 다리 8개, 낫 앞발, 눈 4개, 가시 왕관 |

구조(결정 L-A 유지, 스웜은 타입당 MultiMesh 1개):
- 메시는 **단일 서피스 ArrayMesh**, 원점은 발바닥(y=0), 정면 -Z. `swarm_renderer.gd`는 더 이상 높이의 절반을 올리지 않는다(메시 없는 타입의 대체 캡슐만 올림). 보스 메시 y=1.5 오프셋 제거, 플레이어 씬의 Mesh/Gun/MuzzleFlash 위치를 라이플 위치로 이동(`muzzle_height` 1.14).
- 셰이더 `fx/character.gdshader` 하나를 스웜 MultiMesh·보스·플레이어가 공유. 정점 속성 규약: `COLOR.rgb` = 타입 색에 곱하는 틴트(MultiMesh에서는 인스턴스 색 × 정점 색), `COLOR.a` = 팔레트 색(뼈/건메탈/강철/흰색/알) 블렌드, `UV.x` 발광, `UV.y` 발광 색(타입색 글로우/주황), `UV2.x` 사지 스윙 가중치(부호 = 보행 위상 그룹), `UV2.y` 팔레트 인덱스. `CUSTOM0`은 gl_compatibility에서 셰이더에 도달하지 않아(검증) 쓰지 않는다.
- 인스턴스 데이터: `INSTANCE_CUSTOM.x` 피격 플래시, `.y` 스태거 스쿼시(기존), `.z` 이동량(속도/move_speed), `.w` 보행 Hz(타입별, `move_speed / (2·radius)` 1~8 클램프). 보행은 정점 셰이더의 절차적 흔들림(사지 전후 스윙+들어올림, 발걸음 바운스, 정지 시 호흡)으로 스켈레톤 없음. 드로우콜은 변함없다(타입당 1).
- 포트레이트 `assets/portraits/<id>.png`(256², 3/4 상반신, 키+시안 림 라이트, 그라데이션 배경, 비네트+스캔라인+타입색 액센트 바). Base 화면: 타이틀 옆 플레이어 포트레이트 + 출격 미션의 적 타입/보스 "THREAT INTEL" 스트립. Result 화면: 플레이어 포트레이트 + 적 타입별 포트레이트 카드로 킬 표시. 포트레이트가 없으면 타입색 스와치로 대체(`ui/portraits.gd`).
- 테스트 `tests/test_character_meshes.gd`(5개): EnemyData 메시 존재·단일 서피스·정점 색·삼각형 예산·min y≈0, 풋프린트 비율, 플레이어 메시/총구 위치, 포트레이트 256² 존재 + 누락 시 대체. 총 70개 통과.

재생성:
```
godot --headless --path . -s res://tools/art/build_characters.gd      # 메시 → assets/models/*.res (결정적)
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility \
  --audio-driver Dummy res://tools/art/render_portraits.tscn           # 포트레이트 → assets/portraits/*.png
  # 옵션: -- --lineup=user://lineup.png (아이소 카메라 각도 라인업, 리뷰용) · --only=drone,tank · --out-dir=
godot --headless --path . --import                                       # PNG 임포트
```
스크린샷: `docs/shots/art-draft-lineup.png`(라인업), `art-draft-mission.png`(50마리), `art-draft-boss.png`, `art-draft-base.png`, `art-draft-result.png`, `art-draft-portraits.png`(5장 스트립).
검증(2026-11-06, 클라우드 세션, Godot 4.7.2 Linux):
- `tools/check.sh` 스모크 OK + **70/70** 통과. 봇 완주(헤드리스 8배속): 보스 133.3s, 탈출 178.9s, 킬 190(Drone 73/Runner 106/Tank 10/Boss 1), 크레딧 1,036+600, best_combo 13, 세이브 ok.
- 헤드리스 벤치(`--bench-fast`): sim 0.111 / 0.305 / 0.689 / 1.239 / 2.831 / 4.493 ms/tick (10~300마리), phys peak 2.3~7.6 ms — 렌더 변경은 sim에 영향 없음(예상대로).
- Xvfb+llvmpipe(gl_compatibility, 소프트웨어 래스터) 벤치: 드로우콜 **15~19로 변경 전(HEAD 워크트리 동일 조건 측정)과 동일**. GPU ms는 캡슐 기준 20~25ms 평탄 → 새 바디 20(10마리)~50ms(300마리)로 증가. 소프트웨어 래스터라 정점 수에 선형(캡슐 ~100 tri → 400~540 tri)인 것이며 실제 GPU 수치가 아니다. **3070 재측정(M1.5 Art Performance Slice)이 필요하다**; 2026-09-19 기준 GPU 0.25ms/300마리라 여유는 크다.
- 피격 플래시 상한: 플레이어 0.45(무적 시 미발동), 보스 0.5·감쇠 10/s. 봇 연사(10발/s)에서 보스가 계속 순백으로 떠 몸체가 안 보이던 것을 캡처로 확인하고 조정.

## 다음 후보(승인 후)
- M0.75 Android Spike(기기 필요)
- M1.5 Art Performance Slice: 적 1종 프로덕션 품질로 300마리 재측정 (3070 PC에서만)
- 0.2: Flow Field(통로 뭉침, 측정된 문제 아님 — 실제 뭉침 관찰 후 재검토), 탄약/픽업(결정 C 재결정 필요), Elite 접사(StatModifier), 미션 계약 모디파이어

## Gate 판정 기준 결정 (해결됨)
사용자 결정: **A — 기준을 `low1_wall_fps`로 교체.** 결정 M-2로 `docs/03-m0-decisions.md`에 기록. `tools/bench_runner.gd`의 `gate_ok`와 리포트 문구를 wall-clock 계열 기준으로 수정 완료. 200마리 PASS는 그대로 유효(wall 1% low 150.6, 기준 45의 3.3배).
