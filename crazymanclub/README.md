# CrazyManClub 신수교감 출석판

## 기능
- 회원가입 시 닉네임 선택
- 로그인 후 스크린샷 업로드
- 로그인 계정의 닉네임으로 자동 출석 처리
- 운영진 화면에서 회원 승인, 스크린샷 로그 확인, 승인/반려
- 날짜별 출석판 및 카카오톡 공유용 텍스트

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
