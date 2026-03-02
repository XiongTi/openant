#!/bin/bash
# OpenClaw 多 Agent 多渠道配置初始化脚本
# 用法: bash init-agents.sh

set -e

echo "=========================================="
echo "OpenClaw 多 Agent 多渠道配置初始化"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 读取基础配置
echo "=== 1. 基础配置 ==="
read -p "请输入模型 ID (如 MiniMax-M2.5): " MODEL_ID
read -p "请输入 Base URL (如 https://api.minimaxi.com/anthropic): " BASE_URL
read -p "请输入 API Key: " API_KEY
read -p "请输入 API 协议 (anthropic-messages 或 openai-completions): " API_PROTOCOL
CONTEXT_WINDOW=${CONTEXT_WINDOW:-200000}
MAX_TOKENS=${MAX_TOKENS:-8192}
echo ""

# 读取 Agent 配置
echo "=== 2. Agent 配置 ==="
read -p "请输入 Agent 数量 (1-10): " AGENT_COUNT

AGENTS_JSON="["
BINDINGS_JSON=""

for ((i=1; i<=AGENT_COUNT; i++)); do
    echo ""
    echo "--- Agent $i ---"
    read -p "  Agent ID (英文唯一标识, 如 agent1): " AGENT_ID
    read -p "  Agent 名称 (中文, 如 Agent1): " AGENT_NAME
    read -p "  工作空间目录名 (如 workspace-${AGENT_ID}): " WORKSPACE_NAME

    if [ $i -eq 1 ]; then
        AGENTS_JSON="${AGENTS_JSON}{\"id\":\"${AGENT_ID}\",\"name\":\"${AGENT_NAME}\",\"workspace\":\"${WORKSPACE_NAME}\"}"
    else
        AGENTS_JSON="${AGENTS_JSON},{\"id\":\"${AGENT_ID}\",\"name\":\"${AGENT_NAME}\",\"workspace\":\"${WORKSPACE_NAME}\"}"
    fi

    # 询问是否要绑定 Telegram
    read -p "  是否绑定 Telegram Bot? (y/n): " BIND_TG
    if [[ "$BIND_TG" == "y" || "$BIND_TG" == "Y" ]]; then
        read -p "    Telegram Bot Token (如 123456789:ABCDefGhi): " TG_TOKEN
        TG_TOKEN_FORMATED="${AGENT_ID}:${TG_TOKEN}"
        if [ -z "$TG_TOKENS" ]; then
            TG_TOKENS="${TG_TOKEN_FORMATED}"
            TG_BINDINGS="${AGENT_ID}:${AGENT_ID}"
        else
            TG_TOKENS="${TG_TOKENS},${TG_TOKEN_FORMATED}"
            TG_BINDINGS="${TG_BINDINGS},${AGENT_ID}:${AGENT_ID}"
        fi
    fi

    # 询问是否要绑定 DingTalk
    read -p "  是否绑定 DingTalk Bot? (y/n): " BIND_DD
    if [[ "$BIND_DD" == "y" || "$BIND_DD" == "Y" ]]; then
        read -p "    DingTalk Client ID (AppKey): " DD_CLIENT_ID
        read -p "    DingTalk Client Secret (AppSecret): " DD_CLIENT_SECRET
        DD_FORMATED="${AGENT_ID}:${DD_CLIENT_ID}"
        DD_SECRET_FORMATED="${AGENT_ID}:${DD_CLIENT_SECRET}"
        if [ -z "$DD_CLIENT_IDS" ]; then
            DD_CLIENT_IDS="${DD_FORMATED}"
            DD_CLIENT_SECRETS="${DD_SECRET_FORMATED}"
            DD_BINDINGS="${AGENT_ID}:${AGENT_ID}"
        else
            DD_CLIENT_IDS="${DD_CLIENT_IDS},${DD_FORMATED}"
            DD_CLIENT_SECRETS="${DD_CLIENT_SECRETS},${DD_SECRET_FORMATED}"
            DD_BINDINGS="${DD_BINDINGS},${AGENT_ID}:${AGENT_ID}"
        fi
    fi
