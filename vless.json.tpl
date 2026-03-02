  {
    "log": {
      "loglevel": "warning"
    },
    "inbounds": [
      {
        "tag": "socks-inbound",
        "port": 10808,
        "listen": "127.0.0.1",
        "protocol": "socks"
      },
      {
        "tag": "http-inbound",
        "port": 10809,
        "listen": "127.0.0.1",
        "protocol": "http"
      }
    ],
    "outbounds": [
      {
        "tag": "proxy",
        "protocol": "vless",
        "settings": {
          "vnext": [
            {
              "address": "${VLESS_ADDRESS}",
              "port": ${VLESS_PORT},
              "users": [
                {
                  "id": "${VLESS_UUID}",
                  "encryption": "none"
                }
              ]
            }
          ]
        },
        "streamSettings": {
          "network": "ws",
          "security": "tls",
          "tlsSettings": {
            "serverName": "${VLESS_SNI}"
          },
          "wsSettings": {
            "path": "${VLESS_WS_PATH}",
            "headers": {
              "Host": "${VLESS_SNI}"
            }
          }
        }
      },
      {
        "tag": "google-proxy",
        "protocol": "shadowsocks",
        "settings": {
          "servers": [
            {
              "address": "${SS_ADDRESS}",
              "port": ${SS_PORT},
              "method": "chacha20-ietf-poly1305",
              "password": "${SS_PASSWORD}"
            }
          ]
        }
      },
      {
        "tag": "direct",
        "protocol": "freedom"
      },
      {
        "tag": "block",
        "protocol": "blackhole"
      }
    ],
    "routing": {
      "domainStrategy": "IPIfNonMatch",
      "rules": [
        {
          "type": "field",
          "outboundTag": "direct",
          "domain": ["localhost", "geosite:cn"]
        },
        {
          "type": "field",
          "outboundTag": "direct",
          "ip": ["geoip:private", "geoip:cn"]
        },
        {
          "type": "field",
          "outboundTag": "google-proxy",
          "domain": [
            "domain:google.com",
            "domain:googleapis.com",
            "domain:googlevideo.com",
            "domain:gstatic.com",
            "domain:google.co.jp",
            "domain:gemini.google.com",
            "domain:generativelanguage.googleapis.com",
            "domain:aistudio.google.com",
            "domain:accounts.google.com"
          ]
        },
        {
          "type": "field",
          "outboundTag": "proxy",
          "network": "tcp,udp"
        }
      ]
    }
  }
