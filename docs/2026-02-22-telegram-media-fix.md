# OpenClaw Telegram 媒体下载问题修复记录

日期：2026-02-22 ~ 2026-02-23

## 问题描述

OpenClaw 通过 Telegram 接收文本消息正常，但接收图片和语音时报错：
`MediaFetchError: fetch failed`

文本消息内容直接在 webhook payload 中推送，不需要额外下载。但图片/语音只推 `file_id`，Gateway 需要主动去 `https://api.telegram.org/file/bot.../` 下载文件，这一步失败。

## 根因分析

1. 容器内无法直连 `api.telegram.org`（IPv4 被墙超时，IPv6 不可达）
2. 容器内 V2Ray 提供了本地代理（HTTP `127.0.0.1:10809`，SOCKS5 `127.0.0.1:10808`）
3. openclaw 的 Telegram 媒体下载使用 undici 的 `fetch()`，且**不走 `globalDispatcher`**，而是通过 `account.config.proxy` 配置创建独立的 `ProxyAgent` + `dispatcher` 参数

关键源码路径（`/usr/local/lib/node_modules/openclaw/dist/`）：
- `send-BNes3XH_.js:1037`：`const proxyUrl = account.config.proxy?.trim()`
- `send-BNes3XH_.js:1038`：`resolveTelegramFetch(proxyUrl ? makeProxyFetch(proxyUrl) : void 0, ...)`
- `proxy-DU7W9XSc.js`：`makeProxyFetch` 用 `new ProxyAgent(proxyUrl)` + `fetch(input, { dispatcher: agent })`
- `local-roots-CiMZVqut.js:55`：`fetchWithSsrFGuard` 中 `const fetcher = params.fetchImpl ?? globalThis.fetch`

## 尝试过的方案（均失败）

### 方案1：proxychains4 -q openclaw gateway run（2-22）
- 结果：proxychains4 的 exec 逻辑干扰了 Node.js ESM 模块加载，报 `Cannot find module '/usr/local/bin/openclaw'`

### 方案2：LD_PRELOAD 注入 libproxychains（2-22）
- 结果：劫持了所有 socket 操作，包括 Gateway 自身的端口监听，导致 Gateway 无法启动

### 方案3：undici setGlobalDispatcher + proxy-bootstrap.cjs（2-22）
- `NODE_OPTIONS="--require proxy-bootstrap.cjs"` 预加载，调用 `setGlobalDispatcher(new ProxyAgent(url))`
- 多次延迟重设 dispatcher 防止覆盖
- 结果：**失败**。openclaw 的 Telegram fetch 不走 globalDispatcher，而是自建 dispatcher

### 方案4：proxychains4 -q node /usr/local/bin/openclaw（2-23）
- 绕过 shebang 解析，直接包裹 node 进程
- 配置 localnet 排除本地连接
- 结果：**失败**。undici 内部不走标准 `connect()` 系统调用，proxychains4 的 LD_PRELOAD 劫持对 undici 无效
- 验证：`proxychains4 -q node -e "fetch('https://api.telegram.org')..."` → `FAIL fetch failed`

### 方案5：锁定 setGlobalDispatcher 防覆盖（2-23）
- 用 `Object.defineProperty` 风格拦截 `undici.setGlobalDispatcher`，阻止非 ProxyAgent 的覆盖
- 验证：独立测试通过（`OK 200`），但 openclaw 实际运行仍失败
- 结果：**失败**。根因不是 dispatcher 被覆盖，而是 openclaw 根本不走 globalDispatcher

### 方案6：patch net.Socket.prototype.connect（2-23）
- 在 TCP 层面劫持 `net.Socket.connect`，对非本地连接做 SOCKS5 握手
- 结果：**失败**。undici 的 fetch 虽然最终调用了 `tls.connect` → `net.Socket.connect`，但 SOCKS5 握手与 TLS 握手时序冲突，无法正确建立隧道

## 最终方案：openclaw 原生 proxy 配置（成功）

通过源码分析发现 openclaw 原生支持 `account.config.proxy` 字段，内部使用 undici `ProxyAgent` + `fetch(input, { dispatcher })` 实现代理。

### 修改：sync_config.py
- `sync_telegram()` 中检测 V2Ray 环境变量（`VLESS_ADDRESS` 或 `SS_ADDRESS`）
- 存在时自动设置 `proxy: "http://127.0.0.1:10809"`
- channel 级别和每个 account 级别都设置（覆盖单账号和多账号模式）

### 修改：Dockerfile
- 去掉 `undici` 全局安装（不再需要）
- 去掉 `COPY proxy-bootstrap.cjs`（不再需要）

### 修改：init.sh
- 去掉 `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY` 环境变量
- 去掉 `NODE_OPTIONS="--require proxy-bootstrap.cjs"`
- V2Ray 就绪时仅保留 `NODE_OPTIONS="--dns-result-order=ipv4first"`

## 技术要点

- Node.js 22/24 的 `fetch()` 基于 undici，**不读** `HTTP_PROXY`/`HTTPS_PROXY` 环境变量
- `undici.setGlobalDispatcher()` 只影响直接调用 `globalThis.fetch` 的代码；如果库自建 `Client`/`Pool` 或传入 `dispatcher` 参数则不受影响
- proxychains4 的 `LD_PRELOAD` 劫持 `connect()` 对 undici 无效（undici 有自己的网络栈）
- patch `net.Socket.prototype.connect` 理论上可行，但与 TLS 握手时序冲突难以解决
- **最可靠的方案是使用应用自身的代理配置**，而非外部注入
- `--dns-result-order=ipv4first` 解决 IPv6 优先但不可达的问题（辅助措施）
