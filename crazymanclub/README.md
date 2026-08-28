# CrazyManClub 신수교감 출석판

## 기능
- 회원가입 시 닉네임 선택
- 로그인 후 스크린샷 업로드
- 로그인 계정의 닉네임으로 자동 출석 처리
- 운영진 화면에서 회원 승인, 스크린샷 로그 확인, 승인/반려
- 날짜별 출석판 및 카카오톡 공유용 텍스트
- `/game` 광인회 방치형 레이드 (모바일 세로 화면 전용 미니게임)

## 광인회 방치형 레이드 (`/game`)

서버·로그인 없이 브라우저 `localStorage` 만으로 동작하는 방치형 게임입니다.

- **난이도 3종** — 평온 / 광기 / 광인. 몬스터 체력, 보스 제한시간, 골드와
  환생 보상(광기석)이 함께 바뀝니다. 난이도를 바꾸면 회차가 초기화됩니다.
- **자동 전투 + 탭** — 동료 10명이 자동으로 싸우고, 몬스터를 탭하면 추가
  피해를 줍니다. 탭 피해에는 총 DPS 의 8% 가 더해져 후반에도 의미가 있습니다.
- **스테이지 / 보스** — 일반 몬스터 10마리를 잡으면 보스가 등장하고,
  제한시간 안에 못 잡으면 3마리를 더 잡고 재도전합니다.
- **환생(광기석)** — 스테이지 30 이상에서 회차를 정리하고 광기석을 얻습니다.
  광기석 1개당 모든 피해 +5%, 골드 획득 +3% 가 영구 적용됩니다.
- **오프라인 보상** — 최대 8시간, 효율 55% 로 자리를 비운 동안의 골드를
  정산합니다.

밸런스는 `app/game/engine.ts` 상단 상수로 모여 있습니다. 표준 난이도 기준
방치만 했을 때 S30 약 5분, S80 약 21분, S100 약 56분에 도달하고 1회차
2시간이면 대략 S108 에서 벽에 부딪히도록 맞춰져 있습니다.

## 배포 순서

### 1. Supabase SQL 실행
Supabase Dashboard → SQL Editor → `supabase/schema.sql` 전체 실행

### 2. 최초 운영진 만들기
웹에서 본인 계정 회원가입 후 SQL Editor에서 실행:

```sql
update public.profiles
set role='admin', approved=true
where email='본인이메일@example.com';
```

### 3. GitHub 업로드

```bash
git clone https://github.com/ryugoon0/crazymanclub.git
cd crazymanclub
# 이 ZIP 안의 파일을 전부 복사
git add .
git commit -m "Initial CrazyManClub attendance app"
git push
```

### 4. Vercel 환경변수
Vercel Project → Settings → Environment Variables

```env
NEXT_PUBLIC_SUPABASE_URL=https://fqunsdthpazctpkqtzel.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_dooeMd1phVkEcxDXFnVoHA_ZbykrOQd
```

### 5. Vercel Redeploy
Vercel → Deployments → Redeploy
