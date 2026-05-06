# GOST 一键部署脚本 (OnekeyGost)

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![GOST v2](https://img.shields.io/badge/GOST%20v2-2.12.0-green.svg)](https://github.com/ginuerzh/gost)
[![GOST v3](https://img.shields.io/badge/GOST%20v3-3.2.6-blue.svg)](https://github.com/go-gost/gost)

一个功能完善的 GOST 代理/隧道一键部署管理脚本。**同时支持 GOST v2 和 v3**，启动时可自由切换。

## 功能特性

- ✅ **双版本支持**：启动时选择 GOST v2 或 v3，各自独立的菜单与配置生成逻辑
- ✅ **一键安装/卸载/更新** GOST
- ✅ **自动检测**系统和 CPU 架构
- ✅ 支持**国内镜像加速**下载
- ✅ **systemd 服务**管理
- ✅ 多种转发配置支持：
  - TCP/UDP 端口转发
  - 加密隧道 (TLS/WS/WSS + **gRPC/QUIC** [v3])
  - HTTP/SOCKS5 代理
  - Shadowsocks 代理
  - 负载均衡
  - **SNI 代理** [v3]
  - **反向代理隧道**（内网穿透）[v3]
- ✅ **TLS 证书管理** (ACME 自动申请)
- ✅ **定时重启**任务配置

## GOST v2 与 v3 对比

| 维度 | GOST v2 | GOST v3 |
|------|---------|---------|
| 仓库 | `ginuerzh/gost` | `go-gost/gost` |
| 配置格式 | JSON（ServeNodes/Routes） | **YAML**（services/chains，模块化） |
| 协议 | TCP/UDP/TLS/WS/WSS/HTTP/SOCKS5/SS | **v2 全部 + gRPC/QUIC/HTTP2/HTTP3/KCP/SSH/SNI** |
| 反向代理 | 不支持 | ✅ 原生 rtcp/rudp |
| TUN/TAP | 不支持 | ✅ 支持 |
| Web API | 不支持 | ✅ 支持动态配置与热加载 |
| 监控指标 | 无 | ✅ Prometheus metrics |
| 维护状态 | 基本停滞 | 活跃维护 |

**建议**：新部署优先选择 **v3**；有既有 v2 配置迁移成本考虑时可继续使用 v2。

## 快速开始

### 一键安装脚本

```bash
# 下载脚本
wget -O gost.sh https://raw.githubusercontent.com/jlu3389/OnekeyGost/main/gost.sh

# 添加执行权限
chmod +x gost.sh

# 运行脚本
sudo ./gost.sh
```

### 或者使用 curl

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jlu3389/OnekeyGost/main/gost.sh)
```

## 使用方法

### 启动流程

```
脚本启动 → 选择 v2 或 v3 菜单模式 → 进入对应版本的管理菜单
```

首次启动会出现版本选择器：

```
  请选择 GOST 版本
────────────────────────────────────────────────────────

  [1] GOST v2  (ginuerzh/gost)
      • 协议: TCP/UDP/TLS/WS/WSS/HTTP/SOCKS5/SS
      • 配置: JSON (ServeNodes/Routes/ChainNodes)
      • 状态: 原作者已基本停止维护

  [2] GOST v3  (go-gost/gost) [推荐]
      • 协议: v2 全部 + gRPC/QUIC/HTTP2/HTTP3/KCP/SSH/SNI
               + 反向代理隧道/TUN/TAP/透明代理
      • 配置: YAML (services/chains，结构化、模块化)
      • 特点: 支持 Web API 动态配置、热加载、限速、监控指标
      • 状态: 活跃维护

  提示: v2 与 v3 配置文件格式不兼容，二进制与配置同路径互斥。
```

### 主菜单

```
  当前模式: GOST v3
  已安装版本: v3.2.6 (主版本 v3)
  运行状态: 运行中
────────────────────────────────────────────────────────

  安装管理
    [1] 安装 GOST
    [2] 更新 GOST
    [3] 卸载 GOST

  服务控制
    [4] 启动    [5] 停止    [6] 重启
    [7] 状态    [8] 日志

  配置管理
    [9]  添加转发规则
    [10] 查看当前配置
    [11] 删除转发规则

  高级功能
    [12] TLS 证书管理
    [13] 定时重启设置
    [14] 切换 v2/v3 菜单模式

    [0]  退出
```

## 支持的系统

| 系统 | 版本 |
|------|------|
| CentOS | 7, 8, 9 |
| Debian | 9, 10, 11, 12 |
| Ubuntu | 18.04, 20.04, 22.04, 24.04 |

## 支持的架构

- x86_64 (amd64)
- aarch64 (arm64)
- armv7l
- armv6l
- i386/i686

## 配置类型说明

### 1. TCP/UDP 端口转发

将本机端口的流量转发到目标地址，不加密。

**使用场景**：简单的端口映射、游戏加速等

```
本机:8080 → 目标服务器:80
```

### 2. 加密隧道转发 (中转机)

在中转机上配置，将流量加密后转发到落地机。

**支持的加密类型**：
- TLS 隧道
- WebSocket (WS) 隧道
- WebSocket + TLS (WSS) 隧道

**使用场景**：需要加密传输的场景

### 3. 解密隧道接收 (落地机)

在落地机上配置，接收并解密来自中转机的流量。

**注意**：加密类型需要与中转机对应

### 4. HTTP/SOCKS5 代理

在本机启动代理服务器。

**支持的类型**：
- HTTP 代理
- SOCKS5 代理
- HTTP + SOCKS5 (同端口)

### 5. Shadowsocks 代理

启动 Shadowsocks 服务。

**支持的加密方式**：
- aes-256-gcm (推荐)
- chacha20-ietf-poly1305 (推荐)
- aes-128-gcm
- aes-256-cfb
- aes-128-cfb
- chacha20

### 6. 负载均衡

将流量分发到多个后端服务器。

**支持的策略**：
- round - 轮询
- random - 随机
- fifo - 顺序优先

## 文件位置

| 文件 | 路径 |
|------|------|
| GOST 程序 | `/usr/local/bin/gost` |
| 配置目录 | `/etc/gost/` |
| 配置文件 (v2) | `/etc/gost/config.json` |
| 配置文件 (v3) | `/etc/gost/gost.yml` |
| 版本标记 | `/etc/gost/.major_version` |
| 服务文件 | `/etc/systemd/system/gost.service` |
| 证书目录 | `~/gost_cert/` |

> v2 和 v3 的二进制与配置采用**同路径互斥**：同一时间只能运行一个版本。脚本会将主版本号写入 `.major_version` 文件以供识别，切换版本请通过菜单 `[14]` 或重新运行脚本。

## 常用命令

```bash
# 服务管理
sudo systemctl start gost    # 启动
sudo systemctl stop gost     # 停止
sudo systemctl restart gost  # 重启
sudo systemctl status gost   # 状态
sudo systemctl enable gost   # 开机自启

# 查看日志
sudo journalctl -u gost -f           # 实时日志
sudo journalctl -u gost -n 100       # 最近100条
sudo journalctl -u gost --since today # 今天的日志

# 手动运行 (调试)
sudo /usr/local/bin/gost -C /etc/gost/config.json -D
```

## 配置示例

### 端口转发示例

```json
{
    "ServeNodes": [
        "tcp://:8080/192.168.1.100:80",
        "udp://:8080/192.168.1.100:80"
    ]
}
```

### 加密隧道示例

**中转机配置**：
```json
{
    "Routes": [
        {
            "ServeNodes": ["tcp://:443", "udp://:443"],
            "ChainNodes": ["relay+tls://落地机IP:443"]
        }
    ]
}
```

**落地机配置**：
```json
{
    "ServeNodes": [
        "relay+tls://:443/127.0.0.1:8080"
    ]
}
```

### SOCKS5 代理示例

```json
{
    "ServeNodes": [
        "socks5://admin:password@:1080"
    ]
}
```

### Shadowsocks 示例

```json
{
    "ServeNodes": [
        "ss://aes-256-gcm:password@:8388"
    ]
}
```

## TLS 证书

### 自动申请 (ACME)

脚本支持通过 ACME 自动申请 Let's Encrypt 证书：

1. HTTP 验证 - 需要 80 端口可用
2. Cloudflare DNS 验证 - 需要 API Key

### 手动上传

将证书文件上传到 `~/gost_cert/` 目录：
- `cert.pem` - 证书文件
- `key.pem` - 私钥文件

## 常见问题

### Q: 安装失败怎么办？

A: 检查以下几点：
1. 是否使用 root 权限运行
2. 网络是否正常（可尝试国内镜像）
3. 系统是否在支持列表中

### Q: 服务启动失败？

A: 查看日志排查：
```bash
sudo journalctl -u gost -n 50
```

常见原因：
- 端口被占用
- 配置文件格式错误
- 证书文件不存在

### Q: 如何查看当前配置？

A: 
```bash
# 通过脚本查看
sudo ./gost.sh
# 选择 [10] 查看当前配置

# 或直接查看配置文件
cat /etc/gost/config.json
```

### Q: 如何完全卸载？

A:
```bash
sudo ./gost.sh
# 选择 [3] 卸载 GOST
# 选择删除配置文件和证书
```

## 参考文档

- [GOST v3 官方文档](https://gost.run) （推荐）
- [GOST v3 GitHub 仓库](https://github.com/go-gost/gost)
- [GOST v2 官方文档](https://v2.gost.run)
- [GOST v2 GitHub 仓库](https://github.com/ginuerzh/gost)

## 致谢

- [ginuerzh/gost](https://github.com/ginuerzh/gost) - GOST 项目作者
- [KANIKIG/Multi-EasyGost](https://github.com/KANIKIG/Multi-EasyGost) - 参考脚本

## License

MIT License

## 更新日志

### v2.0.0

- **新增 GOST v3 支持**（go-gost/gost）
  - 启动时选择 v2 / v3 菜单模式
  - v3 使用 YAML 配置文件（gost.yml）
  - 自动适配不同仓库的 release 包命名与下载
- v3 独有协议：
  - gRPC 加密隧道
  - QUIC 加密隧道（基于 UDP）
  - SNI 代理（基于 TLS SNI 的透明转发）
  - 反向代理隧道（rtcp，内网穿透）
- v2 逻辑完全向后兼容
- 主菜单新增 `[14] 切换 v2/v3 菜单模式`

### v1.0.0 (2024-01-21)

- 初始版本发布
- 支持 GOST v2.12.0
- 完整的安装/卸载/更新功能
- 多种转发配置支持
- TLS 证书管理
- 定时重启设置
