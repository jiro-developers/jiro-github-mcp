#!/usr/bin/env zsh
# jiro-developers GitHub MCP - 비개발자용 셋업 스크립트 (macOS 12+)
# Finder에서 더블클릭하면 Terminal에서 자동 실행된다.
#
# 인증: GitHub App + Device Flow.
# 비개발자는 PAT을 직접 발급할 필요 없이 브라우저에서 코드 입력만 하면 된다.

set -euo pipefail

# ============================================================
# 운영자 설정: GitHub App 등록 후 Client ID 를 여기에 채워라
# 가이드: docs/github-app-등록-가이드.md
# ============================================================
GITHUB_CLIENT_ID="Iv23li73JWDV5IlLlh1q"   # jiro-developers App ID 3721094

# Finder 더블클릭 시 Terminal 이 스크립트 종료 후에도 창을 유지하므로
# (macOS Terminal 기본 동작) 에러 메시지를 읽을 시간이 충분하다.
# 종료 시 한국어 안내만 출력하고 사용자가 Cmd+W 로 직접 닫게 한다.
finish() {
    print -- ""
    print -- "스크립트가 끝났습니다. 이 창은 Cmd+W (또는 Cmd+Q) 로 직접 닫아주세요."
}
trap finish EXIT

say() { print -- "$1"; }

say "============================================"
say "  jiro-developers GitHub MCP 설치"
say "============================================"
print -- ""
say "Claude Desktop 에서 GitHub 레포를 자연어로 조회할 수 있게 설정합니다."
say "중단하려면 Ctrl+C 를 누르세요."
print -- ""

# === Client ID 체크 ===
if [[ -z "$GITHUB_CLIENT_ID" ]]; then
    say "✗ 운영자 설정 누락: setup.command 의 GITHUB_CLIENT_ID 가 비어있습니다."
    say "  운영자는 docs/github-app-등록-가이드.md 의 12번 단계를 확인하세요."
    exit 1
fi

# === 사전 조건 ===
macos_major=$(sw_vers -productVersion | cut -d. -f1)
if (( macos_major < 12 )); then
    say "✗ macOS 12 이상이 필요합니다. 현재: $(sw_vers -productVersion)"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import json' >/dev/null 2>&1; then
    say "✗ python3 가 필요합니다."
    say "  터미널에서 다음 명령을 실행 후 다시 시도하세요:"
    say "    xcode-select --install"
    say "  (설치 다이얼로그가 나타나면 '설치'를 누르세요. 5-10분 소요)"
    exit 1
fi

# === 아키텍처 ===
case "$(uname -m)" in
    arm64)  asset_arch="Darwin_arm64" ;;
    x86_64) asset_arch="Darwin_x86_64" ;;
    *)
        say "✗ 지원하지 않는 아키텍처: $(uname -m)"
        exit 1
        ;;
esac
say "✓ 아키텍처: $(uname -m)"

# === 설치 위치 ===
install_dir="$HOME/Library/Application Support/jiro-github-mcp"
bin_dir="$install_dir/bin"
mkdir -p "$bin_dir"
say "✓ 설치 위치: $install_dir"

# === 임시 작업 디렉터리 ===
tmpdir=$(mktemp -d)
cleanup_tmp() { rm -rf "$tmpdir"; }

# === 최신 릴리스 메타 ===
print -- ""
say "최신 github-mcp-server 릴리스 정보를 가져오는 중..."
repo="github/github-mcp-server"
version=""
asset_url=""
checksums_url=""

# 인증 없는 GitHub API 는 IP 당 시간당 60회 제한이라 공유망에서 쉽게 소진된다.
# 토큰이 있으면 5000회/시간으로 올라가므로 있으면 붙여서 호출한다.
gh_token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
if [[ -z "$gh_token" ]] && command -v gh >/dev/null 2>&1; then
    gh_token=$(gh auth token 2>/dev/null || true)
fi

release_json="$tmpdir/release.json"
api_args=(-fsSL)
if [[ -n "$gh_token" ]]; then
    api_args+=(-H "Authorization: Bearer $gh_token")
fi

