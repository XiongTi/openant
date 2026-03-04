# syntax=docker/dockerfile:1
# OpenClaw Docker 镜像
FROM node:24-slim

# ============ 环境变量配置 ============
ENV MODEL_ID= \
    BASE_URL= \
    API_KEY= \
    API_PROTOCOL= \
    CONTEXT_WINDOW=200000 \
    MAX_TOKENS=8192 \
    TELEGRAM_BOT_TOKEN= \
    FEISHU_APP_ID= \
    FEISHU_APP_SECRET= \
    DINGTALK_CLIENT_ID= \
    DINGTALK_CLIENT_SECRET= \
    DINGTALK_ROBOT_CODE= \
    DINGTALK_CORP_ID= \
    DINGTALK_AGENT_ID= \
    DINGTALK_BINDINGS= \
    QQBOT_APP_ID= \
    QQBOT_CLIENT_SECRET= \
    WECOM_TOKEN= \
    WECOM_ENCODING_AES_KEY= \
    AUTH_TOKEN= \
    CT0= \
    WORKSPACE=/home/node/.openclaw/workspace \
    OPENCLAW_GATEWAY_TOKEN= \
    OPENCLAW_GATEWAY_BIND=lan \
    OPENCLAW_GATEWAY_PORT=18789 \
    OPENCLAW_BRIDGE_PORT=18790 \
    VLESS_ADDRESS= \
    VLESS_PORT=443 \
    VLESS_UUID= \
    VLESS_SNI= \
    VLESS_WS_PATH= \
    SS_ADDRESS= \
    SS_PORT=10019 \
    SS_PASSWORD= \
    OPENCLAW_AGENTS= \
    TELEGRAM_BINDINGS=

# 替换为国内镜像源
COPY <<EOF /etc/apt/sources.list.d/debian.sources
Types: deb
URIs: http://mirrors.aliyun.com/debian
Suites: bookworm bookworm-updates
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://mirrors.aliyun.com/debian-security
Suites: bookworm-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

# 安装系统依赖
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash ca-certificates chromium curl tzdata \
    fonts-liberation fonts-noto-cjk fonts-noto-color-emoji \
    vim xvfb git gosu jq make g++ python3 python3-pip socat tini unzip websockify wget gettext-base proxychains4 ffmpeg openssh-client \
  && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
  && echo "Asia/Shanghai" > /etc/timezone \
  && rm -rf /var/lib/apt/lists/*

# 安装 Python 工具: uv(minimax skills), openai-whisper(语音转文字), edge-tts(文字转语音)
RUN pip3 install --no-cache-dir uv openai-whisper edge-tts --break-system-packages -i https://mirrors.aliyun.com/pypi/simple/

# 强制 git 使用 HTTPS 而非 SSH
RUN printf '[url "https://github.com/"]\n\tinsteadOf = ssh://git@github.com/\n[url "https://github.com/"]\n\tinsteadOf = git@github.com:\n[url "https://github.com/"]\n\tinsteadOf = git+ssh://git@github.com/\n[url "https://github.com/"]\n\tinsteadOf = git://github.com/\n' > /root/.gitconfig

# 安装 bun + 全局 npm 包 + 清理编译工具和缓存
# 使用 --ignore-scripts 跳过 postinstall，避免 git 依赖问题
RUN npm config set fetch-retries 5 \
  && npm config set fetch-retry-mintimeout 20000 \
  && npm config set fetch-retry-maxtimeout 120000 \
  && npm install -g bun --registry=https://registry.npmmirror.com \
  && npm install -g --ignore-scripts --prefer-online --no-audit --no-fund @tobilu/qmd openclaw@latest --registry=https://registry.npmmirror.com \
  && (npm install -g --no-audit --no-fund @anthropic-ai/claude-code opencode-ai@latest playwright playwright-extra puppeteer-extra-plugin-stealth --registry=https://registry.npmmirror.com || true) \
  && apt-get purge -y --auto-remove make g++ \
  && rm -rf /var/lib/apt/lists/* /root/.npm /tmp/*

ENV BUN_INSTALL="/usr/local" \
    PATH="/usr/local/bin:$PATH" \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# 创建配置目录并设置权限
RUN mkdir -p /home/node/.openclaw/workspace && \
    chown -R node:node /home/node

# 切换到 node 用户安装插件
USER node

# OpenClaw已内置飞书插件 - 使用 timeout 防止卡住，忽略错误继续构建
# RUN timeout 300 openclaw plugins install @m1heng-clawd/feishu || true

# 安装插件到临时目录（VOLUME 挂载会覆盖 .openclaw，所以装到 /tmp/extensions，init.sh 启动时复制）
# 使用重试机制和国内镜像源
RUN mkdir -p /tmp/extensions \
    && cd /tmp/extensions \
    && for i in 1 2 3; do \
         git clone --depth 1 https://github.com/soimy/openclaw-channel-dingtalk.git && break || sleep 10; \
       done \
    && cd openclaw-channel-dingtalk \
    && rm -rf .git \
    && npm install --no-audit --no-fund --legacy-peer-deps --registry=https://registry.npmmirror.com \
    && timeout 600 openclaw plugins install -l . 2>/dev/null || true \
    && cd /tmp \
    && for i in 1 2 3; do \
         git clone --depth 1 https://github.com/justlovemaki/qqbot.git && break || sleep 10; \
       done \
    && cd qqbot \
    && rm -rf .git \
    && timeout 300 openclaw plugins install . 2>/dev/null || true \
    && timeout 300 openclaw plugins install @sunnoy/wecom 2>/dev/null || true \
    && rm -rf /tmp/qqbot /home/node/.npm

# 切换回 root 用户继续后续操作
USER root

# 清理飞书插件、安装 V2Ray
RUN wget -q --timeout=120 --tries=5 https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip -O /tmp/v2ray.zip \
    && unzip -q /tmp/v2ray.zip -d /opt/v2ray \
    && rm /tmp/v2ray.zip

# 复制配置文件和脚本
COPY ./vless.json.tpl /etc/v2ray/config.json.tpl
COPY ./openclaw.default.json /etc/openclaw/openclaw.default.json
COPY ./sync_config.py /usr/local/bin/sync_config.py
COPY ./workspace /tmp/workspace
COPY ./skills /tmp/skills
COPY ./init.sh /usr/local/bin/init.sh
COPY ./restart-v2ray.sh /usr/local/bin/restart-v2ray
COPY ./claude-proxy /usr/local/bin/claude-proxy

RUN chmod +x /usr/local/bin/init.sh /usr/local/bin/restart-v2ray /usr/local/bin/claude-proxy

# 设置基础环境变量
ENV HOME=/home/node \
    TERM=xterm-256color \
    NODE_PATH=/usr/local/lib/node_modules

# 声明持久卷
VOLUME /home/node/.openclaw

# 暴露端口
EXPOSE 18789 18790

# 设置工作目录为 home
WORKDIR /home/node

# 使用初始化脚本作为入口点（以 root 运行以便修复权限）
ENTRYPOINT ["/bin/bash", "/usr/local/bin/init.sh"]
