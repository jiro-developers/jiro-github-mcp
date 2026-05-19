# jiro-developers GitHub MCP

Claude Desktop 에서 jiro-developers GitHub 레포의 코드를 한국어로 조회할 수 있게 해주는 설치 도구.

비개발자도 GitHub 토큰을 직접 발급하지 않고, 브라우저에서 코드 한 번 입력으로 인증이 끝나도록 설계됨 (GitHub App + Device Flow).

## 셋업

터미널을 열고 (Spotlight → "터미널") 아래 한 줄 붙여넣은 뒤 Enter:

```bash
rm -rf /tmp/jiro-github-mcp && git clone --depth=1 https://github.com/jiro-developers/jiro-github-mcp.git /tmp/jiro-github-mcp && /tmp/jiro-github-mcp/setup.command
```

처음이라면 macOS 가 다이얼로그를 띄울 수 있음:

- **"명령어 라인 개발자 도구 설치"** → 설치 클릭 (5-10분, 1회)

이후 스크립트가 자동으로 브라우저에서 GitHub 인증 화면을 띄움. 표시되는 8자리 코드를 입력하고 "Authorize" 클릭.

"설치 완료" 메시지가 나오면 Claude Desktop 을 Cmd+Q 로 완전 종료한 뒤 다시 실행. 채팅창 도구 목록에 `github` 가 보이면 성공.

## 제거

```bash
/tmp/jiro-github-mcp/uninstall.command
```

또는 이 레포를 받지 않은 상태라면 다시 한 줄:

```bash
rm -rf /tmp/jiro-github-mcp && git clone --depth=1 https://github.com/jiro-developers/jiro-github-mcp.git /tmp/jiro-github-mcp && /tmp/jiro-github-mcp/uninstall.command
```

## 문서

- `docs/사용예시.md` — 설치 후 시도해볼 질문 모음
- `docs/pat-가이드.md` — App 인증이 막힐 때 폴백
- `docs/github-app-등록-가이드.md` — **운영자 전용** (App 등록 절차)
