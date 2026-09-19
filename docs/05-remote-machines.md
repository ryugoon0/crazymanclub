# 3070 PC / 미니 PC를 Claude Code에 연결하기

기준: 공식 문서 2026-09-19 확인. https://code.claude.com/docs/en/remote-control , https://code.claude.com/docs/en/cross-session-messaging , https://code.claude.com/docs/en/self-hosted-environments-quickstart

## 결론
- claude.ai/code의 "환경(environment)"을 개인 PC로 연결하는 기능(자체 호스팅 환경)은 **Team/Enterprise 전용**이고 **Linux/macOS 호스트만** 지원한다. Pro/Max 개인 계정에서는 불가.
- 개인 PC에서 Claude Code를 돌리고 웹/폰/다른 세션에서 조종하는 공식 방법은 **Remote Control**이다. 모든 플랜 지원, Windows 네이티브 지원. 실행은 그 PC에서 일어나므로 GPU와 화면(Godot 창)을 그대로 쓴다.
- 클라우드 세션(이 세션)은 **Cross-session messaging**으로 PC의 Remote Control 세션에 작업 메시지를 보낼 수 있다(ListAgents/SendMessage). PC 쪽은 첫 수신 시 승인 대화상자가 뜰 수 있다.

## 3070 PC (Windows) 설정
1. Claude Code CLI 설치. 공식 설치 문서: https://code.claude.com/docs/en/setup
2. 리포를 받고 프로젝트 폴더에서 한 번 실행해 로그인·워크스페이스 신뢰를 수락한다.
   ```
   git clone https://github.com/ryugoon0/crazymanclub xeno && cd xeno && git checkout godot/main
   claude          # 처음이면 /login 으로 claude.ai 계정 로그인, 신뢰 대화상자 수락, 그 뒤 종료
   ```
3. 서버 모드로 Remote Control 시작(터미널을 켜 둔 채로 둔다):
   ```
   claude remote-control --name xeno-3070
   ```
   첫 실행 시 `Enable Remote Control? (y/n)` → y. 세션 URL과 QR이 나온다. claude.ai/code 세션 목록에 컴퓨터 아이콘 + 초록 점으로 보인다.
4. 확인: `claude --version`이 2.1.234 이상(Windows 네이티브에서 세션 간 메시징 요구 버전).

## 미니 PC
- Windows면 위와 동일, `--name xeno-minipc`.
- Linux면 동일 명령. 항상 켜 두려면 tmux/screen 안에서 `claude remote-control` 실행.

## 조건 (문서 Requirements)
- Pro/Max/Team/Enterprise. API 키 로그인 불가. `ANTHROPIC_BASE_URL`, `DISABLE_TELEMETRY`, `DO_NOT_TRACK`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`, `DISABLE_GROWTHBOOK`이 설정돼 있으면 안 됨.
- 터미널을 닫으면(Ctrl+C) 폰/웹에서 응답이 멈춘다. 같은 폴더에서 `claude remote-control`을 다시 실행하면 약 4시간 안에는 기존 세션이 복구된다.

## 클라우드 세션 → PC 세션에 일 시키기
- PC에서 RC가 켜진 뒤, 클라우드 세션(이 대화)에 "xeno-3070 세션에 벤치마크 돌리라고 보내" 라고 하면 ListAgents로 찾고 SendMessage로 보낸다.
- PC 쪽 세션은 메시지를 "다른 세션이 보낸 것"으로 받는다. 권한 프롬프트는 PC 쪽 규칙대로 뜬다. 클라우드 세션이 권한 우회 모드면 PC에서 승인 대화상자(기본 5분)가 뜬다.
- 메시지 방향은 문서상 클라우드 → 다른 기기가 지원된다(v2.1.225+). 목록에 보이지 않으면 대안: 브라우저에서 `xeno-3070` 세션을 열어 직접 지시한다.

## 벤치마크 지시문 (PC 세션에 보낼 내용)
```
godot/main 브랜치에서 tools\bench_pc.bat 를 실행하고, 생성된 docs/bench/bench_*_pc.md 를
"bench: RTX 3070 gate run" 메시지로 커밋 후 origin godot/main 에 푸시해. 표와 GATE 줄을 답장으로 보내줘.
```
