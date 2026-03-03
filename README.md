## 项目简介

OpenClaw 中国 IM 插件整合版 Docker 镜像，预装并配置了飞书、钉钉、QQ机器人、企业微信等主流中国 IM 平台插件，让您可以快速部署一个支持多个中国 IM 平台的 AI 机器人网关。
魔改于：https://github.com/justlovemaki/OpenClaw-Docker-CN-IM

### 核心特性

- 🚀 **开箱即用**：预装所有中国主流 IM 平台插件
- 🔧 **灵活配置**：通过环境变量轻松配置各平台凭证
- 🐳 **Docker 部署**：一键启动，无需复杂配置
- 📦 **数据持久化**：支持配置和工作空间数据持久化
- 💻 **OpenCode AI**：内置 AI 代码助手，支持智能代码生成和分析
- 🎭 **Playwright**：预装浏览器自动化工具，支持网页操作和截图
- 🗣️ **中文 TTS**：支持中文语音合成（Text-to-Speech）
- 🤖 **Claude Code**：内置 Claude Code AI 编程助手
- 🔍 **Tavily 搜索**：集成 Tavily AI 搜索，适合科技/AI 资讯
- 🖼️ **MiniMax 图片理解**：集成 MiniMax 模型理解图片内容
- 🎤 **Whisper 语音识别**：本地 Whisper 语音转文字
- 🌐 **Jina Reader**：集成 jina.ai 网页抓取，返回干净 Markdown
- 🔎 **MiniMax 搜索**：集成 MiniMax AI 搜索，理解能力更强
- 🐦 **X 登录**：自动登录 X.com，支持 cookies 保存
- 🌍 **V2Ray 代理**：内置 V2Ray，支持 HTTP/SOCKS5 代理（10809 端口）

### 支持的平台

**IM 平台**
- ✅ 飞书（Feishu/Lark）
- ✅ 钉钉（DingTalk）
- ✅ QQ 机器人（QQ Bot）
- ✅ 企业微信（WeCom）

**集成工具**
- ✅ OpenCode AI - AI 代码助手
- ✅ Playwright - 浏览器自动化
- ✅ 中文 TTS - 语音合成

---

### AI 模型配置

本项目支持 **OpenAI 协议**和 **Claude 协议**两种 API 格式。

> 💡 **推荐模型**：推荐使用 `MiniMax2.5` 模型，该模型具有超大上下文窗口（1M tokens）、快速响应速度和优秀的性价比，非常适合作为 OpenClaw 的后端模型。

#### 基础配置参数（环境变量）

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `MODEL_ID` | 模型名称 | `model id` |
| `BASE_URL` | Provider Base URL | `http://xxxxx/v1` |
| `API_KEY` | Provider API Key | `123456` |
| `API_PROTOCOL` | API 协议类型 | `openai-completions` |
| `CONTEXT_WINDOW` | 模型上下文窗口大小 | `200000` |
| `MAX_TOKENS` | 模型最大输出 tokens | `8192` |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway 访问令牌 | `123456` |
| `OPENCLAW_GATEWAY_BIND` | 绑定地址 | `lan` |
| `OPENCLAW_GATEWAY_PORT` | Gateway 端口 | `18789` |
| `OPENCLAW_BRIDGE_PORT` | Bridge 端口 | `18790` |
| `WORKSPACE` | 工作空间目录 | `/home/node/.openclaw/workspace` |
| `OPENCLAW_AGENTS` | 多 Agent 配置（JSON 格式） | 格式：`[{"id":"sunshine","name":"Sunshine","workspace":"workspace-sunshine"},{"id":"rainyrainy","name":"RainyRainy","workspace":"workspace-rainyrainy"}] `|
| `TELEGRAM_BOT_TOKEN` | Telegram Bot Token（支持多账号：`name1:token1,name2:token2`） | - |
| `TELEGRAM_BINDINGS` | Telegram bot 绑定 Agent | 格式：`botName1:agentId1,botName2:agentId2` |
| `DINGTALK_CLIENT_ID` | 钉钉 Client ID | 支持多账号，格式：`name1:appkey1,name2:appkey2` |
| `DINGTALK_CLIENT_SECRET` | 钉钉 Client Secret | 格式需与 CLIENT_ID 对应 |
| `DINGTALK_BINDINGS` | 钉钉bot 绑定 Agent | 支持多账号，格式：`botName1:agentId1,botName2:agentId2` |
| `TAVILY_API_KEY` | Tavily 搜索 API Key | - |
| `GMAIL_APP_TOKEN` | Gmail 应用专用密码 | - |
| `QQMAIL_TOKEN` | QQ 邮箱 SMTP TOKEN | - |
| `GIT_TOKEN` | GitHub 访问令牌 | - |
| `AUTH_TOKEN` | X.com 登陆 Toke Cookie | - |
| `CT0` | X.com 登录 Cookie | - |

