# MEMORY.md - 长期记忆

## 关于 Grunt
- 狮子座，ENTJ 指挥官性格
- 技术风险领域助手（变更风险、故障监控、业务连续性）
- 坐标：上海
- 喜欢直接、高效的沟通

## 技术要点

### x-login (X/Twitter 登录)
- 脚本位置：`/home/node/.openclaw/skills/x-login/scripts/login.js`
- 使用 Node.js + playwright
- 登录流程：优先保存的 cookies → 失败则用环境变量 AUTH_TOKEN/CT0 → 自动保存
- 命令：
  - `node .../login.js` - 默认流程
  - `node .../login.js --check` - 检查状态
  - `node .../login.js --refresh` - 强制刷新

### jina-reader 网页抓取
- 用法：`https://r.jina.ai/` + 任意 URL
- 用途：抓取 Twitter、GitHub 等网页，返回干净 Markdown
- 示例：`https://r.jina.ai/https://twitter.com/sama`

### 浏览器代理
- Chromium 需要 `--proxy-server` 参数才走代理
- 环境变量对 Chromium 无效
- OpenClaw 当前不支持自定义 chromium 参数

### Playwright + 代理
- 用于自动登录 Twitter/X
- 需要用 `storageState` 方式加载 cookies
- 代理地址：`http://127.0.0.1:10809`

## 未解决问题
- **Telegram 语音消息**：DM 发送 2 秒语音已读但 OpenClaw 未收到，可能需要用户在 Telegram 端开启语音转文字

## 待办
- **安装 ffmpeg**：Whisper 需要 ffmpeg 才能运行

## 用户偏好
- 喜欢直接、高效的沟通
- 技术背景深厚，熟悉技术风险领域
- 关注 AI 领域动态
- **铁律**：任何修改前必须先确认细节，用户同意后再改
- **语音文件名**：根据用户要求总结，不超过10个字，存到 `voice-tmp` 目录
- **回复格式**：尽量不用表格，用列表或分段
- **搜索优先级**：优先用 Tavily，Tavily 配额用完再用 MiniMax

## 已废弃
- **bird** (X/Twitter CLI) - 不好用，网络不通，弃用
- 改用 playwright + 代理方案访问 X