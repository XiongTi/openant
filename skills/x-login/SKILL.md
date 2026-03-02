---
name: x-login
description: |
  X/Twitter 登录工具。使用环境变量 AUTH_TOKEN 和 CT0 登录 X.com，或验证已保存的 cookies 是否有效。
  当需要执行 X/Twitter 相关操作（如发推、刷时间线、搜索）时自动触发。
---

# X Login

登录 X/Twitter 的工具，支持 cookie 过期检测和自动刷新。

## 环境变量

- `AUTH_TOKEN` - X 账户的 auth_token cookie
- `CT0` - X 账户的 ct0 cookie

## 使用方式

### 1. 检查登录状态

```bash
python3 /home/node/.openclaw/skills/x-login/scripts/login.py --check
```

### 2. 刷新登录（使用环境变量）

```bash
python3 /home/node/.openclaw/skills/x-login/scripts/login.py --refresh
```

### 3. 在 Python 代码中使用

```python
import sys
sys.path.insert(0, '/home/node/.openclaw/skills/x-login/scripts')
from login import login_with_cookies, login_with_env, load_cookies, COOKIES_FILE
```

## 登录流程

1. 优先使用保存的 cookies (`/home/node/.openclaw/workspace/x_cookies.json`)
2. 如果 cookies 无效或过期，检查环境变量 `AUTH_TOKEN` 和 `CT0`
3. 如果环境变量存在，使用它们登录并保存新的 cookies
4. 如果环境变量也不存在，提示用户设置

## Cookie 过期处理

当执行 X 操作时如果遇到登录问题，skill 会自动：
1. 尝试加载已保存的 cookies
2. 验证登录状态
3. 如果失败，提示用户刷新 cookies

**提示用户的方式**：告诉用户 "X 登录已过期，请提供新的 AUTH_TOKEN 和 CT0 环境变量"

## 代理配置

脚本使用固定代理 `http://127.0.0.1:10809`。如有需要，修改脚本中的 `PROXY` 变量。
