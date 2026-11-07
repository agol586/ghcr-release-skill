# GHCR 发布模板

每个 CMD 使用一份独立 workflow。将 `release.yml` 分别复制为目标项目的 `.github/workflows/release-app1.yml`、`release-app2.yml` 等，并修改各文件的 `name`、`on.push.tags` 和 `env.APP_CMD`。模板中的 app1 是默认应用；复制给其他 CMD 时，删除 `v*` 和 `release/v*`，仅保留对应的 `release/<CMD>-v*`。每次触发只构建该 workflow 指定的应用，共用根目录的 Dockerfile 和构建上下文，可访问共享的 `go.mod`、`internal/` 等文件。镜像统一命名为 `ghcr.io/<owner>/<IMAGE_REPO>-<CMD名>`。

`owner` 自动取当前仓库所属用户或组织；`IMAGE_REPO` 默认取当前仓库名，也可通过 GitHub Actions 仓库变量 `IMAGE_REPO` 自定义（Settings → Secrets and variables → Actions → Variables）。例如仓库 `acme/orders` 默认发布 `ghcr.io/acme/orders-app1`；设置 `IMAGE_REPO=my-platform` 后发布 `ghcr.io/acme/my-platform-app1`。名称统一转小写，变量只填镜像前缀，不含 owner、斜杠或版本。下表的 `owner/repo` 为占位示例。

| Workflow 文件 | Tag 规则 | 固定构建目标 | 发布镜像示例 |
|---|---|---|---|
| `release-app1.yml`（默认应用） | `release/app1-v*`、`v*`、`release/v*` | `APP_CMD: app1` | `ghcr.io/owner/repo-app1:v1.2.3` |
| `release-app2.yml` | `release/app2-v*` | `APP_CMD: app2` | `ghcr.io/owner/repo-app2:v1.2.3` |
| `release-app3.yml` | `release/app3-v*` | `APP_CMD: app3` | `ghcr.io/owner/repo-app3:v1.2.3` |

例如推送 `release/app1-v1.2.3` 只触发 `release-app1.yml`，只构建 `cmd/app1`。无需 matrix、目录扫描或 Python；Bash 仅提取版本并生成镜像名。

裸 tag `v26.11.07` 和 `release/v26.11.07` 只触发默认应用的 workflow，镜像版本均为 `v26.11.07`。如默认应用是 server，就仅在 `release-server.yml` 中保留 `v*`、`release/v*` 并设置 `APP_CMD: server`；其他 workflow 只配置各自带 CMD 名的 tag。

应用名支持小写字母、数字和连字符；版本支持 `v1.2.3-rc.1` 和日期式 `v26.11.07`；同一天后续版本使用 `v26.11.07b`、`v26.11.07c` 等单个小写字母后缀，保留前导零及后缀，不做 SemVer 归一化；不支持含 `+` 的版本。仅发布完整版本标签及提交 SHA 标签，摘要写入 Actions Summary；禁止自动创建、更新或晋升 `latest`。如改用 docker/metadata-action，必须设置 `flavor: latest=false`。发布标签应只指向通过项目 CI 的提交，避免移动或重复使用版本标签。

## 项目接入

- Workflow 使用 `GITHUB_TOKEN` 发布，无需额外 PAT；已有 GHCR 包需要授予该仓库 Actions 写入权限。首次发布后按需设置包可见性。[GitHub 发布说明](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images)
- 默认构建 `linux/amd64`；需要 ARM 时添加 QEMU setup action，并将 platforms 改为 `linux/amd64,linux/arm64`，构建阶段也需支持目标架构。
- Go 项目可将 `Dockerfile.go.example` 复制为根目录 `Dockerfile`，同时复制 `docker-entrypoint.sh` 到根目录。固定适合项目的 `GO_VERSION`，合并 `.dockerignore` 规则，再补充资源文件和健康检查。示例要求 `go.mod`、`go.sum`，以 `CGO_ENABLED=0` 构建；运行用户统一为 `10001:10001`。
- 已有 Dockerfile 必须在构建阶段声明 `ARG APP_CMD` 并实际用于选择入口，例如 `go build -o /out/app "./cmd/$APP_CMD"`；仅传入参数不会自动改变构建目标。
- 应用需实际读取配置路径、日志路径、数据路径对应的环境变量，并在 bridge 模式监听 `0.0.0.0`。模板不会自动改变应用的配置行为。

## 部署

把 `compose.yml`、`.env.example` 复制到服务器上独立的应用目录，然后执行：

