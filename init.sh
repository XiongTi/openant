#!/bin/bash

echo "=== OpenClaw 初始化脚本 ==="

OPENCLAW_HOME="/home/node/.openclaw"
OPENCLAW_WORKSPACE="${WORKSPACE:-/home/node/.openclaw/workspace}"
NODE_UID="$(id -u node)"
NODE_GID="$(id -g node)"

# 创建必要目录
mkdir -p "$OPENCLAW_HOME" "$OPENCLAW_WORKSPACE"

# 预检查挂载卷权限（避免同样命令偶发 Permission denied）
if [ "$(id -u)" -eq 0 ]; then
    CURRENT_OWNER="$(stat -c '%u:%g' "$OPENCLAW_HOME" 2>/dev/null || echo unknown:unknown)"
    echo "挂载目录: $OPENCLAW_HOME"
    echo "当前所有者(UID:GID): $CURRENT_OWNER"
    echo "目标所有者(UID:GID): ${NODE_UID}:${NODE_GID}"

    if [ "$CURRENT_OWNER" != "${NODE_UID}:${NODE_GID}" ]; then
        echo "检测到宿主机挂载目录所有者与容器运行用户不一致，尝试自动修复..."
        chown -R node:node "$OPENCLAW_HOME" || true
    fi

    # 再次验证写权限，失败则给出明确诊断
    if ! gosu node test -w "$OPENCLAW_HOME"; then
        echo "❌ 权限检查失败：node 用户无法写入 $OPENCLAW_HOME"
        echo "请在宿主机执行（Linux）："
        echo "  sudo chown -R ${NODE_UID}:${NODE_GID} <your-openclaw-data-dir>"
        echo "或在启动时显式指定用户："
        echo "  docker run --user \$(id -u):\$(id -g) ..."
        echo "若宿主机启用了 SELinux，请在挂载卷后添加 :z 或 :Z"
        exit 1
    fi
fi

# 同步配置
sync_config_with_env() {
    local config_file="/home/node/.openclaw/openclaw.json"

    # 每次启动都从默认模板重新生成，再用环境变量同步（环境变量是 source of truth）
    if [ -f "$config_file" ]; then
        cp "$config_file" "${config_file}.bak"
    fi
    cp /etc/openclaw/openclaw.default.json "$config_file"

    echo "正在根据当前环境变量同步配置状态..."
    python3 /usr/local/bin/sync_config.py "$config_file" || { echo "❌ 配置同步失败"; exit 1; }
}

sync_config_with_env

# Claude Code 初始化
init_claude() {
    CLAUDE_JSON="/home/node/.claude.json"
    SETTINGS_JSON="/home/node/.claude/settings.json"
    BASHRC="/home/node/.bashrc"
    CLAUDE_PROXY="/usr/local/bin/claude-proxy"

    # 创建 Claude 目录
    mkdir -p /home/node/.claude
    # 1. 创建 .claude.json（如果不存在）
    if [ ! -f "$CLAUDE_JSON" ]; then
        echo '{"hasCompletedOnboarding": true}' > "$CLAUDE_JSON"
        echo "Claude 配置已创建: $CLAUDE_JSON"
    else
        echo "Claude 配置已存在，跳过: $CLAUDE_JSON"
    fi

    # 2. 创建 settings.json（如果不存在）
    if [ ! -f "$SETTINGS_JSON" ]; then
        # 从环境变量 API_KEY 获取 token
        API_TOKEN="${API_KEY:-}"
        if [ -z "$API_TOKEN" ]; then
            echo "⚠️ 警告: 环境变量 API_KEY 未设置，settings.json 中的 TOKEN 将为空"
        fi

        cat > "$SETTINGS_JSON" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "${API_TOKEN}",
    "ANTHROPIC_BASE_URL": "https://api.minimaxi.com/anthropic",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "MiniMax-M2.5",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "MiniMax-M2.5",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "MiniMax-M2.5",
    "ANTHROPIC_MODEL": "MiniMax-M2.5",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": 1
  },
  "includeCoAuthoredBy": false
}
EOF
        echo "Claude settings 已创建: $SETTINGS_JSON"
    else
        echo "Claude settings 已存在，跳过: $SETTINGS_JSON"
    fi

    # 3. 在 .bashrc 中添加 claude 别名
    if [ -f "$CLAUDE_PROXY" ]; then
        if [ -f "$BASHRC" ]; then
            if ! grep -q "alias claude=" "$BASHRC" 2>/dev/null; then
                echo "alias claude='/usr/local/bin/claude-proxy'" >> "$BASHRC"
                echo "claude 别名已添加到: $BASHRC"
            else
                echo "claude 别名已存在，跳过"
            fi
        else
            echo "alias claude='/usr/local/bin/claude-proxy'" > "$BASHRC"
            echo "claude 别名已创建: $BASHRC"
        fi
    else
        echo "⚠️ 警告: claude-proxy 不存在，跳过别名设置"
    fi

    # 确保 Claude 相关文件和目录的权限正确
    if [ "$(id -u)" -eq 0 ]; then
        chown -R node:node /home/node/.claude 2>/dev/null || true
        chown node:node /home/node/.claude.json 2>/dev/null || true
        chown node:node /home/node/.bashrc 2>/dev/null || true
    fi
}

