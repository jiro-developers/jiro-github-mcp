#!/usr/bin/env python3
"""
github-mcp-server wrapper for jiro-developers.

Claude Desktop 과 공식 github-mcp-server 사이에서 MCP JSON-RPC 메시지를
패스스루 하면서 두 가지만 손댄다:

  1. `initialize` 응답에 server-level instructions 주입
     → 클라이언트(Claude)가 시스템 프롬프트에 포함시킴.
  2. `tools/list` 응답의 각 도구 description 뒤에 default owner 안내 추가
     → 도구 선택 시 Claude가 owner 인자에 `jiro-developers` 를 기본으로 사용하게 유도.

사용자가 다른 owner 를 명시한 경우엔 그쪽을 우선하도록 instructions 에 명시.

기대 환경:
  - 환경변수 JIRO_GITHUB_MCP_BIN: 공식 github-mcp-server 바이너리 절대경로.
  - 그 외 env (GITHUB_PERSONAL_ACCESS_TOKEN 등) 는 그대로 자식 프로세스에 전달.
"""

import json
import os
import subprocess
import sys
import threading

DEFAULT_OWNER = "jiro-developers"

SERVER_INSTRUCTIONS = f"""\
이 GitHub MCP 서버는 `{DEFAULT_OWNER}` organization 전용 도구다. 다음 규칙을 **반드시** 지켜라.

규칙 1 — 기본 owner는 `{DEFAULT_OWNER}` 다.
사용자가 owner/organization을 명시하지 않은 모든 GitHub 관련 요청은 owner = `{DEFAULT_OWNER}` 로 해석하고 곧장 도구를 호출한다.
다른 organization을 시도하거나 "여러 곳에 있을 수 있다", "어떤 organization인지 묻겠다" 같은 망설임을 출력하지 않는다.

예시:
- "dropshot 레포의 README 보여줘"
  → 곧장 owner=`{DEFAULT_OWNER}`, repo=`dropshot` 으로 get_file_contents 호출.
- "어제 머지된 PR 알려줘"
  → 곧장 owner=`{DEFAULT_OWNER}` 범위로 검색.

규칙 2 — 사용자가 명시적으로 다른 owner 를 지정한 경우만 그 owner 를 쓴다.
명시적의 정의: `octocat/Hello-World` 처럼 슬래시 형식, 또는 `https://github.com/foo/bar` URL, 또는 문장에 "X 조직의" 라고 쓴 경우.

규칙 3 — 검색 도구도 동일하다. owner 를 못 받는 검색 함수에는 query 에 `org:{DEFAULT_OWNER}` qualifier 를 기본으로 포함시킨다.
"""

OWNER_HINT = (
    f" [필수] owner 인자를 사용자가 명시하지 않았다면 반드시 `{DEFAULT_OWNER}` 를 사용. 다른 organization 을 추측하지 말 것."
)


def patch_message(msg):
    """Mutate an outgoing MCP message in place; return the (possibly modified) msg."""
    if not isinstance(msg, dict):
        return msg

    result = msg.get("result")
    if not isinstance(result, dict):
        return msg

    # 1. initialize 응답: serverInfo + protocolVersion 가 있는 경우
    if "serverInfo" in result or "protocolVersion" in result:
        existing = result.get("instructions") or ""
        if DEFAULT_OWNER not in existing:
            result["instructions"] = (existing + "\n\n" + SERVER_INSTRUCTIONS).strip()

    # 2. tools/list 응답: result.tools 가 list 인 경우
    tools = result.get("tools")
    if isinstance(tools, list):
        for tool in tools:
            if not isinstance(tool, dict):
                continue
            desc = tool.get("description")
            if isinstance(desc, str) and DEFAULT_OWNER not in desc:
                tool["description"] = desc.rstrip() + OWNER_HINT

    return msg


def forward_stdin_to(proc):
    try:
        for line in sys.stdin.buffer:
            proc.stdin.write(line)
            proc.stdin.flush()
    except BrokenPipeError:
        pass
    finally:
        try:
            proc.stdin.close()
        except Exception:
            pass


def forward_stdout_from(proc):
    try:
        for raw in proc.stdout:
            line = raw.decode("utf-8", errors="replace")
            stripped = line.strip()
            if not stripped:
                sys.stdout.write(line)
                sys.stdout.flush()
                continue
            try:
                msg = json.loads(stripped)
            except json.JSONDecodeError:
                # 알 수 없는 형식은 그대로 통과
                sys.stdout.write(line)
                sys.stdout.flush()
                continue
            patched = patch_message(msg)
            sys.stdout.write(json.dumps(patched, ensure_ascii=False) + "\n")
            sys.stdout.flush()
    except BrokenPipeError:
        pass


def main():
    server_bin = os.environ.get("JIRO_GITHUB_MCP_BIN", "").strip()
    if not server_bin or not os.path.isfile(server_bin):
        sys.stderr.write(
            "jiro-github-mcp wrapper: JIRO_GITHUB_MCP_BIN 환경변수가 비어있거나 "
            f"파일을 찾지 못함: {server_bin!r}\n"
        )
        sys.exit(1)

    proc = subprocess.Popen(
        [server_bin, "stdio"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        # stderr 는 그대로 inherit → Claude Desktop 로그에 그대로 보임
        env=os.environ.copy(),
    )

    t_in = threading.Thread(target=forward_stdin_to, args=(proc,), daemon=True)
    t_out = threading.Thread(target=forward_stdout_from, args=(proc,), daemon=True)
    t_in.start()
    t_out.start()

    rc = proc.wait()
    sys.exit(rc)


if __name__ == "__main__":
    main()
