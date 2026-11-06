---
name: ghcr-release
description: Set up or adapt tag-triggered GitHub Actions publishing to GHCR, with one independent workflow per CMD, configurable repository prefixes, Dockerfiles and Compose runtime mounts/networking. Use for GHCR release workflows, not for general CI repair or unrelated deployment platforms.
---

# GHCR Release

Configure one concise, independent workflow per application CMD using the bundled template. Give each workflow its own tag filter and fixed APP_CMD. Avoid matrix jobs, automatic CMD discovery, and inline Python for this release convention. Preserve the user's requested naming, directory layout and release behavior when they differ from the defaults below.

## Inspect and adapt

Read the project's agent instructions, existing workflows, Dockerfiles, Compose files, package/build definitions and application entrypoints. Determine which CMD directories are executable apps, what shared sources and generated assets they need, and how each app loads configuration. Reuse existing build/test steps and runtime behavior; merge existing files rather than replacing them wholesale.

For `cmd/app1`, `cmd/app2` and similar layouts, copy [assets/release.yml](assets/release.yml) to `.github/workflows/release-app1.yml`, `release-app2.yml`, etc. In each file, set its display name, literal `on.push.tags` filter and fixed `env.APP_CMD` consistently:

- `release/app1-v1.2.3` triggers only `release-app1.yml`, which publishes only `cmd/app1`; other applications use their own prefixes and workflows.
- If requested, assign `release/v*` to exactly one explicit default application workflow, such as `APP_CMD: server`. Never use it as an implicit publish-all trigger or repeat it across application workflows.
- Images use `ghcr.io/<owner>/<IMAGE_REPO>-<CMD>:<version>`. Derive owner and repository name from GitHub context; optional Actions variable `IMAGE_REPO` overrides only the repository prefix. Normalize image names to lowercase and validate the override; never hardcode the originating project.
- Build with repository-root context and `APP_CMD=<CMD>` so shared modules and source directories remain accessible. The Dockerfile must actually consume this argument.
- Publish the version and full commit SHA tags, and record the digest. Use `GITHUB_TOKEN` with `packages: write` only on publishing jobs, per-app caches and bounded build time. Do not add automatic `latest` promotion unless requested.

Choose the actual executable CMDs from project evidence while implementing the workflows. Each generated workflow builds only its fixed application; do not add runtime scanning or publish-all behavior. For a different layout or a single app without `cmd/`, adapt the Dockerfile and fixed target to its existing entrypoint without restructuring the project. Document the workflow-to-tag-to-command mapping.

Use [assets/Dockerfile.go.example](assets/Dockerfile.go.example) only for compatible Go projects. Select the Go version from project evidence, account for CGO and runtime libraries, and preserve frontend builds, embedded assets, templates and certificates. Other languages should retain their native build/runtime stages while supporting the selected app mapping. Handle modules without `go.sum` according to their actual dependency setup.

Wire the release to existing required quality gates when the project has them. Tag pushes do not inherently prove that branch CI passed.

## Runtime assets

Adapt [assets/compose.yml](assets/compose.yml), [assets/.env.example](assets/.env.example) and [assets/.dockerignore](assets/.dockerignore). Merge ignore rules without excluding files genuinely needed to build. Preserve existing deployment paths and application config keys.

- Provide read-only config and writable log/data mounts. Align the runtime UID/GID, bind-mount ownership and file permissions; the starter uses `10001:10001`.
- Inject runtime variables with `env_file`; ordinary Compose `.env` interpolation alone is insufficient. If the application explicitly reads a file, add a read-only `.env` mount with compatible permissions. Do not bake environment secrets into the image or replace a real `.env` with examples.
- Verify that config/log/data environment names are consumed by the app. If not, use its existing flags/config settings rather than claiming the template enables unsupported behavior.
- Configure the application logger to emit plain text to stdout/stderr and disable application-managed file rotation. `LOG_FORMAT=text` is only an example; verify or adapt the app's actual logging configuration. Shell redirection does not convert JSON to text.
- Copy/adapt [assets/docker-entrypoint.sh](assets/docker-entrypoint.sh) and wire it into the Dockerfile. It uses `exec "$@" >> "$LOG_DIR/app.log" 2>&1` to preserve argument boundaries and termination signals while appending both streams to the mounted log directory. Preserve any required existing entrypoint initialization. Keep runtime UID/GID and permissions aligned; new log files use `0640`.
- Delegate rotation to the host using [assets/logrotate.conf.example](assets/logrotate.conf.example), with an absolute host log path per app and an enabled logrotate timer/cron. `copytruncate` works with the continuously open redirected file; document its small concurrent-write loss window. Use rename/reopen only when the application actually supports reopening its log file descriptors.
- Use Compose `logging.driver: none` after file redirection is wired; view logs with host `tail -F`, not `docker compose logs`. Keep graceful shutdown and non-root execution. Add a health check only when a real endpoint/command exists, and include its runtime dependencies.
- Retain bridge networking by default. RDS/private APIs require reachable routes, DNS and service-side access rules. Use `host.docker.internal:host-gateway` for host services listening on a reachable interface; use a reachable DNS IP for custom DNS, not host loopback in bridge mode.
- When host networking is requested or required, adapt [assets/compose.host.yml](assets/compose.host.yml), which removes port mappings. Linux host mode permits host loopback access; it does not supply VPC permissions or share the host's hosts file. Host networking on Docker Desktop requires compatible support and enabling the feature. Do not enable host mode globally just because a database is remote.

Read [references/usage.md](references/usage.md) when writing project-specific release/deployment instructions or configuring networking. Copy only the needed templates into the project; the reference is guidance, not a file to install unchanged.

## Verify and deliver

Validate workflow YAML, non-overlapping application tag filters, the fixed APP_CMD passed to each Dockerfile, malformed versions, and default/custom image prefixes. Check that an app1 tag cannot trigger the app2 workflow, and that any release/v* rule belongs only to the chosen default application. Use actionlint when available. Validate the Compose configurations with placeholder environment values; check that host overrides remove ports. Build representative selected apps/images when available tooling and the task scope permit, including necessary project checks. For logging changes, verify both output streams reach the mounted file, restarts append, arguments and exit statuses are preserved, and SIGTERM still reaches the application. Validate host logrotate configuration when the tool is available. Never print actual secrets in validation output.

Report files changed, tag-to-image examples, custom variable setup and any unverified build/publish/network behavior. Implementing a workflow is not itself a request to push a release tag, publish packages, change remote settings or deploy; perform those only within the user's authorized scope. Do not introduce an extra approval step for already-authorized local implementation.