init_claude

# 配置 .vimrc 解决乱码问题
init_vimrc() {
    VIMRC="/home/node/.vimrc"

    if [ ! -f "$VIMRC" ]; then
        cat > "$VIMRC" << 'EOF'
" Vim 编码配置，解决乱码问题
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=ucs-bom,utf-8,gbk,cp936,latin1
set termencoding=utf-8
set encoding=utf-8

" 语法高亮
syntax on

" 显示行号
set number

" 缩进设置
set tabstop=4
set shiftwidth=4
set expandtab

" 搜索设置
set ignorecase
set smartcase

" 显示匹配括号
set showmatch

" 增强命令行补全
set wildmenu
EOF
        echo "Vim 配置已创建: $VIMRC"

        # 设置权限
        if [ "$(id -u)" -eq 0 ]; then
            chown node:node "$VIMRC" 2>/dev/null || true
        fi
    else
        echo "Vim 配置已存在，跳过: $VIMRC"
    fi
}

init_vimrc

# 确保所有文件和目录的权限正确（仅 root 可执行）
if [ "$(id -u)" -eq 0 ]; then
    chown -R node:node "$OPENCLAW_HOME" || true
    chown -R node:node "$CLAUDE_HOME" || true
fi

echo "=== 初始化完成 ==="
echo "当前使用模型: default/$MODEL_ID"
echo "API 协议: ${API_PROTOCOL:-openai-completions}"
echo "Base URL: ${BASE_URL}"
echo "上下文窗口: ${CONTEXT_WINDOW:-200000}"
echo "最大 Tokens: ${MAX_TOKENS:-8192}"
echo "Gateway 端口: $OPENCLAW_GATEWAY_PORT"
echo "Gateway 绑定: $OPENCLAW_GATEWAY_BIND"

# 复制 workspace、skills、extensions 到正确位置（支持挂载卷场景）
if [ -d /tmp/workspace ]; then
    cp -r /tmp/workspace /home/node/.openclaw/ 2>/dev/null || true
fi
if [ -d /tmp/skills ]; then
    cp -r /tmp/skills /home/node/.openclaw/ 2>/dev/null || true
