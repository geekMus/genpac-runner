# genpac-runner

一个基于 Docker 的 **自动生成 PAC 文件** 工具，支持 GFWList、SOCKS5/DIRECT 代理规则，并可通过 Webhook 通知成功或失败。

---

## 功能

- 自动生成 PAC 文件 (`proxy.pac`)
- 支持 GFWList URL 配置
- 支持 SOCKS5 或 HTTP 代理规则
- 支持 PAC 压缩和精确模式
- 支持 Webhook 成功/失败通知（钉钉示例）
- 内置简单 HTTP 服务，只暴露 `/proxy.pac`，浏览器直接显示 UTF-8 内容
- 支持定时任务（Cron）自动更新 PAC 文件

---

## 文件说明

| 文件 | 功能 |
|------|------|
| `Dockerfile` | Docker 构建文件，安装依赖并复制脚本 |
| `docker-compose.yml` | Docker Compose 配置，设置环境变量和端口 |
| `entrypoint.sh` | 容器入口脚本，初始化时区、生成 PAC、启动 cron 和 HTTP 服务 |
| `update.sh` | 自动生成 PAC 的脚本，并触发 webhook |
| `serve_proxy.py` | 内置 HTTP 服务，提供 `/proxy.pac` 下载或浏览器访问 |

---

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `CRON_SCHEDULE` | - | cron 表达式，控制 PAC 更新频率 |
| `TZ` | `Asia/Shanghai` | 容器时区 |
| `PAC_PROXY` | `SOCKS5 127.0.0.1:1080; DIRECT` | PAC 代理规则 |
| `PAC_COMPRESS` | `true` | 是否压缩 PAC 文件 |
| `PAC_PRECISE` | `false` | 是否精确模式 |
| `GFWLIST_URL` | `https://github.com/gfwlist/gfwlist/raw/master/gfwlist.txt` | GFWList 地址 |
| `WEBHOOK_SUCCESS_URL` | - | 成功 webhook URL，可选 |
| `WEBHOOK_SUCCESS_OPTIONS` | - | 成功 webhook JSON 配置，可选 |
| `WEBHOOK_FAILURE_URL` | - | 失败 webhook URL，可选 |
| `WEBHOOK_FAILURE_OPTIONS` | - | 失败 webhook JSON 配置，可选 |

---

## 构建与运行

### 1. 构建镜像

```bash
docker-compose build
```

