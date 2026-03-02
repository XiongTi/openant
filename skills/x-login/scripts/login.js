#!/usr/bin/env node
/**
 * X/Twitter Login Tool
 * 
 * 登录流程（符合 SKILL.md）：
 * 1. 优先使用保存的 cookies (/home/node/.openclaw/workspace/x_cookies.json)
 * 2. 如果 cookies 无效或过期，检查环境变量 AUTH_TOKEN 和 CT0
 * 3. 如果环境变量存在，使用它们登录并保存新的 cookies
 * 4. 如果环境变量也不存在，提示用户设置
 */

const fs = require('fs');
const pw = require('playwright');

const COOKIES_FILE = '/home/node/.openclaw/workspace/x_cookies.json';
const PROXY = 'http://127.0.0.1:10809';

// ============ 核心函数 ============

function getAuthFromEnv() {
  return {
    authToken: process.env.AUTH_TOKEN || '',
    ct0: process.env.CT0 || ''
  };
}

function saveCookies(context) {
  const cookies = context.cookies();
  fs.writeFileSync(COOKIES_FILE, JSON.stringify(cookies, null, 2));
  console.log(`Cookies saved to ${COOKIES_FILE}`);
}

function loadCookies() {
  if (fs.existsSync(COOKIES_FILE)) {
    const content = fs.readFileSync(COOKIES_FILE, 'utf8');
    if (content && content !== '{}') {
      return JSON.parse(content);
    }
  }
  return null;
}

async function checkLogin(page) {
  await page.goto('https://x.com', { timeout: 15000 });
  await page.waitForTimeout(3000);
  
  const url = page.url();
  console.log('Current URL:', url);
  
  // 登录成功的标志：URL 包含 /home
  // 登录失败的标志：包含 /i/flow 或 /login 或 只是 x.com/
  if (url.includes('/home')) {
    return true;
  }
  return false;
}

async function tryLogin(cookies) {
  const browser = await pw.chromium.launch({
    headless: true,
    args: ['--proxy-server=' + PROXY, '--no-sandbox', '--disable-gpu']
  });
  
  let context;
  if (cookies) {
    // 使用 storageState 方式加载 cookies
    context = await browser.newContext({
      storageState: {
        cookies: cookies
      }
    });
  } else {
    context = await browser.newContext();
  }
  
  const page = await context.newPage();
  const loggedIn = await checkLogin(page);
  
  await browser.close();
  
  return loggedIn;
}

// ============ 主登录流程（符合 SKILL.md）============

async function login() {
  console.log('=== X Login Process ===');
  
  // 步骤 1: 尝试使用保存的 cookies
  console.log('\n[1/3] Trying saved cookies...');
  let cookies = loadCookies();
  
  if (cookies) {
    console.log('  Found saved cookies');
    const loggedIn = await tryLogin(cookies);
    if (loggedIn) {
      console.log('  ✓ Login successful with saved cookies!');
      return true;
    }
    console.log('  ✗ Saved cookies expired');
  } else {
    console.log('  No saved cookies found');
  }
  
  // 步骤 2: 检查环境变量
  console.log('\n[2/3] Checking environment variables...');
  const { authToken, ct0 } = getAuthFromEnv();
  
  if (!authToken || !ct0) {
    console.error('  ✗ AUTH_TOKEN or CT0 not found in environment');
    console.log('\n⚠️ X 登录已过期，请提供新的 AUTH_TOKEN 和 CT0 环境变量');
    return false;
  }
  
  console.log('  Found AUTH_TOKEN and CT0 in environment');
  
  // 步骤 3: 使用环境变量登录并保存
  console.log('\n[3/3] Logging in with environment variables...');
  const loggedIn = await tryLogin([
    { name: 'auth_token', value: authToken, domain: '.x.com', path: '/', secure: true },
    { name: 'ct0', value: ct0, domain: '.x.com', path: '/', secure: true }
  ]);
  
  if (loggedIn) {
    console.log('  ✓ Login successful!');
    // 直接保存环境变量的 cookie（不用从 context 读取）
    const cookiesToSave = [
      { name: 'auth_token', value: authToken, domain: '.x.com', path: '/', expires: -1, httpOnly: false, secure: true, sameSite: 'Lax' },
      { name: 'ct0', value: ct0, domain: '.x.com', path: '/', expires: -1, httpOnly: false, secure: true, sameSite: 'Lax' }
    ];
    fs.writeFileSync(COOKIES_FILE, JSON.stringify(cookiesToSave, null, 2));
    console.log('  ✓ Cookies saved!');
    return true;
  }
  
  console.error('  ✗ Login failed - cookies may be invalid');
  return false;
}

// ============ 命令行接口 ============

async function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--check')) {
    // 只检查登录状态
    console.log('=== Checking login status ===');
    const cookies = loadCookies();
    if (!cookies) {
      console.log('No saved cookies');
    }
    const loggedIn = await tryLogin(cookies);
    console.log(loggedIn ? '✓ Logged in' : '✗ Not logged in');
    process.exit(loggedIn ? 0 : 1);
    
  } else if (args.includes('--refresh')) {
    // 强制用环境变量刷新
    console.log('=== Force refresh with environment variables ===');
    const { authToken, ct0 } = getAuthFromEnv();
    if (!authToken || !ct0) {
      console.error('ERROR: AUTH_TOKEN or CT0 not found in environment');
      process.exit(1);
    }
    
    // 直接用环境变量登录并保存
    const browser = await pw.chromium.launch({
      headless: true,
      args: ['--proxy-server=' + PROXY, '--no-sandbox', '--disable-gpu']
    });
    const context = await browser.newContext();
    await context.addCookies([
      { name: 'auth_token', value: authToken, domain: '.x.com', path: '/', secure: true },
      { name: 'ct0', value: ct0, domain: '.x.com', path: '/', secure: true }
    ]);
    
    const page = await context.newPage();
    await page.goto('https://x.com', { timeout: 15000 });
    await page.waitForTimeout(3000);
    
    const url = page.url();
    console.log('Current URL:', url);
    
    if (url.includes('/home') || (!url.includes('/i/flow') && !url.includes('/login'))) {
      console.log('Login successful!');
      // 直接保存我们设置的 cookies
      const cookiesToSave = [
        { name: 'auth_token', value: authToken, domain: '.x.com', path: '/', expires: -1, httpOnly: false, secure: true, sameSite: 'Lax' },
        { name: 'ct0', value: ct0, domain: '.x.com', path: '/', expires: -1, httpOnly: false, secure: true, sameSite: 'Lax' }
      ];
      fs.writeFileSync(COOKIES_FILE, JSON.stringify(cookiesToSave, null, 2));
      console.log('Cookies saved!');
    } else {
      console.error('Login failed - cookies may be expired');
    }
    
    await browser.close();
    
  } else {
    // 默认流程：按 SKILL.md 描述的流程
    const success = await login();
    process.exit(success ? 0 : 1);
  }
}

main().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
