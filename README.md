# XENO RECLAIMER

Kill. Salvage. Evolve. Reclaim.

Isometric 3D action RPG / twin-stick shooter prototype. Godot **4.7.2-stable**, GDScript.

이 브랜치(`godot/main`)는 `crazymanclub` 리포의 orphan 브랜치로, 기존 웹 프로젝트(`main`)와 히스토리를 공유하지 않는다.
나중에 별도 리포로 옮길 때는 `git push <new-remote> godot/main:main` 으로 히스토리를 그대로 가져간다.

## 현재 단계
M0-1 구현 중(총/스웜/Dash/벤치마크). 결정 사항은 `docs/03-m0-decisions.md`.

## 조작 (M0-1)
WASD 이동 · 마우스 조준 · 좌클릭 사격 · Space 대시 · R 재장전 · Esc 재시작 · F3 벤치마크 씬
게임패드: 왼쪽 스틱 이동 · 오른쪽 스틱 조준(밀면 발사) · RT 사격 · A 대시 · X 재장전

## 실행
- 에디터: Godot 4.7.2에서 `project.godot` 열기.
- 헤드리스 스모크 체크:
  ```
  godot --headless --path . --import
  godot --headless --path . -s res://tools/smoke_check.gd
  ```
- 단위 테스트(GdUnit4) / 전체 게이트:
  ```
  GODOT=/path/to/godot tools/check.sh
  ```
- 벤치마크(결정 M, 화면 있는 PC에서):
  ```
  godot --path . res://levels/benchmark.tscn -- --bench-quit
  ```
  결과는 콘솔과 `user://bench/bench_<unix>.csv`. `--bench-fast`를 붙이면 각 수량 2초만 측정(스모크용).

## 폴더
```
core/      Autoload (Events만)
schema/    Resource 클래스 정의 (WeaponData, EnemyData, StatModifier ...)
data/      .tres 콘텐츠 인스턴스. 코드 없음
combat/    StatSheet, DamageInfo, Health
swarm/     SwarmSim, SpatialHash, SwarmRenderer, SwarmSpawner
entities/  player/ (Node 기반 개체)
weapons/   Weapon
levels/    그레이박스, 벤치마크
flow/      mission.tscn (M0 루트)
fx/ audio/ input/ ui/ tools/ tests/ docs/
```

## 원칙
- 콘텐츠와 로직 분리. 숫자는 `.tres`에.
- Autoload는 `Events` 하나.
- 일반 적은 Node가 아니다 (중앙 배열 시뮬레이션 + MultiMesh).
- 측정 없는 최적화 금지.
