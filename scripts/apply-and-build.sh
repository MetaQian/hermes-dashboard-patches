#!/usr/bin/env bash
# apply-and-build.sh — 把本项目的补丁应用到 hermes-agent 源码并重建 dashboard
#
# 用法:
#   ./apply-and-build.sh <patch名或路径>            应用补丁并构建
#   ./apply-and-build.sh --undo <patch名或路径>     回退补丁并构建
#
# 环境变量:
#   HERMES_DIR   hermes-agent 源码目录 (默认 ~/.hermes/hermes-agent)
#   NODE_BIN_DIR 额外 node 目录, 会优先加入 PATH (如 ~/.hermes/tools/node-v26.13.1-linux-x64/bin)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

UNDO=0
PATCH_ARG=""
for arg in "$@"; do
  case "$arg" in
    --undo) UNDO=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) PATCH_ARG="$arg" ;;
  esac
done

if [[ -z "$PATCH_ARG" ]]; then
  echo "用法: $0 [--undo] <patch名或路径>" >&2
  ls "$PROJECT_DIR"/patches/*.patch | sed 's|.*/|  |' >&2
  exit 1
fi

# 补丁名 -> patches/ 下完整路径
if [[ ! "$PATCH_ARG" = *"/"* && ! -f "$PATCH_ARG" ]]; then
  PATCH_ARG="$PROJECT_DIR/patches/$PATCH_ARG"
fi
if [[ ! -f "$PATCH_ARG" ]]; then
  echo "找不到补丁: $PATCH_ARG" >&2
  exit 1
fi

HERMES_DIR="${HERMES_DIR:-$HOME/.hermes/hermes-agent}"
if [[ ! -d "$HERMES_DIR/.git" ]]; then
  echo "找不到 hermes-agent 源码目录: $HERMES_DIR (用 HERMES_DIR=... 指定)" >&2
  exit 1
fi

# ── Node ≥ 26 检查 ─────────────────────────────────────────────
if [[ -n "${NODE_BIN_DIR:-}" && -x "$NODE_BIN_DIR/node" ]]; then
  export PATH="$NODE_BIN_DIR:$PATH"
fi
node_major() { node -v 2>/dev/null | sed 's/^v\([0-9]*\).*/\1/'; }
MAJOR="$(node_major)"
if [[ -z "$MAJOR" ]]; then
  echo "未找到 node, 请先安装 Node >= 26" >&2; exit 1
fi
if (( MAJOR < 26 )); then
  # 常见位置自动找一下
  CANDIDATE="$(ls -d "$HOME"/.hermes/tools/node-v2[6-9]*.*/bin "$HOME"/.hermes/tools/node-v[3-9]*.*/bin 2>/dev/null | sort -V | tail -1 || true)"
  if [[ -n "$CANDIDATE" && -x "$CANDIDATE/node" ]]; then
    export PATH="$CANDIDATE:$PATH"
    MAJOR="$(node_major)"
  fi
fi
if [[ -z "$MAJOR" || $MAJOR -lt 26 ]]; then
  echo "需要 Node >= 26 (当前 $(node -v))。安装后重试, 或用 NODE_BIN_DIR 指定。" >&2
  exit 1
fi
echo "node: $(node -v)"

# ── pnpm 检查 ─────────────────────────────────────────────────
if ! command -v pnpm >/dev/null 2>&1; then
  PNPM_CANDIDATE="$(ls "$HOME"/.hermes/tools/pnpm-*/pnpm 2>/dev/null | sort -V | tail -1 || true)"
  if [[ -n "$PNPM_CANDIDATE" ]]; then
    Pnpm="\"$PNPM_CANDIDATE\""
  else
    echo "未找到 pnpm, 请先安装 (corepack enable 或 npm i -g pnpm)" >&2; exit 1
  fi
else
  Pnpm="pnpm"
fi

cd "$HERMES_DIR"

echo "hermes-agent 目录: $HERMES_DIR (commit $(git rev-parse --short HEAD))"
if [[ -n "$(git status --porcelain web/ 2>/dev/null)" ]]; then
  echo "注意: web/ 下存在未提交改动, 与本补丁可能重叠。建议先 git stash 或人工核对。" >&2
fi

# ── 应用 / 回退 ───────────────────────────────────────────────
if (( UNDO )); then
  if git apply --check -R "$PATCH_ARG" 2>/dev/null; then
    git apply -R "$PATCH_ARG"
    echo "已回退补丁: $(basename "$PATCH_ARG")"
  else
    echo "补丁当前未被应用(或已部分应用), 无需回退"
  fi
else
  if git apply --check "$PATCH_ARG" 2>/dev/null; then
    git apply "$PATCH_ARG"
    echo "已应用补丁: $(basename "$PATCH_ARG")"
  elif git apply --check -R "$PATCH_ARG" 2>/dev/null; then
    echo "补丁已经处于应用状态, 跳过 apply"
  else
    echo "直接 apply 失败, 尝试 --3way 三路合并..." >&2
    git apply --3way "$PATCH_ARG"
    echo "三路合并完成; 如产生冲突标记(<<<<<<<)请人工解决后再构建" >&2
  fi
fi

# ── 构建 ──────────────────────────────────────────────────────
echo "安装依赖..."
$Pnpm install --frozen-lockfile
echo "构建 dashboard..."
$Pnpm --dir web run build
echo
echo "完成。dashboard 刷新浏览器页面即可看到效果(无需重启 hermes 进程)。"