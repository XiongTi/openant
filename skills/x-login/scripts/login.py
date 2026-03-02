#!/usr/bin/env python3
"""
X/Twitter Login Script
- 使用环境变量 AUTH_TOKEN 和 CT0 登录 X
- 自动保存 cookies 到文件
- 检测 cookie 是否过期，过期则提示用户
"""

import os
import sys
import json
from playwright.sync_api import sync_playwright

COOKIES_FILE = '/home/node/.openclaw/workspace/x_cookies.json'
PROXY = 'http://127.0.0.1:10809'

def get_auth_from_env():
    """从环境变量获取认证信息"""
    auth_token = os.environ.get('AUTH_TOKEN', '')
    ct0 = os.environ.get('CT0', '')
    return auth_token, ct0

def save_cookies(context):
    """保存 cookies 到文件"""
    cookies = context.cookies()
    with open(COOKIES_FILE, 'w') as f:
        json.dump(cookies, f)
    print(f"Cookies saved to {COOKIES_FILE}")

def load_cookies():
    """从文件加载 cookies"""
    if os.path.exists(COOKIES_FILE):
        with open(COOKIES_FILE, 'r') as f:
            return json.load(f)
    return None

def check_login(page):
    """检查是否已登录"""
    # 尝试访问首页，看是否跳转到 home
    page.goto('https://x.com', timeout=15000)
    page.wait_for_timeout(3000)
    
    url = page.url
    if '/home' in url or '/i/flow' not in url:
        return True
    return False

def login_with_env():
    """使用环境变量登录"""
    auth_token, ct0 = get_auth_from_env()
    
    if not auth_token or not ct0:
        print("ERROR: AUTH_TOKEN or CT0 not found in environment variables")
        print("Please set these variables and try again")
        sys.exit(1)
    
    print(f"Using auth_token: {auth_token[:20]}...")
    print(f"Using ct0: {ct0[:20]}...")
    
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=['--proxy-server=' + PROXY, '--no-sandbox', '--disable-gpu']
        )
        
        context = browser.new_context()
        context.add_cookies([
            {'name': 'auth_token', 'value': auth_token, 'domain': '.x.com', 'path': '/'},
            {'name': 'ct0', 'value': ct0, 'domain': '.x.com', 'path': '/'}
        ])
        
        page = context.new_page()
        page.goto('https://x.com', timeout=30000)
        page.wait_for_timeout(3000)
        
        # 检查是否登录成功
        if check_login(page):
            print("Login successful!")
            save_cookies(context)
        else:
            print("Login failed - cookies may be expired")
            sys.exit(1)
        
        browser.close()

def login_with_cookies():
    """使用保存的 cookies 登录"""
    cookies = load_cookies()
    
    if not cookies:
        print("No cookies found, please login with environment variables first")
        sys.exit(1)
    
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=['--proxy-server=' + PROXY, '--no-sandbox', '--disable-gpu']
        )
        
        context = browser.new_context()
        context.add_cookies(cookies)
        
        page = context.new_page()
        
        if check_login(page):
            print("Login successful with saved cookies!")
        else:
            print("Cookies expired, please refresh with new AUTH_TOKEN and CT0")
            sys.exit(1)
        
        browser.close()

def main():
    import argparse
    parser = argparse.ArgumentParser(description='X Login Tool')
    parser.add_argument('--refresh', action='store_true', help='Force refresh with env variables')
    parser.add_argument('--check', action='store_true', help='Check login status')
    
    args = parser.parse_args()
    
    if args.refresh:
        print("=== Refreshing with environment variables ===")
        login_with_env()
    elif args.check:
        print("=== Checking login status ===")
        login_with_cookies()
    else:
        # 默认先尝试用 cookies，失败再问用户
        print("=== Attempting login with saved cookies ===")
        try:
            login_with_cookies()
        except SystemExit:
            print("\nCookies expired or not found. Please provide new AUTH_TOKEN and CT0")
            print("Set them as environment variables and run with --refresh")
            sys.exit(1)

if __name__ == '__main__':
    main()
