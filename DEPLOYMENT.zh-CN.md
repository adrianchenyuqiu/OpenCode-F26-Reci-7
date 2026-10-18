# Recitation 6 部署说明

课程要求：<https://cmu-17313q.github.io/recitations/reci6-deployment/>

此分支为 `codex/recitation-deployment`，基于课程仓库的 `dev` 分支。
Andrew ID 使用 `chenyuq`。尚未拿到课程 VM hostname，下面的 VM 命令需等地址确认后执行。

## 文件用途

- `Dockerfile`：安装 Bun 1.3.14 和构建依赖，构建本仓库的 OpenCode 与网页 UI，再把编译产物放入运行镜像
- `docker-compose.yml`：后台运行服务，只把 4096 端口绑定到 VM 的 `127.0.0.1`，并设置 `restart: unless-stopped`
- `deploy/nginx-opencode.conf.template`：Nginx 监听 80 端口，转发 HTTP、WebSocket 和流式响应到 OpenCode

Docker 构建需要联网下载依赖与 models.dev 元数据。模型对话需要另行配置可用的模型服务；网页部署验证不代表模型对话已经配置完成。

## 本地验证（2026-10-19）

- Linux ARM64 镜像构建成功，最终运行镜像中的程序版本为 `1.18.31-reci`
- 容器健康检查、首页及本地 JavaScript/CSS 资源请求通过，浏览器实际显示 OpenCode 主页
- 终端 PTY 启动、正常退出、删除，以及文件搜索检查通过
- Nginx 模板语法检查与隔离容器中的代理请求通过
- 容器的 `unless-stopped` 策略已核对；VM 开机启动和实际重启恢复尚未验证

课程源码的 `package.json` 已声明 `openai@6.39.1`，但原 `bun.lock` 漏记了这一项。
此分支仅补齐对应锁文件记录，没有升级其他依赖，Docker 构建仍使用 `--frozen-lockfile`。

## 1. 在自己的电脑连接 VM

把 `<VM-HOSTNAME>` 替换成老师实际提供的地址：

```bash
ssh chenyuq@<VM-HOSTNAME>
```

后续 `systemctl` 和 `/etc/nginx` 命令在 Linux VM 上运行。

## 2. 在 VM 获取部署分支

```bash
gh auth login
cd ~
git clone --single-branch --branch codex/recitation-deployment https://github.com/adrianchenyuqiu/OpenCode-F26-Reci-7.git
cd OpenCode-F26-Reci-7
```

如果该目录已经存在，先检查其中的分支与未提交修改，不要覆盖现有工作。

## 3. 构建并启动 OpenCode

VM 需要已安装 Docker Engine、Docker Compose 插件和 Nginx。

```bash
docker compose config --quiet
docker compose up --build -d
docker compose ps
docker compose logs --tail=80
curl --fail http://127.0.0.1:4096/global/health
```

健康接口应返回 `healthy: true`，容器应显示 `healthy`。首次构建会安装整个仓库的依赖并编译网页，可能需要数分钟。
镜像会按构建机器的 Linux 架构编译；VM 上应重新构建镜像。

## 4. 配置 Nginx

把下面引号里的地址改为老师实际提供的 hostname，再执行。
如果已有同名配置，下面的命令会停留在检查提示；先查看现有文件，再决定如何更新。

```bash
VM_HOSTNAME='<VM-HOSTNAME>'
if sudo test -e /etc/nginx/sites-available/opencode || sudo test -L /etc/nginx/sites-available/opencode || sudo test -e /etc/nginx/sites-enabled/opencode || sudo test -L /etc/nginx/sites-enabled/opencode; then
  echo '已有 OpenCode Nginx 配置，请先查看文件再更新'
else
  sed "s/<VM-HOSTNAME>/${VM_HOSTNAME}/g" deploy/nginx-opencode.conf.template | sudo tee /etc/nginx/sites-available/opencode > /dev/null &&
  sudo ln -s /etc/nginx/sites-available/opencode /etc/nginx/sites-enabled/opencode &&
  sudo nginx -t &&
  sudo systemctl reload nginx
fi
curl --fail -H "Host: ${VM_HOSTNAME}" http://127.0.0.1/global/health
```

命令只有在 `nginx -t` 成功后才执行 reload。

在自己的电脑上，按课程网络要求连接 CMU 网络，再打开：

```text
http://<VM-HOSTNAME>/
```

确认看到 OpenCode 网页。此模板使用课程要求的 HTTP 配置。

## 5. 配置开机自启

```bash
sudo systemctl enable docker
systemctl is-enabled docker nginx
systemctl is-active docker nginx
docker inspect "$(docker compose ps -q opencode-chenyuq)" --format '{{.HostConfig.RestartPolicy.Name}}'
```

Docker 与 Nginx 的 enablement 应为 `enabled`，服务状态应为 `active`，容器策略应为 `unless-stopped`。
如果 Nginx 还未设为开机启动，再运行 `sudo systemctl enable nginx`。

`unless-stopped` 会保留手动停止的状态；若此前执行过 `docker compose stop`，需要重新运行 `docker compose up -d`。
上述检查验证的是配置，实际 VM 重启后的恢复情况仍需要单独验证。课程页面没有要求主动重启 VM。

## 完成标准

- Docker 镜像构建成功，容器健康检查通过
- 本机访问 4096 的健康接口和网页成功
- Nginx 配置检查通过，代理请求成功
- 在 CMU 网络的另一台电脑上打开 VM 网页成功
- Docker 与 Nginx 开机启动配置、容器重启策略已验证

课程页面没有列出截图、PR 或 Gradescope 上传要求；如 Gradescope 有对应作业，以其具体说明为准。