```sh
cp .env.example .env
mkdir -p config logs data
sudo chown -R 10001:10001 logs data
sudo chmod 750 logs
chmod 600 .env
# 编辑 .env 中的 IMAGE、VERSION 和业务变量；将配置放到 config/config.yml，确保 UID 10001 可读。
docker compose up -d --pull always
sudo tail -n 100 -F logs/app.log
```

私有镜像需先 `docker login ghcr.io`，使用具有 `read:packages` 权限的凭据。回滚时改回 `.env` 中旧的 `VERSION`，再运行启动命令；数据迁移的回滚由应用处理。

`env_file: .env` 将变量注入进程；Compose 的默认 `.env` 插值本身不会注入全部变量。[Docker 环境变量说明](https://docs.docker.com/compose/how-tos/environment-variables/set-environment-variables/)
如应用必须读取实体 `.env` 文件，再增加 `./.env:/app/.env:ro` 挂载并保证运行用户可读。真实 `.env`、配置、日志和数据应加入项目 `.gitignore`，不要打进镜像。

配置只读挂载；日志和数据可写并持久化。

## 文本日志与宿主机轮转

将应用日志配置为文本格式输出到 stdout/stderr，关闭应用自身的文件轮转。`.env.example` 中的 `LOG_FORMAT=text` 是约定示例，接入时需匹配应用实际配置；重定向本身不会把 JSON 转成文本。

`docker-entrypoint.sh` 通过 `exec` 启动应用，将 stdout/stderr 合并追加到 `/app/logs/app.log`，对应宿主机 `./logs/app.log`；新文件权限为 `0640`。每个应用使用独立部署目录。`LOG_DIR` 如需修改，应同时调整挂载目标。

Compose 使用 `logging.driver: none`，日志直接在宿主机查看，`docker compose logs` 不再输出应用日志。已有镜像需先接入入口脚本及文本日志配置，再使用此 Compose 配置。[Docker 日志说明](https://docs.docker.com/engine/logging/configure/)

宿主机安装 logrotate，将 `logrotate.conf.example` 中路径改为日志文件的实际绝对路径，再安装配置：

```sh
sudo install -m 644 logrotate.conf.example /etc/logrotate.d/app1
sudo logrotate --debug /etc/logrotate.d/app1
```

确认宿主机的 logrotate timer 或 cron 已启用。默认每天轮转，保留 14 份并压缩。配置使用 `copytruncate` 保持应用已打开的文件描述符有效，无需重启；复制与截断之间可能丢失少量并发日志。若要求无损轮转，需要应用支持重新打开日志文件，再使用 rename 和 reopen 方案。[logrotate 说明](https://github.com/logrotate/logrotate/blob/main/logrotate.8.in)

## 主机网络和 DNS

默认 bridge 模式可出站连接 RDS、HTTP API 等；私有服务需要宿主机具备 VPC/VPN 路由、可用的内网 DNS，并放行相应安全组和防火墙端口。使用 RDS 域名连接，不固定其 IP。

访问宿主机服务可使用 `host.docker.internal:端口`，服务需监听 Docker 网关可达的地址；Linux 上仅监听 `127.0.0.1` 的服务需要 host 模式。Compose 服务之间使用服务名和容器端口访问。

如内网域名解析失败，取消 `compose.yml` 中 `dns` 的注释，在 `.env` 设置容器可达的 `DNS_SERVER`。bridge 模式下 `127.0.0.1` / `127.0.0.53` 指向容器自身，不能指向宿主机 DNS；挂载宿主机 `/etc/resolv.conf` 也不能解决该地址问题。[Compose 网络配置](https://docs.docker.com/reference/compose-file/services/)

确需共享 Linux 主机网络时，复制 `compose.host.yml` 并运行：

```sh
docker compose -f compose.yml -f compose.host.yml up -d --pull always
```

覆盖文件会移除端口映射，应用直接占用主机端口；`BIND_IP`、`HOST_PORT` 不再生效，监听地址由应用配置决定。若需主机 loopback DNS，可取消覆盖文件中 `dns` 的注释并填写实际解析器地址。host 模式不自动共享主机 `/etc/hosts`，也不会自动获得 VPC 权限。Docker Desktop 需 4.34+ 并开启 host networking；Compose 需支持 `!reset`。[Host 网络说明](https://docs.docker.com/engine/network/drivers/host/) · [覆盖文件合并规则](https://docs.docker.com/reference/compose-file/merge/)