if curl "${api_args[@]}" "https://api.github.com/repos/$repo/releases/latest" -o "$release_json" 2>/dev/null; then
    version=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['tag_name'])" "$release_json")

    asset_url=$(ARCH="$asset_arch" python3 - <<'PYEOF' "$release_json"
import json, os, sys
arch = os.environ["ARCH"]
d = json.load(open(sys.argv[1]))
for a in d["assets"]:
    name = a["name"]
    if arch in name and (name.endswith(".tar.gz") or name.endswith(".zip")):
        print(a["browser_download_url"])
        break
PYEOF
)

    checksums_url=$(python3 - <<'PYEOF' "$release_json"
import json, sys
d = json.load(open(sys.argv[1]))
for a in d["assets"]:
    n = a["name"].lower()
    if "checksum" in n or "sha256" in n:
        print(a["browser_download_url"])
        break
PYEOF
)
else
    # API 가 막히면(주로 rate limit 403) rate limit 이 없는 릴리스 페이지로 우회한다.
    say "⚠ GitHub API 호출 실패(요청 한도 초과 등). 릴리스 페이지로 재시도합니다..."
    version=$(curl -fsSI "https://github.com/$repo/releases/latest" \
        | awk -F/ 'tolower($0) ~ /^location:/ { gsub(/\r/, ""); print $NF }')
    if [[ -n "$version" ]]; then
        assets_html="$tmpdir/assets.html"
        if curl -fsSL "https://github.com/$repo/releases/expanded_assets/$version" -o "$assets_html"; then
            asset_path=$(grep -o "href=\"[^\"]*${asset_arch}[^\"]*\"" "$assets_html" \
                | sed 's/^href="//; s/"$//' | grep -E '\.(tar\.gz|zip)$' | head -1)
            if [[ -n "$asset_path" ]]; then
                asset_url="https://github.com$asset_path"
            fi

            checksums_path=$(grep -o 'href="[^"]*"' "$assets_html" \
                | sed 's/^href="//; s/"$//' | grep -iE 'checksum|sha256' | head -1)
            if [[ -n "$checksums_path" ]]; then
                checksums_url="https://github.com$checksums_path"
            fi
        fi
    fi
fi

if [[ -z "$version" ]]; then
    say "✗ 릴리스 정보를 가져오지 못했습니다."
    say "  잠시 후 다시 시도하거나, 인터넷 연결을 확인하세요."
    cleanup_tmp
    exit 1
fi
say "✓ 버전: $version"

if [[ -z "$asset_url" ]]; then
    say "✗ $asset_arch 용 자산을 찾을 수 없습니다."
    say "  https://github.com/$repo/releases/latest"
    cleanup_tmp
    exit 1
fi

asset_name=$(basename "$asset_url")
say "✓ 자산: $asset_name"

# === 다운로드 ===
print -- ""
say "바이너리 다운로드 중..."
curl -fL --progress-bar "$asset_url" -o "$tmpdir/$asset_name"

# === 체크섬 검증 ===
if [[ -n "$checksums_url" ]]; then
    curl -fsSL "$checksums_url" -o "$tmpdir/checksums.txt"
    expected=$(grep -F "$asset_name" "$tmpdir/checksums.txt" | awk '{print $1}' | head -1)
    if [[ -n "$expected" ]]; then
        actual=$(shasum -a 256 "$tmpdir/$asset_name" | awk '{print $1}')
        if [[ "$expected" != "$actual" ]]; then
            say "✗ 체크섬 불일치"
            say "  예상: $expected"
            say "  실제: $actual"
            cleanup_tmp
            exit 1
        fi
        say "✓ 체크섬 OK"
    else
        say "⚠ 체크섬 파일에서 $asset_name 항목을 찾지 못함. 검증 생략."
    fi
else
    say "⚠ 체크섬 URL을 찾지 못함. 검증 생략."
fi

# === 압축 풀기 ===
extract_dir="$tmpdir/extract"
mkdir -p "$extract_dir"
case "$asset_name" in
    *.tar.gz) tar -xzf "$tmpdir/$asset_name" -C "$extract_dir" ;;
    *.zip)    unzip -q "$tmpdir/$asset_name" -d "$extract_dir" ;;
    *)
        say "✗ 알 수 없는 자산 형식: $asset_name"
        cleanup_tmp
        exit 1
        ;;
esac

bin_src=$(find "$extract_dir" -type f -name "github-mcp-server" | head -1)
if [[ -z "$bin_src" ]]; then
    say "✗ 압축 해제됐지만 github-mcp-server 바이너리가 없습니다."
    cleanup_tmp
    exit 1
fi

cp "$bin_src" "$bin_dir/github-mcp-server"
chmod +x "$bin_dir/github-mcp-server"
say "✓ 바이너리 설치: $bin_dir/github-mcp-server"

cleanup_tmp

