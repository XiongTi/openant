#!/usr/bin/env python3
"""OpenClaw 配置同步脚本：根据环境变量更新 openclaw.json"""

import json
import sys
import os
from datetime import datetime

CONFIG_PATH = sys.argv[1] if len(sys.argv) > 1 else '/home/node/.openclaw/openclaw.json'


def ensure_path(cfg, keys):
    curr = cfg
    for k in keys:
        if k not in curr:
            curr[k] = {}
        curr = curr[k]
    return curr


def migrate_feishu(config):
    """飞书旧版本格式迁移"""
    feishu_raw = config.get('channels', {}).get('feishu', {})
    if 'appId' in feishu_raw and 'accounts' not in feishu_raw:
        print('检测到飞书旧版本格式，执行迁移...')
        old_app_id = feishu_raw.pop('appId', '')
        old_app_secret = feishu_raw.pop('appSecret', '')
        old_bot_name = feishu_raw.pop('botName', 'OpenClaw Bot')
        feishu_raw['accounts'] = {
            'main': {'appId': old_app_id, 'appSecret': old_app_secret, 'botName': old_bot_name}
        }


def sync_model(config, env):
    """模型与工作区同步"""
    if not (env.get('API_KEY') and env.get('BASE_URL')):
        return

    p = ensure_path(config, ['models', 'providers', 'default'])
    p['baseUrl'] = env['BASE_URL']
    p['apiKey'] = env['API_KEY']
    p['api'] = env.get('API_PROTOCOL') or 'openai-completions'

    mid = env.get('MODEL_ID') or 'gpt-4o'
    mlist = p.get('models', [])
    m_obj = next((m for m in mlist if m.get('id') == mid), None)
    if not m_obj:
        m_obj = {
            'id': mid, 'name': mid, 'reasoning': False,
            'input': ['text', 'image'],
            'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
        }
        mlist.append(m_obj)

    m_obj['contextWindow'] = int(env.get('CONTEXT_WINDOW') or 200000)
    m_obj['maxTokens'] = int(env.get('MAX_TOKENS') or 8192)
    p['models'] = mlist

    ensure_path(config, ['agents', 'defaults', 'model'])['primary'] = f'default/{mid}'
    ensure_path(config, ['agents', 'defaults', 'imageModel'])['primary'] = f'default/{mid}'
    config['agents']['defaults']['workspace'] = env.get('WORKSPACE') or '/home/node/.openclaw/workspace'

    print(f'✅ 模型与工作区同步: {mid}')


def sync_agents(config, env):
    """多 Agent 同步"""
    agents_json = env.get('OPENCLAW_AGENTS')
    if not agents_json:
        return

    agent_list = json.loads(agents_json)
    home = '/home/node/.openclaw'
    for a in agent_list:
        ws = a.get('workspace', '')
        if ws and not ws.startswith('/'):
            a['workspace'] = f'{home}/{ws}'

    config['agents']['list'] = agent_list
    if agent_list:
        agent_list[0]['default'] = True

    for a in agent_list:
        ws = a.get('workspace', '')
        if ws:
            os.makedirs(ws, exist_ok=True)

    agent_ids = [a.get('id') for a in agent_list]
    print(f'✅ 多 Agent 同步: {agent_ids}')


def sync_memory(config, env):
    """Memory (QMD) 配置同步：根据已同步的 agent 列表生成 memory.qmd.paths"""
    agent_list = config.get('agents', {}).get('list', [])
    if not agent_list:
        return

    # 为每个 agent 生成 memory.qmd.paths 配置
    memory_paths = []
    for a in agent_list:
        ws = a.get('workspace', '')
        if ws:
            memory_paths.append({
                'path': ws,
                'name': a.get('id', 'default'),
                'pattern': '**/*.md'
            })

    # 设置 memory.qmd.paths
    if memory_paths:
        ensure_path(config, ['memory', 'qmd'])['paths'] = memory_paths
        print(f'✅ Memory (QMD) 同步: {[p["name"] for p in memory_paths]}')


# --- 渠道同步函数 ---

