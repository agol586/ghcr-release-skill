# GHCR Release Skill

供 Codex 跨项目使用的 GitHub Actions 镜像发布技能：每个 CMD 使用独立 workflow，通过对应 release tag 发布到 GHCR。

## 安装与使用

首次安装到用户级技能目录：

```sh
git clone git@github.com:agol586/ghcr-release-skill.git ~/.agents/skills/ghcr-release
```

已安装时保留本地修改，再更新仓库。安装后在任意项目中调用：

```text
$ghcr-release 为当前项目配置每个 CMD 独立的 GHCR 发布 workflow
```

如果技能列表未刷新，重启 Codex。

## 发布约定

| 项目结构 | Workflow | 唯一 Tag 规则 | 构建目标 |
|---|---|---|---|
| 单 CMD | `release.yml` | `release/v*` | 该 CMD，例如 `cmd/server` |
| 多 CMD | `release-cmd11.yml` | `release/cmd11-v*` | `cmd/cmd11` |
| 多 CMD | `release-cmd22.yml` | `release/cmd22-v*` | `cmd/cmd22` |

不配置裸 `v*`，不设置默认应用。多 CMD 项目中，每份 workflow 只接受自己的 CMD 前缀，不接受 `release/v*`。

镜像格式为 `ghcr.io/<owner>/<IMAGE_REPO>-<CMD>:<version>`，`IMAGE_REPO` 默认取当前仓库名，也可通过 GitHub Actions 仓库变量自定义。支持日期版本及同日后缀，例如单 CMD 的 `release/v26.11.07b`、多 CMD 的 `release/cmd11-v26.11.07c`；镜像版本完整保留前导零和后缀。仅发布明确的版本和提交 SHA 标签，不自动创建或更新 `latest`。

模板包含 Go 多阶段构建、配置和数据挂载、`.env` 注入、文本日志重定向到挂载目录、宿主机 logrotate 示例，以及可选的 DNS 和 host 网络配置。接入时按项目实际入口、配置和日志实现适配。

- [技能指令](SKILL.md)
- [模板与部署说明](references/usage.md)
- [Workflow 模板](assets/release.yml)

模板位于 `assets/`，安装技能本身不会触发镜像发布。
