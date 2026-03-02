// 预加载脚本：为 Node.js 内置 fetch (undici) 设置全局代理，并锁定 dispatcher 防止被覆盖
// 通过 NODE_OPTIONS="--require /usr/local/bin/proxy-bootstrap.cjs" 注入
"use strict";

const PROXY_URL = process.env.HTTPS_PROXY || process.env.HTTP_PROXY || "http://127.0.0.1:10809";

try {
  const undici = require("undici");
  const agent = new undici.ProxyAgent(PROXY_URL);

  undici.setGlobalDispatcher(agent);

  // 锁定：拦截后续的 setGlobalDispatcher 调用，防止 openclaw 覆盖
  const origSetGlobal = undici.setGlobalDispatcher;
  undici.setGlobalDispatcher = function (dispatcher) {
    // 如果传入的不是 ProxyAgent，忽略这次调用
    if (dispatcher instanceof undici.ProxyAgent) {
      origSetGlobal.call(undici, dispatcher);
    } else {
      console.error("[proxy-bootstrap] blocked setGlobalDispatcher override, keeping proxy");
    }
  };

  // 同时锁定 getGlobalDispatcher 确保返回我们的 agent
  undici.getGlobalDispatcher = function () {
    return agent;
  };

  console.error("[proxy-bootstrap] Global fetch proxy locked to", PROXY_URL);
} catch (e) {
  console.error("[proxy-bootstrap] Failed:", e.message);
}
