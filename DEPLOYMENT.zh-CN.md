# Recitation 6 部署说明

[最新课程要求](https://cmu-17313q.github.io/recitations/reci6-deployment/)：在课程 VM 上用 Docker Compose 运行 OpenCode，通过 `http://crs-17313-demo.qatar.cmu.edu:<YOUR_PORT>` 访问，再将 URL 提交 Gradescope。

## 当前进度（2026-10-19）

- 本地 Linux ARM64 镜像已构建，版本为 `1.18.31-reci`；健康接口、网页资源、浏览器主页、终端 PTY 和文件搜索已验证
- `Dockerfile` 构建本仓库的程序及网页 UI；`bun.lock` 已补齐源码原本声明的 `openai@6.39.1`，仍使用 `--frozen-lockfile`
- 用户已手动登录 VM；`chenyuq` 属于 `docker` 组，VM 为 Linux x86_64，Docker 为 `29.1.3`、Compose 为 `2.40.3`
- 已在 VM 上完成 Linux x86_64 原生构建，启动 `chenyuq-reci6-opencode-chenyuq-1`，映射 `0.0.0.0:4096`，容器为 `healthy`
- VM 内健康检查、经 SSH 通道的网页资源、浏览器主页、终端 PTY 和文件搜索已验证
- VM 的 Docker 开机启动为 `enabled`，容器策略为 `unless-stopped`；未重启共享 VM 或 Docker
- VPN 客户端直接访问课程主机的 4096 仍超时，浏览器直连也未通过；尚未提交 Gradescope
- `4096` 仅用于本次已获授权的示例测试，尚未确认它是分配给自己的正式端口

本次已分别验证本地 Linux ARM64 和 VM Linux x86_64 构建；后续应按运行机器的实际架构重建。构建需要联网下载依赖与 models.dev 元数据。网页部署和模型服务配置分别验证。

## 当前访问阻碍

应用在 VM 内正常运行，SSH 登录正常；客户端 DNS 与目标 VPN 路由检查没有发现异常。
课程 URL 的 TCP 4096 直接访问仍未通过，具体访问限制需要课程管理员确认，或改用确认可访问的正式分配端口。

测试时可以通过自己的 SSH 连接访问 VM 上的同一服务：

```bash
ssh -N -L 127.0.0.1:14096:127.0.0.1:4096 chenyuq@crs-17313-demo.qatar.cmu.edu
```

保持该连接，在本机打开 <http://127.0.0.1:14096/>。这个地址仅用于 SSH 通道测试，不能提交为课程部署 URL。

## 1. 登录课程 VM

在自己的电脑连接 CMU 网络或 VPN，然后运行并手动完成认证：

```bash
ssh chenyuq@crs-17313-demo.qatar.cmu.edu
```

下面第 2 至第 4 步在 VM 内执行。

## 2. 检查 Docker 权限与测试端口

```bash
docker compose version
docker info --format '{{.ServerVersion}}'
ss -ltn 'sport = :4096'
docker ps --filter publish=4096 --format 'table {{.ID}}\t{{.Names}}\t{{.Ports}}'
```

只有 Docker 可用且 4096 没有被其他服务占用时，才继续部署。若发现已有容器，先核对归属与 Compose 项目标签；不要停止其他人的服务。

如果 Docker 报 `permission denied`，记录报错、`id` 和 `ls -l /var/run/docker.sock` 的输出。可用 `sudo -n docker info` 检查是否已有免密权限；若仍不可用，向课程管理员报告“SSH 已登录，但 Docker 权限阻止部署”，暂不执行启动命令，不自行修改用户组或 socket 权限。

## 3. 获取仓库并启动自己的服务

分支为 `codex/recitation-deployment`，基于课程仓库的 `dev`。如果 `~/OpenCode-F26-Reci-7` 已存在，先检查其中的分支和未提交修改；不要覆盖已有目录。以下克隆命令用于目录尚不存在的情况：

```bash
git clone --depth 1 --single-branch --branch codex/recitation-deployment https://github.com/adrianchenyuqiu/OpenCode-F26-Reci-7.git ~/OpenCode-F26-Reci-7
```

确认仓库正确后，进入目录并明确启用 VM 的直接访问。固定使用项目名 `chenyuq-reci6`，仅管理服务 `opencode-chenyuq`：

```bash
cd ~/OpenCode-F26-Reci-7
export OPENCODE_BIND_ADDRESS=0.0.0.0 OPENCODE_PORT=4096
docker compose -p chenyuq-reci6 config --quiet
docker compose -p chenyuq-reci6 up --build -d opencode-chenyuq
docker compose -p chenyuq-reci6 ps opencode-chenyuq
docker compose -p chenyuq-reci6 logs --tail=80 opencode-chenyuq
```

Compose 默认绑定 `127.0.0.1:4096`，适合本地验证；VM 上面的环境变量将其改为 `0.0.0.0:4096`，供校网直接访问。每次重新登录 VM 后，运行 Compose 前都应重新设置这两个变量。正式端口确定后，更新 `OPENCODE_PORT` 和下方 URL，并重新检查端口与访问结果。

首次构建可能需要数分钟。容器起初可能显示 `starting`；等待其显示 `healthy` 后再检查接口：

```bash
curl --fail --show-error --max-time 10 http://127.0.0.1:4096/global/health
```

应返回包含 `"healthy":true` 的 JSON。

## 4. 核对重启策略

```bash
docker inspect "$(docker compose -p chenyuq-reci6 ps -q opencode-chenyuq)" --format '{{.HostConfig.RestartPolicy.Name}}'
systemctl is-enabled docker
```

容器策略应为 `unless-stopped`。Docker 的开机启动状态单独记录；若未启用，由课程管理员确认共享 VM 的设置。本次不重启 VM 或 Docker。配置检查通过也不等于已经验证实际重启恢复。

若曾手动停止自己的容器，需要重新运行本项目的 `up -d`；`unless-stopped` 会保留手动停止的状态。

## 5. 从自己的电脑访问并提交 URL

保持 CMU 网络或 VPN 连接，在自己的电脑执行：

```bash
curl --fail --show-error --max-time 10 http://crs-17313-demo.qatar.cmu.edu:4096/global/health
```

再用浏览器打开 [本次示例测试地址](http://crs-17313-demo.qatar.cmu.edu:4096/)，确认实际显示 OpenCode 网页。VM 内健康检查成功和另一台电脑成功访问需要分别验证。

在 Gradescope 的对应作业（ID `8896144`）提交已验证的部署 URL：

```text
http://crs-17313-demo.qatar.cmu.edu:4096/
```

提交前确认课程接受当前测试端口；若收到自己的正式端口，先更新部署与 URL。提交后重新打开作业，核对提交内容和回执。

当前课程直接将主机端口映射到容器的 4096，无需安装或配置 Nginx。仓库中的 `deploy/nginx-opencode.conf.template` 仅保留为旧方案参考。
