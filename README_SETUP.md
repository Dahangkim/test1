# 제주 유흥주점 실태조사 대시보드 Supabase 설정

## 핵심 요약

이 폴더는 GitHub Pages에서 동작하는 정적 HTML/JS 구조입니다. Supabase는 제보 저장, 승인 제보 공개 조회, 관리자 검토 기능에만 사용합니다.

실제 `config.js`에는 Supabase URL과 anon key가 들어가므로 공개 저장소에 커밋하지 마세요.

## 파일 구성

- `jeju-research-dashboard.html`: 공개 대시보드
- `admin.html`: 관리자 제보 검토 페이지
- `js/supabase-client.js`: Supabase 클라이언트 초기화
- `js/reports.js`: 제보 접수, 승인 제보 조회, 관리자 처리 로직
- `config.example.js`: 설정 예시
- `supabase_schema.sql`: 테이블, RLS 정책, 관리자 권한 설정

## 설정 순서

1. Supabase 프로젝트를 만듭니다.
2. Supabase SQL Editor에서 `supabase_schema.sql` 내용을 실행합니다.
3. Supabase Auth에서 관리자 이메일 계정을 만듭니다.
4. `auth.users`의 관리자 `user_id`를 확인한 뒤 `admin_profiles`에 추가합니다.
5. `config.example.js`를 복사해 `config.js`를 만들고 실제 값을 입력합니다.
6. GitHub Pages에 올릴 때 `config.js`가 공개 저장소에 커밋되지 않도록 `.gitignore`에 추가합니다.

## config.js 예시

```js
window.JEJU_DASHBOARD_CONFIG = {
  supabaseUrl: "https://YOUR-PROJECT.supabase.co",
  supabaseAnonKey: "YOUR_SUPABASE_ANON_KEY"
};
```

## 개인정보 및 내부자료 주의

상담기록, 내담자 개인정보, 사건 관계자 식별정보, 내부 회의자료, 비공개 조사자료를 공개 저장소나 공개 제보 데이터에 넣지 마세요.

제보 폼의 `reporter_contact`는 관리자 검토용입니다. 공개 대시보드는 `status='approved'`인 제보만 읽으며, 연락처와 관리자 메모는 공개 조회 컬럼에 포함하지 않습니다.

## 관리자 상태값

- `pending`: 접수
- `reviewing`: 검토 중
- `approved`: 공개 승인
- `rejected`: 반려
- `private`: 비공개 보관

## 위험요소

- anon key는 공개되어도 되는 키이지만, RLS 정책이 잘못되면 데이터가 노출될 수 있습니다.
- `reporter_contact`에는 개인정보가 들어갈 수 있으므로 보존 기간과 접근 권한을 별도로 정하세요.
- 공개 승인 전에 상담기록, 개인정보, 내부자료 포함 여부를 반드시 확인하세요.
