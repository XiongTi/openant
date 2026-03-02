#!/bin/bash
pkill -f "v2ray run" && sleep 1
/opt/v2ray/v2ray run -config /home/node/.openclaw/v2ray.json &
echo "V2Ray 已重启 (PID: $!)"