def sync_feishu(c, e):
    c.update({'enabled': True, 'dmPolicy': 'pairing', 'groupPolicy': 'open'})
    main = ensure_path(c, ['accounts', 'main'])
    main.update({
        'appId': e['FEISHU_APP_ID'],
        'appSecret': e['FEISHU_APP_SECRET'],
        'botName': e.get('FEISHU_BOT_NAME') or 'OpenClaw Bot',
    })
    if e.get('FEISHU_DOMAIN'):
        main['domain'] = e['FEISHU_DOMAIN']


def sync_dingtalk(c, e, config):
    c.update({
        'enabled': True,
        'dmPolicy': 'open', 'groupPolicy': 'open', 'messageType': 'markdown',
    })

    raw_id = e['DINGTALK_CLIENT_ID']
    raw_secret = e['DINGTALK_CLIENT_SECRET']

    def parse_kv(raw):
        """解析 name:value,name2:value2 格式"""
        result = {}
        for part in raw.split(','):
            part = part.strip()
            if not part:
                continue
            sep = part.index(':')
            result[part[:sep]] = part[sep + 1:]
        return result

    if ':' in raw_id:
        # 多账号格式（含单账号）: bot1:appkey1 或 bot1:appkey1,bot2:appkey2
        id_map = parse_kv(raw_id)
        secret_map = parse_kv(raw_secret)

        accounts = {}
        for acct_name, client_id in id_map.items():
            client_secret = secret_map.get(acct_name, '')
            accounts[acct_name] = {
                'clientId': client_id,
                'clientSecret': client_secret,
                'robotCode': client_id,
                'messageType': 'markdown',
            }
        c['accounts'] = accounts
        print(f'  DingTalk 账号: {list(accounts.keys())}')
    else:
        # 旧格式兼容：纯 appkey
        c['clientId'] = raw_id
        c['clientSecret'] = raw_secret
        c['robotCode'] = e.get('DINGTALK_ROBOT_CODE') or raw_id
        if e.get('DINGTALK_CORP_ID'):
            c['corpId'] = e['DINGTALK_CORP_ID']
        if e.get('DINGTALK_AGENT_ID'):
            c['agentId'] = e['DINGTALK_AGENT_ID']
        print(f'  DingTalk 账号: default')

    # 处理 bindings
    bindings_raw = e.get('DINGTALK_BINDINGS')
    if bindings_raw:
        bindings = config.get('bindings', [])
        bindings = [b for b in bindings if b.get('match', {}).get('channel') != 'dingtalk']
        for part in bindings_raw.split(','):
            part = part.strip()
            if not part:
                continue
            sep = part.index(':')
            bindings.append({
                'agentId': part[sep + 1:],
                'match': {'channel': 'dingtalk', 'accountId': part[:sep]},
            })
        config['bindings'] = bindings
        print(f'  DingTalk bindings: {bindings}')


def sync_wecom(c, e):
    c.update({'enabled': True, 'token': e['WECOM_TOKEN'], 'encodingAesKey': e['WECOM_ENCODING_AES_KEY']})
    if 'commands' not in c:
        c['commands'] = {'enabled': True, 'allowlist': ['/new', '/status', '/help', '/compact']}


def sync_telegram(c, e, config):
    c.update({'enabled': True, 'dmPolicy': 'pairing', 'groupPolicy': 'allowlist', 'streamMode': 'partial'})
    c['groups'] = {'*': {'groupPolicy': 'open', 'requireMention': False}}
    c.pop('botToken', None)

    # 代理配置：openclaw 原生支持 account.config.proxy
    # 当配置了 V2Ray（VLESS 或 SS）时，使用本地 HTTP 代理
    proxy_url = ''
    if e.get('VLESS_ADDRESS') or e.get('SS_ADDRESS'):
        proxy_url = 'http://127.0.0.1:10809'
    if proxy_url:
        c['proxy'] = proxy_url

    raw = e['TELEGRAM_BOT_TOKEN']

    # 判断是否多账号格式：name:数字:token
    # Telegram token 本身格式是 数字:字母，所以第一个 : 前如果不是纯数字就是账号名
    first_colon = raw.find(':')
    is_named = first_colon > 0 and not raw[:first_colon].isdigit()

    if is_named:
        # 多账号格式（含单账号）: name:数字:token 或 name1:数字:token1,name2:数字:token2
        accounts = {}
        for part in raw.split(','):
            part = part.strip()
            if not part:
                continue
            sep = part.index(':')
            acct_name = part[:sep]
            acct_token = part[sep + 1:]
            acct_cfg = {'botToken': acct_token}
            if proxy_url:
                acct_cfg['proxy'] = proxy_url
            accounts[acct_name] = acct_cfg
        c['accounts'] = accounts
        print(f'  Telegram 账号: {list(accounts.keys())}')
    else:
        # 旧格式兼容：纯 token（数字:字母）
        c['botToken'] = raw
        print(f'  Telegram 账号: default')

    bindings_raw = e.get('TELEGRAM_BINDINGS')
    if bindings_raw:
        bindings = config.get('bindings', [])
        bindings = [b for b in bindings if b.get('match', {}).get('channel') != 'telegram']
        for part in bindings_raw.split(','):
            part = part.strip()
            if not part:
                continue
            sep = part.index(':')
            bindings.append({
                'agentId': part[sep + 1:],
                'match': {'channel': 'telegram', 'accountId': part[:sep]},
            })
        config['bindings'] = bindings
        print(f'  Telegram bindings: {bindings}')

