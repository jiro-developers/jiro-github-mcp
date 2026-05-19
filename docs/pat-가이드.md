# GitHub Personal Access Token (PAT) 발급 가이드 *(폴백)*

> **이 문서는 폴백용입니다.** 기본은 `setup.command` 가 GitHub App device flow 로 인증을
> 자동 처리하기 때문에 일반 사용자는 이 페이지를 따라할 필요가 없습니다.
>
> 다음의 경우에만 이 가이드를 사용하세요:
> - 조직 정책상 GitHub App 등록이 막혀있는 경우
> - GitHub App 인증이 실패해서 임시로 PAT 우회가 필요한 경우
>
> 정상 흐름은 `docs/github-app-등록-가이드.md` (운영자) + `setup.command` 더블클릭(사용자) 입니다.

Claude Desktop이 GitHub에 접속하려면 본인 계정의 "출입증" 같은 토큰이 하나 필요합니다.
이 토큰을 PAT(Personal Access Token)이라고 부릅니다. 5분이면 끝납니다.

## 0. 사전 준비

- GitHub 계정에 로그인돼있어야 합니다.
- `jiro-developers` 조직의 멤버여야 합니다.

## 1. 발급 페이지로 이동

다음 링크를 클릭하세요:

[https://github.com/settings/personal-access-tokens/new](https://github.com/settings/personal-access-tokens/new)

> 일반 토큰("Tokens (classic)") 말고 **Fine-grained personal access tokens** 페이지로
> 가야 합니다. 위 링크는 자동으로 그쪽으로 보내줍니다.

## 2. 항목 입력

페이지를 위에서 아래로 채워나갑니다.

### Token name
원하는 이름을 적습니다. 본인이 알아볼 수 있으면 충분합니다.

> 예: `claude-desktop-읽기전용`

### Resource owner
드롭다운에서 **`jiro-developers`** 를 선택합니다.

> `jiro-developers` 가 안 보인다면 조직 관리자에게 fine-grained PAT 발급 권한을
> 받아야 합니다. 배포자에게 알려주세요.

### Expiration
**90 days** (또는 사내 표준이 다르면 그쪽 값) 을 선택합니다.

> 만료되면 토큰이 막혀서 Claude Desktop의 GitHub 도구가 동작을 멈춥니다.
> 그때 이 가이드를 다시 보고 새 토큰을 만들어서 `setup.command` 를 다시 실행하면 됩니다.

### Repository access
**"Only select repositories"** 를 선택합니다.

그 아래 "Select repositories" 검색창에서 사용할 레포를 하나씩 추가합니다.
배포자에게 받은 레포 목록을 그대로 추가하세요. (현재 아래 2개)

- `dropshot`
- `dropshot-server`

### Permissions

"Repository permissions" 섹션을 펼치고 아래 항목들을 정확히 다음과 같이 설정합니다.
**Account permissions** 섹션은 아무것도 건드리지 않습니다.

| 항목 | 설정값 |
|---|---|
| Contents | **Read-only** |
| Metadata | **Read-only** (자동으로 같이 켜집니다) |
| Pull requests | Read-only *(선택)* |
| Issues | Read-only *(선택)* |
| 그 외 모든 항목 | **No access** 그대로 |

> 쓰기(Write) 권한은 절대 켜지 마세요. 이 토큰으로 코드 변경/이슈 생성을 할 수
> 없어야 안전합니다.

## 3. 토큰 생성

페이지 맨 아래 **Generate token** 버튼을 누릅니다.

조직 관리자 승인이 필요하다는 메시지가 뜨면, 배포자나 관리자에게 알려서 승인받아 주세요.
승인 후엔 같은 페이지에서 토큰이 활성화됩니다.

## 4. 토큰 복사

토큰이 생성되면 `github_pat_xxxxxxxxxx...` 같은 긴 문자열이 한 번만 표시됩니다.

**오른쪽 끝의 복사 아이콘을 눌러 클립보드에 복사합니다.**

> 이 페이지를 닫으면 다시는 토큰 전체를 볼 수 없습니다. 잃어버리면 처음부터 다시 만들어야 합니다.

## 5. setup.command 실행

토큰을 복사한 상태로 받은 폴더의 **`setup.command`** 를 더블클릭합니다.

- "확인되지 않은 개발자" 경고가 뜨면: Finder 에서 우클릭 → 열기 → "열기" 버튼.
- 안내가 한국어로 진행됩니다.
- 도중에 `PAT:` 입력란이 나오면 **Cmd+V** 로 붙여넣고 **Enter**.
  - 화면에 아무것도 표시되지 않는 게 정상입니다.
- 설치가 끝나면 Claude Desktop을 완전히 종료(Cmd+Q)했다가 다시 켭니다.

## 문제 해결

| 증상 | 조치 |
|---|---|
| "확인되지 않은 개발자" 경고로 실행 안 됨 | Finder에서 setup.command 우클릭 → 열기 |
| `python3 가 필요합니다` 에러 | 터미널 열고 `xcode-select --install` 실행 후 다시 시도 |
| `Resource owner` 에 jiro-developers가 안 보임 | 조직 관리자에게 fine-grained PAT 허용 요청 |
| Claude Desktop 도구 목록에 github 안 보임 | Cmd+Q로 완전 종료 후 재실행. 그래도 없으면 배포자에게 문의 |