fi
if [ -d /tmp/extensions ]; then
    mkdir -p /home/node/.openclaw/extensions
    cp -rn /tmp/extensions/* /home/node/.openclaw/extensions/ 2>/dev/null || true
    rm -rf /home/node/.openclaw/extensions/feishu 2>/dev/null || true
    chown -R node:node /home/node/.openclaw/extensions 2>/dev/null || true
fi

# 安装 bun
export BUN_INSTALL="/usr/local"
export PATH="$BUN_INSTALL/bin:$PATH"

# 启动 OpenClaw Gateway（切换到 node 用户）
echo "=== 启动 OpenClaw Gateway ==="

export DBUS_SESSION_BUS_ADDRESS=/dev/null

# 定义清理函数
cleanup() {
    echo "=== 接收到停止信号,正在关闭服务 ==="
    if [ -n "$GATEWAY_PID" ]; then
        kill -TERM "$GATEWAY_PID" 2>/dev/null || true
        wait "$GATEWAY_PID" 2>/dev/null || true
    fi
    if [ -n "$V2RAY_PID" ]; then
        kill -TERM "$V2RAY_PID" 2>/dev/null || true
        wait "$V2RAY_PID" 2>/dev/null || true
    fi
    echo "=== 服务已停止 ==="
    exit 0
}

# 捕获终止信号
trap cleanup SIGTERM SIGINT SIGQUIT


# 检查是否配置了代理（VLESS 或 SS）
HAS_PROXY=false
if [ -n "$VLESS_ADDRESS" ] || [ -n "$SS_ADDRESS" ]; then
    HAS_PROXY=true
fi

# 从模板渲染 V2Ray 配置（仅在代理配置存在时渲染）
V2RAY_OK=false
V2RAY_PID=""
if $HAS_PROXY; then
    V2RAY_CONFIG="/home/node/.openclaw/v2ray.json"
    if [ ! -f "$V2RAY_CONFIG" ]; then
        envsubst < /etc/v2ray/config.json.tpl > "$V2RAY_CONFIG"
        echo "V2Ray 配置已从模板渲染"
    else
        echo "V2Ray 配置已存在，跳过渲染"
    fi

    # 启动 V2Ray 代理
    if [ -f "$V2RAY_CONFIG" ]; then
        echo "=== 启动 V2Ray 代理 ==="
        /opt/v2ray/v2ray run -config "$V2RAY_CONFIG" &
        V2RAY_PID=$!
        # 等待 V2Ray 端口就绪（最多 5 秒）
        for i in $(seq 1 50); do
            if curl -s --connect-timeout 1 -o /dev/null http://127.0.0.1:10809 2>/dev/null; then
                V2RAY_OK=true
                break
            fi
            sleep 0.1
        done
        if $V2RAY_OK; then
            echo "=== V2Ray 已启动 (PID: $V2RAY_PID) ==="
        else
            echo "⚠️ V2Ray 未能在 5 秒内就绪，Gateway 将不使用代理启动"
            kill "$V2RAY_PID" 2>/dev/null || true
            V2RAY_PID=""
        fi
    else
        echo "=== V2Ray 配置文件不存在，跳过 ==="
    fi
else
    echo "=== 未配置代理，跳过 V2Ray 启动 ==="
fi

# 启动 Gateway
echo "=== 准备启动 Gateway ==="
echo "openclaw 路径: $(which openclaw 2>&1)"

if $V2RAY_OK; then
    echo "=== Gateway 将通过 openclaw 原生代理配置 + V2Ray 启动 ==="
    gosu node env HOME=/home/node DBUS_SESSION_BUS_ADDRESS=/dev/null \
        BUN_INSTALL=/usr/local PATH=/usr/local/bin:/usr/bin:/bin \
        NODE_OPTIONS="--dns-result-order=ipv4first" \
        openclaw gateway run \
        --bind "$OPENCLAW_GATEWAY_BIND" --port "$OPENCLAW_GATEWAY_PORT" \
        --token "$OPENCLAW_GATEWAY_TOKEN" --verbose &
else
    echo "=== Gateway 将直连启动（无代理）==="
    gosu node env HOME=/home/node DBUS_SESSION_BUS_ADDRESS=/dev/null \
        BUN_INSTALL=/usr/local PATH=/usr/local/bin:/usr/bin:/bin \
        NODE_OPTIONS="--dns-result-order=ipv4first" \
        openclaw gateway run \
        --bind "$OPENCLAW_GATEWAY_BIND" --port "$OPENCLAW_GATEWAY_PORT" \
        --token "$OPENCLAW_GATEWAY_TOKEN" --verbose &
fi
GATEWAY_PID=$!

echo "=== OpenClaw Gateway 进程已启动 (PID: $GATEWAY_PID) ==="

# 检测 Gateway 端口是否就绪（最多等 30 秒）
GATEWAY_READY=false
for i in $(seq 1 60); do
    if curl -s --connect-timeout 1 -o /dev/null "http://127.0.0.1:${OPENCLAW_GATEWAY_PORT}" 2>/dev/null; then
        GATEWAY_READY=true
        break
    fi
    if ! kill -0 "$GATEWAY_PID" 2>/dev/null; then
        echo "❌ Gateway 进程已退出，端口 ${OPENCLAW_GATEWAY_PORT} 未启动"
        wait "$GATEWAY_PID" 2>/dev/null
        EXIT_CODE=$?
        echo "Gateway 退出码: $EXIT_CODE"
        exit $EXIT_CODE
    fi
    sleep 0.5
done

if $GATEWAY_READY; then
    echo "✅ Gateway 端口 ${OPENCLAW_GATEWAY_PORT} 已就绪"
else
    echo "⚠️ Gateway 端口 ${OPENCLAW_GATEWAY_PORT} 在 30 秒内未就绪，继续等待..."
fi

# 主进程等待子进程
wait "$GATEWAY_PID"
EXIT_CODE=$?

echo "=== OpenClaw Gateway 已退出 (退出码: $EXIT_CODE) ==="
exit $EXIT_CODE
