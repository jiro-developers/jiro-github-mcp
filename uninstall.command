#!/usr/bin/env zsh
# jiro-developers GitHub MCP - 언인스톨 스크립트 (macOS)

set -euo pipefail

finish() {
    print -- ""
    print -- "스크립트가 끝났습니다. 이 창은 Cmd+W (또는 Cmd+Q) 로 직접 닫아주세요."
}
trap finish EXIT

say() { print -- "$1"; }

say "============================================"
say "  jiro-developers GitHub MCP 제거"
say "============================================"
print -- ""

# === 1. 바이너리·설치 디렉터리 삭제 ===
install_dir="$HOME/Library/Application Support/jiro-github-mcp"
if [[ -d "$install_dir" ]]; then
    rm -rf "$install_dir"
    say "✓ 제거됨: $install_dir"
else
    say "ℹ 설치 디렉터리가 없음: $install_dir"
fi

# === 2. Claude Desktop config 에서 github 항목만 제거 ===
config_path="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

if [[ ! -f "$config_path" ]]; then
    say "ℹ Claude Desktop config 가 없음: $config_path"
else
    if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import json' >/dev/null 2>&1; then
        say "✗ python3 가 필요합니다. config 자동 정리를 건너뜁니다."
        say "  수동으로 $config_path 의 mcpServers.github 항목을 지워주세요."
    else
        backup_path="${config_path}.backup-$(date +%Y%m%d-%H%M%S)"
        cp "$config_path" "$backup_path"
        say "✓ 기존 config 백업: $backup_path"

        export _CONFIG_PATH="$config_path"
        python3 - <<'PYEOF'
import json, os, sys

path = os.environ["_CONFIG_PATH"]
try:
    with open(path) as f:
        config = json.load(f)
except json.JSONDecodeError:
    print("✗ config 가 유효한 JSON 이 아닙니다. 수동으로 정리하세요.", file=sys.stderr)
    sys.exit(1)

servers = config.get("mcpServers", {})
if "github" in servers:
    del servers["github"]
    if not servers:
        del config["mcpServers"]
    with open(path, "w") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("✓ config 에서 mcpServers.github 항목 제거")
else:
    print("ℹ config 에 mcpServers.github 항목이 없었음")
PYEOF
        unset _CONFIG_PATH
    fi
fi

print -- ""
say "제거 완료. Claude Desktop을 재시작하면 도구 목록에서 사라집니다."
say ""
say "ℹ GitHub 측에서 PAT 자체를 폐기하려면:"
say "  https://github.com/settings/personal-access-tokens 에서 직접 Revoke."
