#!/bin/bash
# visual-tokenizer-dev 단일 이미지 환경 설치 스크립트
# nvcr CUDA 12.1 runtime 이미지 위에서 실행
# 완료 후 save-as-image → visual-tokenizer-dev
set -euo pipefail

REPO_URL="https://github.com/tunatone0111/visual-tokenizer.git"
REPO_RAW="https://raw.githubusercontent.com/tunatone0111/visual-tokenizer/main"
RUN_DIR="/opt/vt-cache"
NFS_HOME="/mnt/image-net-full/junhapark/home"

# --- Preamble: GITHUB_TOKEN + sudo 설정 ---

# GITHUB_TOKEN: 환경변수로 미리 설정되어 있으면 사용, 없으면 프롬프트
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo -n "GitHub Personal Access Token (private repo 접근용): "
    read -rs GITHUB_TOKEN || true
    echo
fi
[ -z "$GITHUB_TOKEN" ] && echo "ERROR: GITHUB_TOKEN이 비어 있습니다." >&2 && exit 1
export GITHUB_TOKEN

# root 사용자면 sudo 불필요 (Docker 컨테이너 등)
if [ "$(id -u)" -eq 0 ]; then
    sudo() { "$@"; }
    export -f sudo
else
    echo "sudo 권한이 필요합니다 (apt, /usr/local/bin, /etc/profile.d 쓰기용)."
    sudo -v
    while true; do sudo -n true; sleep 50; done 2>/dev/null &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT
fi

echo "=== 1/6. apt 패키지 설치 ==="

# GitHub CLI 공식 apt repo 등록 (gpg는 base 이미지에 포함)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

# Node.js 20 (NodeSource) — Claude Code CLI 의존성
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -

# NodeSource 스크립트가 apt-get update를 실행하므로 바로 install
sudo apt-get install -y --no-install-recommends \
    git curl wget ca-certificates unzip \
    libgl1 libglib2.0-0 \
    gh nodejs \
    jq htop nvtop ripgrep fd-find bat vim nano tmux \
    && sudo rm -rf /var/lib/apt/lists/*

echo "=== 2/6. uv 설치 ==="
curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR="/usr/local/bin" sh

echo "=== 3/6. bun 설치 ==="
curl -fsSL https://bun.sh/install | BUN_INSTALL="/usr/local/bin" bash

echo "=== 4/6. Claude Code CLI 설치 ==="
curl -fsSL https://claude.ai/install.sh | bash
sudo cp "$(which claude 2>/dev/null || echo "$HOME/.local/bin/claude")" /usr/local/bin/claude 2>/dev/null || true

echo "=== 5/6. 프로젝트 의존성 사전 설치 ==="
mkdir -p "$RUN_DIR"
fetch_raw() {
    mkdir -p "$(dirname "$RUN_DIR/$1")"
    curl -fsSL -H "Authorization: token $GITHUB_TOKEN" -o "$RUN_DIR/$1" "$REPO_RAW/$1"
}
fetch_raw pyproject.toml
fetch_raw uv.lock
fetch_raw .python-version
fetch_raw scripts/run_experiment.sh
chmod +x "$RUN_DIR/scripts/run_experiment.sh"
ln -sfn "$RUN_DIR/scripts/run_experiment.sh" /opt/vt-cache/run_experiment.sh

(cd "$RUN_DIR" && UV_CACHE_DIR=/opt/uv-cache uv sync --frozen --no-install-project --link-mode=copy \
    --python 3.11 --no-install-package flash-attn)
chmod -R a+rwX /opt/uv-cache

echo "=== 6/6. 환경 변수 설정 ==="
sudo tee /etc/profile.d/vt-env.sh >/dev/null << 'ENVEOF'
# --- visual-tokenizer-dev ---
NFS_HOME=/mnt/image-net-full/junhapark/home
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export WANDB_MODE=disabled
export PYTHONUNBUFFERED=1
export PYTHONDONTWRITEBYTECODE=1
export TORCH_HOME=$NFS_HOME/.cache/torch
export HF_HOME=$NFS_HOME/.cache/huggingface
export UV_CACHE_DIR=$NFS_HOME/.cache/uv
mkdir -p "$TORCH_HOME" "$HF_HOME" "$UV_CACHE_DIR" 2>/dev/null || true
export HYDRA_FULL_ERROR=1
export TERM=xterm-256color
alias l='ls -lh --group-directories-first'
alias la='ls -lha --group-directories-first'
# tmux: SSH 접속 시 자동 attach
if [[ $- == *i* ]] && [[ -z "$TMUX" ]] && [[ -n "$SSH_TTY" ]]; then
    exec tmux new-session -A -s main
fi
# ANTHROPIC_API_KEY: 컨테이너 진입 후 export ANTHROPIC_API_KEY=sk-ant-... 로 설정

# Dotfiles 자동 설치 (첫 로그인 시 1회)
if [ ! -d "$HOME/dotfiles" ]; then
    echo "🔧 Dotfiles 자동 설치 중..."
    if git clone https://github.com/tunatone0111/dotfiles.git "$HOME/dotfiles" 2>/dev/null; then
        if [ -f "$HOME/dotfiles/install.sh" ]; then
            bash "$HOME/dotfiles/install.sh"
        else
            [ -d "$HOME/dotfiles/.claude" ] && cp -r "$HOME/dotfiles/.claude" "$HOME/"
        fi
        echo "✅ Dotfiles 설치 완료"
    else
        echo "⚠️  Dotfiles clone 실패 (gh auth login 후 재시도)"
    fi
fi
ENVEOF

echo "✅ Dev 환경 설치 완료. 이 컨테이너를 save as image 하세요."
