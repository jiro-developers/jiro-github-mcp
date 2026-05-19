# GitHub App 등록 가이드 (운영자 전용)

비개발자 사용자가 PAT을 직접 발급하지 않아도 되게 하려면, 운영자(너)가 jiro-developers organization에 GitHub App을 한 번 등록해두면 된다. 등록 후엔 사용자는 브라우저에서 코드 한 줄 입력만 하면 인증 끝.

> 이 가이드는 **운영자 1회용**. 일반 사용자가 따라할 필요는 없다.

## 0. 준비물

- jiro-developers organization owner 권한, 또는 owner 승인 약속.
- 약 15분.

## 1. GitHub App 생성 페이지로 이동

[https://github.com/organizations/jiro-developers/settings/apps/new](https://github.com/organizations/jiro-developers/settings/apps/new)

> "Owner: jiro-developers" 가 자동으로 잡힌 페이지로 가야 한다. URL이 `organizations/jiro-developers/settings/apps/new` 인지 확인.

## 2. 기본 정보 입력

| 항목 | 값 |
|---|---|
| **GitHub App name** | `jiro-developers-claude-mcp` (이름은 GitHub 전역 유일, 안 되면 뒤에 -001 같은 suffix) |
| **Description** | `Claude Desktop 에서 jiro-developers 레포 자연어 조회를 위한 read-only App` |
| **Homepage URL** | `https://github.com/jiro-developers` (정상 동작하는 URL이면 됨) |

## 3. Identifying and authorizing users 섹션

- **Callback URL**: 비워둠 (device flow만 쓸 거니 불필요)
- **Expire user authorization tokens**: **체크 해제 (중요!)**
  - 체크돼 있으면 8시간마다 만료되어 사용자가 다시 인증해야 함
  - 해제하면 토큰이 영구 (PAT 처럼 동작)
- **Request user authorization (OAuth) during installation**: 체크 해제 (device flow 쓸 거라 불필요)
- **Enable Device Flow**: **체크 (중요!)**

## 4. Post installation 섹션
- 모두 비워둠.

## 5. Webhook 섹션
- **Active**: **체크 해제**. webhook 받을 일 없음.

## 6. Repository permissions 섹션

읽기 전용만 켠다. 그 외 모든 항목은 **No access** 그대로.

| 항목 | 값 |
|---|---|
| **Contents** | Read-only |
| **Metadata** | Read-only (Contents 켜면 자동) |
| **Pull requests** | Read-only *(선택 — 이슈/PR 조회도 허용하려면)* |
| **Issues** | Read-only *(선택)* |

## 7. Organization permissions / User permissions 섹션
- 둘 다 전부 **No access** 그대로.

## 8. Where can this GitHub App be installed?
- **Only on this account** 선택. organization 내부 전용.

## 9. Create GitHub App

페이지 맨 아래 **Create GitHub App** 클릭.

## 10. Client ID 확보

생성된 App의 General 페이지에서 두 값을 메모:

| 항목 | 위치 | 메모할 위치 |
|---|---|---|
| **Client ID** | "About" 섹션 상단 | `setup.command` 의 `GITHUB_CLIENT_ID` 변수에 그대로 붙여넣기 |
| App slug | 페이지 URL의 마지막 부분 | 참고용 (코드엔 안 들어감) |

> Client secret 은 **device flow 에서 필요 없다**. 발급/저장 안 해도 됨.

## 11. Organization 에 App 설치

같은 페이지 좌측 사이드바 → **Install App** → jiro-developers 옆 **Install** 클릭.

설치 화면에서:
- **Repository access**: **Only select repositories** → 사용자에게 노출할 레포 추가
  - `dropshot`
  - `dropshot-server`
  - (필요 시 추가)
- **Install** 클릭.

## 12. setup.command 에 Client ID 채우기

`setup.command` 를 텍스트 에디터로 열고 상단의

```bash
GITHUB_CLIENT_ID=""   # ← GitHub App 의 Client ID 를 여기에 (Iv23li... 또는 Iv1.... 형태)
```

이 줄에 Client ID 를 큰따옴표 안에 붙여넣는다.

저장 후 본인 머신에서 한 번 검증 (`./setup.command` 실행 → device flow 진행 → Claude Desktop 도구 등록 확인) 한 뒤에 zip으로 묶어 사용자에게 배포.

## 13. 사용자 권한 부여 시 화면 흐름 (참고)

사용자가 `setup.command` 를 실행하면 브라우저가 열리고 다음 화면이 나옴:

1. **GitHub 로그인** (이미 로그인돼있으면 생략)
2. **"jiro-developers-claude-mcp wants to access your GitHub account"** 같은 화면
3. **"Authorize"** 클릭
4. 사용자 본인 외에 jiro-developers organization 으로의 권한 부여가 추가로 표시될 수 있음. 모두 Authorize.
5. "Device activated" 메시지 → setup.command 가 자동으로 토큰 수령

## 트러블슈팅

| 증상 | 원인 / 조치 |
|---|---|
| 사용자 인증 후에도 jiro-developers 레포가 안 보임 | App 설치 시 레포 선택을 안 했거나 사용자가 organization 멤버 아님. Install App 페이지에서 레포 추가/확인 |
| "Device Flow not enabled" 에러 | App 설정 3번 단계의 Enable Device Flow 가 꺼져있음. 재설정 |
| 토큰이 8시간 후 만료됨 | App 설정 3번의 "Expire user authorization tokens" 가 켜져있음. 끄고 사용자가 재인증 |
| Client ID 형식이 `Iv1...` vs `Iv23...` | 둘 다 정상. 시기에 따라 형식이 바뀜. 그대로 사용 |
