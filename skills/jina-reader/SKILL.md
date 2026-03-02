---
name: jina-reader
description: 使用 jina.ai Reader 抓取任意网页内容，返回干净 Markdown。用于：(1) 读取完整网页内容（绕过 JavaScript/付费墙），(2) 抓取 Twitter/X 推文，(3) 获取结构化 meta 数据。触发条件：用户要求读取网页内容、获取 Twitter 推文、抓取文章全文。
---

# jina-reader �读取

用 jina.ai Reader 抓取任意网页，绕过 JavaScript 和付费墙。

## 用法

在任意 URL 前面加上 `https://r.jina.ai/` 前缀：

```
https://r.jina.ai/https://example.com/article
```

## 示例

### 读取文章
```
URL: https://r.jina.ai/https://36kr.com/news/
```

### 抓取 Twitter
```
URL: https://r.jina.ai/https://twitter.com/sama
URL: https://r.jina.ai/https://twitter.com/elonmusk/status/123456789
```

### 抓取 GitHub
```
URL: https://r.jina.ai/https://github.com/openclaw/openclaw
```

## 使用工具

用 `web_fetch` 工具，URL 填 `https://r.jina.ai/` + 目标 URL。

示例：
```
web_fetch(url="https://r.jina.ai/https://twitter.com/sama")
```

## 注意事项

- 免费，无需 API key
- 返回干净的 Markdown，AI 友好
- 支持 Twitter/X（很多工具搞不定）
- 能绕过付费墙