def sync_channels(config, env):
    """渠道与插件同步"""
    channels = ensure_path(config, ['channels'])
    entries = ensure_path(config, ['plugins', 'entries'])
    installs = ensure_path(config, ['plugins', 'installs'])

    sync_rules = [
        (['TELEGRAM_BOT_TOKEN'], 'telegram',
         lambda c, e: sync_telegram(c, e, config), None),
        (['FEISHU_APP_ID', 'FEISHU_APP_SECRET'], 'feishu', sync_feishu,
         {'source': 'npm', 'spec': '@openclaw/feishu',
          'installPath': '/home/node/.openclaw/extensions/feishu'}),
        (['DINGTALK_CLIENT_ID', 'DINGTALK_CLIENT_SECRET'], 'dingtalk',
         lambda c, e: sync_dingtalk(c, e, config),
         {'source': 'npm', 'spec': '@soimy/dingtalk',
          'installPath': '/home/node/.openclaw/extensions/openclaw-channel-dingtalk'}),
        (['QQBOT_APP_ID', 'QQBOT_CLIENT_SECRET'], 'qqbot',
         lambda c, e: c.update({'enabled': True, 'appId': e['QQBOT_APP_ID'], 'clientSecret': e['QQBOT_CLIENT_SECRET']}),
         {'source': 'path', 'sourcePath': '/home/node/.openclaw/qqbot',
          'installPath': '/home/node/.openclaw/extensions/qqbot'}),
        (['WECOM_TOKEN', 'WECOM_ENCODING_AES_KEY'], 'wecom', sync_wecom,
         {'source': 'npm', 'spec': '@sunnoy/wecom',
          'installPath': '/home/node/.openclaw/extensions/wecom'}),
    ]

    for req_envs, cid, config_fn, install_info in sync_rules:
        has_env = all(env.get(k) for k in req_envs)
        if has_env:
            conf_obj = ensure_path(channels, [cid])
            config_fn(conf_obj, env)
            entries[cid] = {'enabled': True}
            if install_info and cid not in installs:
                install_info['installedAt'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
                installs[cid] = install_info
            print(f'✅ 渠道同步: {cid}')
        else:
            if cid in entries and entries[cid].get('enabled'):
                entries[cid]['enabled'] = False
                print(f'🚫 环境变量缺失，已禁用渠道: {cid}')


def sync_gateway(config, env):
    """Gateway 同步"""
    if not env.get('OPENCLAW_GATEWAY_TOKEN'):
        return
    gw = ensure_path(config, ['gateway'])
    gw['port'] = int(env.get('OPENCLAW_GATEWAY_PORT') or 18789)
    gw['bind'] = env.get('OPENCLAW_GATEWAY_BIND') or '0.0.0.0'
    gw['mode'] = 'local'
    ensure_path(gw, ['auth'])['token'] = env['OPENCLAW_GATEWAY_TOKEN']
    print('✅ Gateway 同步完成')


def main():
    try:
        with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
            config = json.load(f)

        env = os.environ

        migrate_feishu(config)
        sync_model(config, env)
        sync_agents(config, env)
        sync_memory(config, env)
        sync_channels(config, env)
        sync_gateway(config, env)

        ensure_path(config, ['meta'])['lastTouchedAt'] = (
            datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'
        )
        with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)

    except Exception as e:
        print(f'❌ 同步失败: {e}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
