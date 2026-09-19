# 인수인계 — 클라우드 세션 → 미니 PC 메인 세션

작성: 2026-09-19, 클라우드 세션(move-reservation-mvp-b7) 종료 시점. 이 문서 하나로 새 세션이 이어받을 수 있어야 한다.

## 현재 상태 한 줄
Prototype 0.1 루프(기지→미션→웨이브 5→보스→탈출→결과→상점/강화/Bio→세이브) 코드 완료. RTX 3070 성능 Gate PASS(200마리 avg 983 fps). 사람 판정 남은 것: 재미(M0-2 감각 토글 A/B).

## 읽을 순서
1. `docs/03-m0-decisions.md` — 확정 결정 A~N, 아키텍처, Gate 정의
2. `docs/04-m0-status.md` — 단계별 상태, 봇 완주 수치, 발견 버그, 다음 후보
3. `docs/01-design-review.md` — 원 기획 검토(배경). `02-gpt-prompt.md`는 참고용
4. `docs/05-remote-machines.md` — 3070/미니 PC Remote Control 연결

## 작업 규칙(사용자 지정, 계속 유지)
- 마일스톤 단위, 각 단계 실행 확인, 에러 남긴 채 진행 금지, 프리미티브 유지, 아트/백엔드/PvP/길드/시즌/오픈월드 착수 금지, 불필요한 프레임워크 금지, 측정 없는 최적화 금지.
- 다음 항목은 A/B/(C)/추천/이유를 갖춰 먼저 질문: 아키텍처 변경, 범위 확대, 핵심 조작 변경, 플러그인/외부 의존성, 세이브 스키마 장기 구조, 네이티브 코드, 에셋 라이선스, 유료 서비스, 리포/브랜치 전략, 되돌리기 어려운 선택.
- 커밋 메시지에 모델명 넣지 않음. 브랜치 `godot/main`(crazymanclub orphan). `main`은 웹 프로젝트라 건드리지 않음.

## 검증 명령 (미니 PC)
```
GODOT=<godot 4.7.2 경로> tools/check.sh      # 스모크 + 61 테스트 (Windows: 각 명령을 직접 실행)
godot --headless --path . --audio-driver Dummy res://tools/autoplay.tscn -- --speed=8 --timeout=300   # 봇 완주
tools\bench_pc.bat 또는 tools/bench_pc.sh     # 3070에서만 의미 있음
```

## 미답 결정
- C(0.1 탄약), D(실패 규칙 수치): 첫 플레이테스트 후
- H(Android 기기 모델), I(Mac 보유): M0.75 진입 조건
- B(모바일 조준 방식): M0.75 전

## 다음 후보(승인 후 하나 선택)
1. M0-2 재미 판정 → 수치 조정(히트스톱 프레임, 샷건 넉백 5.0, 트라우마)
2. M1.5 Art Performance Slice: 적 1종 프로덕션 품질(스켈레톤/그림자) → 300마리 재측정
3. M0.75 Android Spike(기기 필요)
4. 0.2 후보: Flow Field, 탄약/픽업, Elite 접사, 미션 계약 모디파이어, 콤보 카운터

## 두 PC 역할 제안
- 미니 PC(`xeno-minipc`, 항상 켜 둠): 메인 세션. 코드 작성, 헤드리스 테스트, 봇 완주, 문서.
- 3070(`xeno-3070`): GPU/화면 필요한 일만. 벤치마크, 스크린샷, 사람 플레이테스트. 미니 PC 세션이 Remote Control로 3070 세션에 메시지를 보내 작업 요청(둘 다 RC가 켜져 있어야 함).
