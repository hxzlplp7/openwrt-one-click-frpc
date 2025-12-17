# OpenWrt/iStoreOS FRPC 一键管理脚本

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-OpenWrt%20%7C%20iStoreOS-brightgreen.svg)](https://openwrt.org/)

一个用于 OpenWrt/iStoreOS 路由器的 FRPC 内网穿透一键管理脚本，支持快速连接到您的 FRPS 服务器。

## ✨ 功能特性

- 🚀 **一键安装**: 自动检测系统架构并下载安装对应版本的 FRPC
- 🔧 **交互式配置**: 简单易用的配置向导
- 📡 **多种代理类型**: 支持 TCP、UDP、HTTP、HTTPS、STCP、XTCP 等
- 🎯 **快速部署**: 内置常用场景模板(路由器管理、SSH、远程桌面、NAS等)
- 📊 **状态监控**: 实时查看运行状态和连接信息
- 📝 **日志管理**: 查看和清理运行日志
- 🔄 **开机自启**: 支持开机自动启动

## 📦 安装方法

### 方法一：一键安装 (推荐)

```bash
# 下载脚本
wget -O /usr/bin/frpc-manager https://raw.githubusercontent.com/hxzlplp7/openwrt-one-click-frpc/main/frpc-manager.sh

# 添加执行权限
chmod +x /usr/bin/frpc-manager

# 运行脚本
frpc-manager
```

### 方法二：手动安装

```bash
# 下载脚本
wget -O frpc-manager.sh https://raw.githubusercontent.com/hxzlplp7/openwrt-one-click-frpc/main/frpc-manager.sh

# 添加执行权限
chmod +x frpc-manager.sh

# 运行脚本
./frpc-manager.sh
```

## 🖥️ 使用方法

### 交互式菜单

直接运行脚本进入交互式菜单：

```bash
./frpc-manager.sh
```

### 命令行模式

```bash
./frpc-manager.sh start      # 启动 FRPC
./frpc-manager.sh stop       # 停止 FRPC
./frpc-manager.sh restart    # 重启 FRPC
./frpc-manager.sh reload     # 重载配置
./frpc-manager.sh status     # 查看状态
./frpc-manager.sh log        # 查看日志
./frpc-manager.sh install    # 安装 FRPC
./frpc-manager.sh uninstall  # 卸载 FRPC
./frpc-manager.sh help       # 显示帮助
```

## 📋 快速开始

### 1. 安装 FRPC

运行脚本后选择 `1. 安装 FRPC`，脚本会自动：
- 检测系统架构 (amd64/arm64/arm/mips 等)
- 从 GitHub 下载最新版本的 FRPC
- 安装到 `/usr/bin/frpc`
- 创建 OpenWrt 服务脚本

### 2. 配置 FRPS 服务器

选择 `4. 配置 FRPS 服务器连接`，输入：
- FRPS 服务器地址（域名或IP）
- FRPS 服务器端口（默认 7000）
- 认证令牌（Token）

### 3. 添加代理规则

选择 `6. 添加代理规则` 或 `9. 快速部署`，添加您需要的代理：

| 代理类型 | 说明 | 使用场景 |
|---------|------|---------|
| TCP | TCP 端口转发 | SSH、Web服务、数据库等 |
| UDP | UDP 端口转发 | 游戏服务器、VoIP 等 |
| HTTP | HTTP 网站代理 | 网站、API 等 |
| HTTPS | HTTPS 网站代理 | 加密网站 |
| STCP | 安全 TCP | 需要密钥验证的 TCP 服务 |
| XTCP | P2P 穿透 | 点对点直连 |

### 4. 启动服务

选择 `10. 启动 FRPC` 开始运行服务。

## 📁 文件位置

| 文件 | 路径 |
|------|------|
| FRPC 程序 | `/usr/bin/frpc` |
| 配置文件 | `/etc/frpc/frpc.toml` |
| 服务脚本 | `/etc/init.d/frpc` |
| 日志文件 | `/var/log/frpc.log` |

## 🎯 快速部署模板

脚本内置了以下常用场景的快速部署模板：

### 1. 路由器 Web 管理界面
- 通过公网访问路由器管理页面
- 默认本地端口: 80

### 2. 路由器 SSH 访问
- 远程 SSH 登录路由器
- 默认本地端口: 22

### 3. 远程桌面 (RDP)
- 内网 Windows 电脑远程桌面
- 默认本地端口: 3389

### 4. NAS/文件服务器
- 访问内网 NAS 设备 (群晖、威联通等)
- 默认端口: 5000

### 5. 摄像头/监控
- 远程查看内网摄像头

## ⚙️ 配置文件示例

```toml
# FRPC 配置文件

serverAddr = "your-frps-server.com"
serverPort = 7000

[auth]
method = "token"
token = "your-secret-token"

[log]
to = "/var/log/frpc.log"
level = "info"
maxDays = 7

[webServer]
addr = "0.0.0.0"
port = 7400
user = "admin"
password = "admin"

# SSH 代理
[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 2222

# Web 代理
[[proxies]]
name = "web"
type = "tcp"
localIP = "127.0.0.1"
localPort = 80
remotePort = 8080
```

## 🌐 Web 管理界面

脚本默认启用 FRPC 的 Web 管理面板：

- 访问地址: `http://路由器IP:7400`
- 默认用户名: `admin`
- 默认密码: `admin`

> ⚠️ 建议修改默认密码以提高安全性

## 🔒 安全建议

1. **使用强密码**: 设置复杂的 Token 和 Web 管理密码
2. **限制端口**: 只开放必要的端口
3. **定期更新**: 保持 FRPC 版本最新
4. **监控日志**: 定期检查运行日志

## 🐛 常见问题

### Q: 下载 FRPC 失败？
A: 检查网络连接，或手动从 [GitHub Releases](https://github.com/fatedier/frp/releases) 下载。

### Q: 连接 FRPS 服务器失败？
A: 检查以下内容：
- 服务器地址和端口是否正确
- Token 是否与服务器端一致
- 服务器防火墙是否开放对应端口

### Q: 代理无法访问？
A: 检查：
- 本地服务是否正常运行
- 本地端口是否正确
- 远程端口是否被占用

## 📝 更新日志

### v1.0.0
- 初始版本发布
- 支持一键安装/卸载
- 支持多种代理类型
- 内置快速部署模板
- Web 管理面板

## 📄 许可证

本项目采用 MIT 许可证。

## 🙏 致谢

- [fatedier/frp](https://github.com/fatedier/frp) - FRPC/FRPS 项目
- [OpenWrt](https://openwrt.org/) - OpenWrt 项目
- [iStoreOS](https://www.istoreos.com/) - iStoreOS 项目
