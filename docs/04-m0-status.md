# 진행 상태 (M0 → M1 / Prototype 0.1)

갱신: 2026-09-19 · 브랜치 `godot/main` · Godot 4.7.2 · 테스트 61개 통과

## 단계별 상태
| 단계 | 상태 | 검증 |
|---|---|---|
| 0 프로젝트 골격 | 완료 | 스모크 체크 |
| M0-1 Gun/Swarm + Dash + 벤치마크 | 코드 완료 | 테스트, 헤드리스 실행, Xvfb 스크린샷 |
| M0-2 Gun Feel + 적 3종 + 토글 | 코드 완료 | 테스트, 스크린샷 `docs/shots/m0-2-*.png` |
| M0-1 성능 Gate (200마리, RTX 3070) | **잠정** | `docs/bench/m0-1-gate-provisional.md`. 소프트웨어 GPU에서는 FAIL이나 무효. 드로우콜 13, sim 3.1ms/200 |
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

## 사람이 해야 남는 것
1. RTX 3070에서 F3 벤치마크 → Gate 확정 (`docs/bench/`에 기록)
2. 감각 토글 A/B로 M0-2 재미 판정. 특히 히트스톱 프레임 수, 넉백 5.0(샷건), 카메라 트라우마
3. 첫 플레이테스트 후 결정 C(0.1 탄약), D(실패 규칙 수치) 재확인
4. 결정 H/I → M0.75

## 다음 후보(승인 후)
- M0.75 Android Spike(기기 필요)
- M1.5 Art Performance Slice: 적 1종 프로덕션 품질로 300마리 재측정
- 0.2: Flow Field(통로 뭉침), 탄약/픽업, Elite 접사(StatModifier), 미션 계약 모디파이어, 콤보 카운터