# === wrapper.py 설치 ===
# setup.command 와 같은 폴더의 wrapper.py 를 설치 디렉터리로 복사한다.
script_dir=${0:A:h}
wrapper_src="$script_dir/wrapper.py"
if [[ ! -f "$wrapper_src" ]]; then
    say "✗ wrapper.py 를 setup.command 옆에서 찾을 수 없습니다: $wrapper_src"
    say "  레포 폴더를 통째로 받지 않고 setup.command 만 따로 옮겼다면, 폴더 전체를 다시 받아주세요."
    exit 1
fi
cp "$wrapper_src" "$bin_dir/wrapper.py"
chmod +x "$bin_dir/wrapper.py"
say "✓ wrapper 설치: $bin_dir/wrapper.py"

# python3 절대경로 (Claude Desktop 이 띄울 때 PATH 의존하지 않게)
python3_bin=$(command -v python3)
if [[ -z "$python3_bin" ]]; then
    say "✗ python3 절대경로를 찾을 수 없습니다."
    exit 1
fi
say "✓ python3: $python3_bin"

# === Device Flow: device code 요청 ===
print -- ""
say "============================================"
say "  브라우저에서 GitHub 인증"
say "============================================"

device_resp_file="$(mktemp)"
if ! curl -fsSL -X POST \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "{\"client_id\": \"$GITHUB_CLIENT_ID\"}" \
        "https://github.com/login/device/code" -o "$device_resp_file"; then
    say "✗ device code 요청 실패. 인터넷 연결과 Client ID 를 확인하세요."
    rm -f "$device_resp_file"
    exit 1
fi

device_code=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('device_code',''))" "$device_resp_file")
user_code=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('user_code',''))" "$device_resp_file")
verification_uri=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('verification_uri',''))" "$device_resp_file")
interval=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('interval', 5))" "$device_resp_file")
expires_in=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('expires_in', 900))" "$device_resp_file")
device_err=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('error',''))" "$device_resp_file")
rm -f "$device_resp_file"

if [[ -n "$device_err" ]] || [[ -z "$device_code" ]]; then
    say "✗ device code 발급 실패: $device_err"
    say "  GitHub App 의 Enable Device Flow 가 켜져있는지 확인하세요."
    exit 1
fi

print -- ""
say "다음 단계를 진행하세요:"
print -- ""
say "  1. 열린 브라우저(또는 아래 URL)에서 GitHub 로그인 후"
say "     $verification_uri"
print -- ""
say "  2. 아래 코드를 입력하세요 (클립보드에 복사됩니다):"
say "     ┌─────────────────┐"
say "     │   $user_code      │"
say "     └─────────────────┘"
print -- ""
say "  3. 권한 부여 화면이 나오면 'Authorize' 클릭"
print -- ""

# 클립보드에 user_code 복사 (실패해도 무시)
print -n -- "$user_code" | pbcopy 2>/dev/null || true

# 브라우저 자동 오픈
open "$verification_uri" 2>/dev/null || true

say "(인증을 기다리는 중... 최대 $((expires_in/60))분, 완료되면 자동으로 진행됩니다)"

# === Device Flow: 토큰 폴링 ===
poll_endpoint="https://github.com/login/oauth/access_token"
start_ts=$(date +%s)
access_token=""

while true; do
    now_ts=$(date +%s)
    elapsed=$(( now_ts - start_ts ))
    if (( elapsed > expires_in )); then
        say "✗ 인증 시간 초과. setup.command 를 다시 실행하세요."
        exit 1
    fi

    sleep "$interval"

    poll_resp_file="$(mktemp)"
    curl -fsSL -X POST \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "{\"client_id\": \"$GITHUB_CLIENT_ID\", \"device_code\": \"$device_code\", \"grant_type\": \"urn:ietf:params:oauth:grant-type:device_code\"}" \
        "$poll_endpoint" -o "$poll_resp_file" || true

    access_token=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('access_token',''))" "$poll_resp_file" 2>/dev/null || echo "")
    err=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('error',''))" "$poll_resp_file" 2>/dev/null || echo "")
    rm -f "$poll_resp_file"

    if [[ -n "$access_token" ]]; then
        say "✓ 인증 완료"
        break
    fi

    case "$err" in
        authorization_pending)
            # 정상. 계속 폴링.
            ;;
        slow_down)
            interval=$((interval + 5))
            ;;
        expired_token)
            say "✗ 코드 만료. setup.command 를 다시 실행하세요."
            exit 1
            ;;
        access_denied)
            say "✗ 사용자가 권한 부여를 거부했습니다."
            exit 1
            ;;
        "")
            say "✗ 알 수 없는 응답. 잠시 후 다시 시도하세요."
            exit 1
            ;;
        *)
            say "✗ 인증 오류: $err"
            exit 1
            ;;
    esac
done