> 如果有这些参数不知道怎么获取，直接问大模型; 如果多agent多渠道不知道怎么配置，可以使用init-agent.sh

#### 协议类型说明

| 协议类型 | 适用模型 | Base URL 格式 | 特殊特性 |
|---------|---------|--------------|---------|
| `openai-completions` | OpenAI、Gemini 等 | 需要 `/v1` 后缀 | - |
| `anthropic-messages` | Claude | 不需要 `/v1` 后缀 | Prompt Caching、Extended Thinking |

#### 配置示例

**OpenAI 协议（Gemini 模型）**

```bash
MODEL_ID=gemini-3-flash-preview
BASE_URL=http://localhost:3000/v1
API_KEY=your-api-key
API_PROTOCOL=openai-completions
CONTEXT_WINDOW=1000000
MAX_TOKENS=8192
```

**Claude 协议（Claude 模型）**

```bash
MODEL_ID=claude-sonnet-4-5
BASE_URL=http://localhost:3000
API_KEY=your-api-key
API_PROTOCOL=anthropic-messages
CONTEXT_WINDOW=200000
MAX_TOKENS=8192
```


## 常见问题

### Q: 修改了环境变量但配置没有生效？

容器启动时只有在配置文件不存在时才会生成新配置。如需重新生成配置，请删除现有配置文件：

```bash
# 删除配置文件
rm ~/.openclaw/openclaw.json
# 重启容器
docker-compose restart
```

或者直接删除整个数据目录重新开始：

```bash
rm -rf ~/.openclaw
docker-compose up -d
```

### Q: 401 错误？

- 检查 API Key 是否正确配置
- 确认环境变量 `API_KEY` 已设置


### Q: 飞书机器人能发消息但收不到消息？

- 检查是否配置了事件订阅（最容易遗漏的配置）
- 确认事件配置方式选择了"使用长连接接收事件"
- 确认已添加 `im.message.receive_v1` 事件

### Q: Telegram 机器人如何配对？

如果需要启用 Telegram，必须提供有效的 `TELEGRAM_BOT_TOKEN`，启用后需要执行以下命令进行配对审批：

```bash
openclaw pairing approve telegram {token}
```

并且需要重启 Docker 服务使配置生效。

### Q: Telegram 如何绑定 Agent？

支持多账号配置，通过 `TELEGRAM_BINDINGS` 环境变量绑定 Bot 到指定的 Agent：

```bash
# 单账号
TELEGRAM_BOT_TOKEN=mybot:123456789:ABCDefGhi
TELEGRAM_BINDINGS=mybot:myagent

# 多账号
TELEGRAM_BOT_TOKEN=bot1:123456789:AAA,bot2:987654321:BBB
TELEGRAM_BINDINGS=bot1:agent1,bot2:agent2
```

格式说明：
- `TELEGRAM_BOT_TOKEN`: `账号名:数字:Token`（数字部分是 Telegram API 的 bot token 前缀）
- `TELEGRAM_BINDINGS`: `账号名:AgentID`


## 注意事项