done

AGENTS_JSON="${AGENTS_JSON}]"

echo ""
echo "=== 3. 网关配置 ==="
read -p "请输入 Gateway Token: " GW_TOKEN
read -p "请输入 Gateway 绑定地址 (lan/0.0.0.0): " GW_BIND
GW_PORT=${GW_PORT:-18789}
BRIDGE_PORT=${BRIDGE_PORT:-18790}

echo ""
echo "=== 4. 代理配置 (可选) ==="
read -p "是否配置 V2Ray/VLESS 代理? (y/n): " CONFIGURE_VLESS
if [[ "$CONFIGURE_VLESS" == "y" || "$CONFIGURE_VLESS" == "Y" ]]; then
    read -p "  VLESS 地址: " VLESS_ADDRESS
    read -p "  VLESS 端口: " VLESS_PORT
    read -p "  VLESS UUID: " VLESS_UUID
    read -p "  VLESS SNI: " VLESS_SNI
    read -p "  VLESS WS Path: " VLESS_WS_PATH
fi

read -p "是否配置 Shadowsocks 代理? (y/n): " CONFIGURE_SS
if [[ "$CONFIGURE_SS" == "y" || "$CONFIGURE_SS" == "Y" ]]; then
    read -p "  SS 地址: " SS_ADDRESS
    read -p "  SS 端口: " SS_PORT
    read -p "  SS 密码: " SS_PASSWORD
fi

# 生成 .env 文件
echo ""
echo "=== 5. 生成配置 ==="

cat > .env << EOF
# ===== 基础配置 =====
MODEL_ID=${MODEL_ID}
BASE_URL=${BASE_URL}
API_KEY=${API_KEY}
API_PROTOCOL=${API_PROTOCOL}
CONTEXT_WINDOW=${CONTEXT_WINDOW}
MAX_TOKENS=${MAX_TOKENS}

# ===== Agent 配置 =====
OPENCLAW_AGENTS=${AGENTS_JSON}

# ===== Telegram 配置 =====
TELEGRAM_BOT_TOKEN=${TG_TOKENS:-}
TELEGRAM_BINDINGS=${TG_BINDINGS:-}

# ===== DingTalk 配置 =====
DINGTALK_CLIENT_ID=${DD_CLIENT_IDS:-}
DINGTALK_CLIENT_SECRET=${DD_CLIENT_SECRETS:-}
DINGTALK_BINDINGS=${DD_BINDINGS:-}

# ===== Gateway 配置 =====
OPENCLAW_GATEWAY_TOKEN=${GW_TOKEN}
OPENCLAW_GATEWAY_BIND=${GW_BIND:-lan}
OPENCLAW_GATEWAY_PORT=${GW_PORT}
OPENCLAW_BRIDGE_PORT=${BRIDGE_PORT}
EOF

# 添加代理配置
if [[ "$CONFIGURE_VLESS" == "y" || "$CONFIGURE_VLESS" == "Y" ]]; then
    cat >> .env << EOF

# ===== VLESS 代理配置 =====
VLESS_ADDRESS=${VLESS_ADDRESS}
VLESS_PORT=${VLESS_PORT}
VLESS_UUID=${VLESS_UUID}
VLESS_SNI=${VLESS_SNI}
VLESS_WS_PATH=${VLESS_WS_PATH}
EOF
fi

if [[ "$CONFIGURE_SS" == "y" || "$CONFIGURE_SS" == "Y" ]]; then
    cat >> .env << EOF

# ===== Shadowsocks 代理配置 =====
SS_ADDRESS=${SS_ADDRESS}
SS_PORT=${SS_PORT}
SS_PASSWORD=${SS_PASSWORD}
EOF
fi

echo ""
echo "${GREEN}配置生成完成!${NC}"
echo ""
echo "生成的 .env 文件:"
echo "----------------------------------------"
cat .env
echo "----------------------------------------"
echo ""
echo "下一步:"
echo "1. 检查 .env 文件确保配置正确"
echo "2. 运行 docker-compose up -d 启动服务"
echo ""