# === Claude Desktop config 머지 ===
config_path="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
config_dir=${config_path:h}
mkdir -p "$config_dir"

if [[ -f "$config_path" ]]; then
    backup_path="${config_path}.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$config_path" "$backup_path"
    say "✓ 기존 config 백업: $backup_path"
fi

export _TOKEN_VALUE="$access_token"
export _CONFIG_PATH="$config_path"
export _SERVER_BIN="$bin_dir/github-mcp-server"
export _WRAPPER_PATH="$bin_dir/wrapper.py"
export _PYTHON_BIN="$python3_bin"

python3 - <<'PYEOF'
import json, os, sys

config_path = os.environ["_CONFIG_PATH"]
python_bin = os.environ["_PYTHON_BIN"]
wrapper_path = os.environ["_WRAPPER_PATH"]
server_bin = os.environ["_SERVER_BIN"]
token = os.environ["_TOKEN_VALUE"]

if os.path.exists(config_path) and os.path.getsize(config_path) > 0:
    try:
        with open(config_path) as f:
            config = json.load(f)
    except json.JSONDecodeError as e:
        print(f"✗ 기존 config 파일이 손상돼있어 머지할 수 없습니다: {e}", file=sys.stderr)
        sys.exit(1)
else:
    config = {}

config.setdefault("mcpServers", {})
config["mcpServers"]["github"] = {
    # python3 를 통해 wrapper.py 를 실행.
    # wrapper 가 JIRO_GITHUB_MCP_BIN 으로 공식 바이너리를 띄우고
    # MCP 메시지를 가로채 default owner 안내를 주입한다.
    "command": python_bin,
    "args": [wrapper_path],
    "env": {
        # github-mcp-server 는 환경변수 이름이 GITHUB_PERSONAL_ACCESS_TOKEN 이지만,
        # GitHub API 는 user-to-server 토큰도 Bearer 헤더에 같은 형식으로 받아들이므로
        # GitHub App device flow 로 발급된 user access token 도 그대로 동작한다.
        "GITHUB_PERSONAL_ACCESS_TOKEN": token,
        "JIRO_GITHUB_MCP_BIN": server_bin,
    },
}

with open(config_path, "w") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF
merge_status=$?

unset _TOKEN_VALUE _CONFIG_PATH _SERVER_BIN _WRAPPER_PATH _PYTHON_BIN
access_token=""

if (( merge_status != 0 )); then
    say "✗ config 업데이트 실패"
    exit 1
fi

say "✓ Claude Desktop config 업데이트: $config_path"

# === 완료 안내 ===
print -- ""
say "============================================"
say "  설치 완료"
say "============================================"
print -- ""
say "다음 단계:"
say "  1. Claude Desktop 이 실행 중이면 완전히 종료하세요 (Cmd+Q)"
say "  2. Claude Desktop 을 다시 실행하세요"
say "  3. 채팅창의 도구 아이콘에서 'github' 항목이 보이면 성공입니다."
print -- ""
say "처음 시도해볼 질문 (한 줄씩 복사해서 써보세요):"
say "  • dropshot 레포의 README 를 보여줘"
say "  • dropshot-server 레포의 디렉터리 구조를 알려줘"
say "  • jiro-developers/dropshot-server 에서 docker 관련 파일을 찾아줘"
print -- ""
say "더 많은 예시는 docs/사용예시.md, 문제 발생 시 배포자에게 문의."

# === Installer 디렉토리 정리 (선택) ===
# setup.command 는 보통 /tmp/jiro-github-mcp 에 clone 된 위치에서 실행된다.
# 실제 설치본은 ~/Library/Application Support/jiro-github-mcp/ 에 옮겨졌으므로 clone 위치는 더 이상 필요 없다.
# 단, 개발용으로 home 디렉토리 등에 clone 해서 돌리는 경우엔 건드리지 않는다.
installer_root="$script_dir"
if [[ ( "$installer_root" == /tmp/* || "$installer_root" == /private/tmp/* ) && -d "$installer_root/.git" ]]; then
    print -- ""
    print -n -- "Installer 디렉토리($installer_root)를 삭제할까요? [Y/n] "
    read -r cleanup_answer || cleanup_answer=n   # 비대화형 실행(EOF)이면 삭제하지 않고 넘어간다
    case "$cleanup_answer" in
        ""|y|Y|yes|YES)
            rm -rf "$installer_root"
            say "✓ installer 정리 완료"
            ;;
        *)
            say "  ($installer_root 는 그대로 두었습니다. 필요 시 직접 정리하세요.)"
            ;;
    esac
fi