1. 确保宿主机的 18789 和 18790 端口未被占用
2. 配置文件中的敏感信息（如 API 密钥、令牌）应妥善保管
3. 首次运行时会自动创建必要的目录和配置文件，包括 `openclaw.json` 配置文件，已存在时不会覆盖
4. 容器以 `node` 用户身份运行，确保挂载的卷有正确的权限
5. IM 平台配置均为可选项，可根据实际需求选择性配置
6. 使用 OpenAI 协议时，Base URL 需要包含 `/v1` 后缀
7. 使用 Claude 协议时，Base URL 不需要 `/v1` 后缀

---

## IM 平台配置

<details>
<summary><b>飞书配置</b></summary>

### 1. 获取飞书机器人凭证

1. 在 [飞书开放平台](https://open.feishu.cn/) 创建自建应用
2. 添加应用能力-机器人
3. 在凭证页面获取 **App ID** 和 **App Secret**
4. 开启所需权限（见下方）⚠️ **重要**
5. 配置事件订阅（见下方）⚠️ **重要**

### 2. 必需权限（租户级别）

| 权限 | 范围 | 说明 |
|------|------|------|
| `im:message` | 消息 | 发送和接收消息（核心权限） |
| `im:message.p2p_msg:readonly` | 私聊 | 读取发给机器人的私聊消息 |
| `im:message.group_at_msg:readonly` | 群聊 | 接收群内 @机器人 的消息 |
| `im:message:send_as_bot` | 发送 | 以机器人身份发送消息 |
| `im:resource` | 媒体 | 上传和下载图片/文件 |
| `im:chat.members:bot_access` | 群成员 | 获取群成员信息 |
| `im:chat.access_event.bot_p2p_chat:read` | 聊天事件 | 读取机器人单聊事件 |

### 3. 推荐权限（租户级别）

| 权限 | 范围 | 说明 |
|------|------|------|
| `contact:user.employee_id:readonly` | 用户信息 | 获取用户员工 ID（用于用户识别） |
| `im:message:readonly` | 读取 | 获取历史消息 |
| `application:application:self_manage` | 应用管理 | 应用自我管理 |
| `application:bot.menu:write` | 机器人菜单 | 配置机器人菜单 |
| `event:ip_list` | IP 列表 | 获取飞书服务器 IP 列表 |

### 4. 可选权限（租户级别）

| 权限 | 范围 | 说明 |
|------|------|------|
| `aily:file:read` | AI 文件读取 | 读取 AI 助手文件 |
| `aily:file:write` | AI 文件写入 | 写入 AI 助手文件 |
| `application:application.app_message_stats.overview:readonly` | 消息统计 | 查看应用消息统计概览 |
| `corehr:file:download` | 人事文件 | 下载人事系统文件 |

### 5. 用户级别权限（可选）

| 权限 | 范围 | 说明 |
|------|------|------|
| `aily:file:read` | AI 文件读取 | 以用户身份读取 AI 助手文件 |
| `aily:file:write` | AI 文件写入 | 以用户身份写入 AI 助手文件 |
| `im:chat.access_event.bot_p2p_chat:read` | 聊天事件 | 以用户身份读取机器人单聊事件 |

### 6. 事件订阅 ⚠️

**这是最容易遗漏的配置！** 如果机器人能发消息但收不到消息，请检查此项。

在飞书开放平台的应用后台，进入 **事件与回调** 页面：

1. **事件配置方式**：选择 **使用长连接接收事件**（推荐）
2. **添加事件订阅**，勾选以下事件：

| 事件 | 说明 |
|------|------|
| `im.message.receive_v1` | 接收消息（必需） |
| `im.message.message_read_v1` | 消息已读回执 |
| `im.chat.member.bot.added_v1` | 机器人进群 |
| `im.chat.member.bot.deleted_v1` | 机器人被移出群 |

3. 确保事件订阅的权限已申请并通过审核

### 7. 环境变量配置

在 `.env` 文件中添加：

```bash
FEISHU_APP_ID=your-app-id
FEISHU_APP_SECRET=your-app-secret
```

> 💡 **参考项目**：[clawdbot-feishu](https://github.com/openclaw/openclaw/blob/main/docs/channels/feishu.md) - 飞书机器人完整实现示例

</details>

<details>
<summary><b>钉钉配置</b></summary>

### 1. 创建钉钉应用

1. 访问 [钉钉开发者后台](https://open-dev.dingtalk.com/)
2. 创建企业内部应用
3. 添加「机器人」能力
4. 配置消息接收模式为 **Stream 模式**
5. 发布应用

### 2. 获取凭证

从开发者后台获取：

- **Client ID**（AppKey）
- **Client Secret**（AppSecret）
- **Robot Code**（与 Client ID 相同）
- **Corp ID**（与 Client ID 相同）
- **Agent ID**（应用 ID）

### 3. 环境变量配置

在 `.env` 文件中添加：

```bash
DINGTALK_CLIENT_ID=your-dingtalk-client-id
DINGTALK_CLIENT_SECRET=your-dingtalk-client-secret
DINGTALK_ROBOT_CODE=your-dingtalk-robot-code
DINGTALK_CORP_ID=your-dingtalk-corp-id
DINGTALK_AGENT_ID=your-dingtalk-agent-id
```

**参数说明**：
- `DINGTALK_CLIENT_ID` - 必需，钉钉应用的 Client ID（AppKey）
- `DINGTALK_CLIENT_SECRET` - 必需，钉钉应用的 Client Secret（AppSecret）
- `DINGTALK_ROBOT_CODE` - 可选，机器人 Code，默认与 Client ID 相同
- `DINGTALK_CORP_ID` - 可选，企业 ID
- `DINGTALK_AGENT_ID` - 可选，应用 Agent ID
- `DINGTALK_BINDINGS` - 可选，绑定 Bot 到 Agent（格式：`botName:agentId`）

**多 Bot 绑定示例**：

```bash
# 单账号
DINGTALK_CLIENT_ID=mybot:ding_appkey
DINGTALK_CLIENT_SECRET=mybot:secret
DINGTALK_BINDINGS=mybot:myagent

# 多账号
DINGTALK_CLIENT_ID=bot1:appkey1,bot2:appkey2
DINGTALK_CLIENT_SECRET=bot1:secret1,bot2:secret2
DINGTALK_BINDINGS=bot1:agent1,bot2:agent2
```

> 💡 **参考项目**：[openclaw-channel-dingtalk](https://github.com/soimy/openclaw-channel-dingtalk) - 钉钉渠道完整实现示例

</details>

<details>
<summary><b>QQ 机器人配置</b></summary>

### 1. 获取 QQ 机器人凭证

1. 访问 [QQ 开放平台](https://q.qq.com/)
2. 创建机器人应用
3. 获取 AppID 和 AppSecret（ClientSecret）
4. 获取主机在公网的 IP，配置到 IP 白名单

### 2. 环境变量配置

在 `.env` 文件中添加：

```bash
QQBOT_APP_ID=你的AppID
QQBOT_CLIENT_SECRET=你的AppSecret
```

> 💡 **参考项目**：[qqbot](https://github.com/sliverp/qqbot) - QQ 机器人完整实现示例

</details>

<details>
<summary><b>企业微信配置</b></summary>

### 1. 获取企业微信凭证

1. 访问 [企业微信管理后台](https://work.weixin.qq.com/)
2. 进入"应用管理" - 用 API 模式创建"智能机器人"应用
3. 在应用的"接收消息"配置中设置 Token 和 EncodingAESKey
4. 设置"接收消息"URL 为你的服务地址（例如：https://your-domain.com/webhooks/wxwork），需要当前服务可公网访问

### 2. 环境变量配置

在 `.env` 文件中添加：

```bash
WECOM_TOKEN=your-token
WECOM_ENCODING_AES_KEY=your-aes-key
```

> 💡 **参考项目**：[openclaw-plugin-wecom](https://github.com/sunnoy/openclaw-plugin-wecom) - 企业微信插件完整实现示例

</details>
