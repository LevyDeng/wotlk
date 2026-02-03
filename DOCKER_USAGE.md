# Docker 使用指南

本项目提供了 Docker 支持，可以方便地运行 WoW WOTLK 模拟器。

## 文件说明

- `Dockerfile` - Docker 镜像构建文件
- `docker-compose.yml` - Docker Compose 配置文件
- `docker.sh` - Linux/macOS 启动脚本
- `docker.ps1` - Windows PowerShell 启动脚本
- `.dockerignore` - Docker 构建时忽略的文件

## 前置要求

1. 安装 Docker Desktop（Windows/macOS）或 Docker Engine（Linux）
2. 确保 Docker 服务正在运行

## 使用方法

### Windows (PowerShell)

```powershell
# 启动容器
.\docker.ps1 start

# 停止容器
.\docker.ps1 stop

# 重启容器
.\docker.ps1 restart

# 强制重启（拉取代码、重新构建、重启）
.\docker.ps1 frestart

# 查看状态
.\docker.ps1 status

# 查看日志
.\docker.ps1 logs
```

### Linux/macOS (Bash)

```bash
# 启动容器
./docker.sh start

# 停止容器
./docker.sh stop

# 重启容器
./docker.sh restart

# 强制重启（拉取代码、重新构建、重启）
./docker.sh frestart

# 查看状态
./docker.sh status

# 查看日志
./docker.sh logs
```

**注意**：首次使用前，需要给脚本添加执行权限：
```bash
chmod +x docker.sh
```

## 命令说明

### start
启动容器。如果容器不存在，会自动构建并启动。

### stop
停止运行中的容器。

### restart
重启容器（不重新构建）。

### frestart
强制重启：
1. 停止并删除现有容器
2. 从 Git 拉取最新代码（如果在 Git 仓库中）
3. 重新构建 Docker 镜像（不使用缓存）
4. 启动新容器

### status
显示容器的运行状态。

### logs
实时查看容器日志（按 Ctrl+C 退出）。

## 访问服务

启动成功后，模拟器将在以下地址可用：
- http://localhost:3333

## 开发模式（快速测试）

### 使用开发配置启动

开发模式使用 `docker-compose.dev.yml` 配置，挂载源代码目录，支持快速测试：

```powershell
# Windows
docker-compose -f docker-compose.dev.yml up -d

# Linux/macOS
docker-compose -f docker-compose.dev.yml up -d
```

### 快速测试命令

修改代码后，使用快速测试脚本：

**Windows (PowerShell)**:
```powershell
# 只重新生成装备数据库（最快，~10秒）
.\quick-test.ps1 items
.\quick-test.ps1 restart

# 只重新编译服务器（修改了 Go 代码）
.\quick-test.ps1 server

# 只重新编译 UI（修改了 TypeScript 代码）
.\quick-test.ps1 ui

# 完整重新构建（items + server + UI）
.\quick-test.ps1 full

# 只重启服务器（不重新构建）
.\quick-test.ps1 restart
```

**Linux/macOS (Bash)**:
```bash
chmod +x quick-test.sh

# 同样的命令
./quick-test.sh items
./quick-test.sh restart
./quick-test.sh server
./quick-test.sh ui
./quick-test.sh full
```

### 典型开发工作流

**修改装备属性**：
```powershell
# 1. 编辑 tools/database/overrides.go
# 2. 重新生成数据库
.\quick-test.ps1 items

# 3. 重启服务器加载新数据库
.\quick-test.ps1 restart
```

**修改模拟器逻辑（Go 代码）**：
```powershell
# 1. 编辑 sim/{class}/*.go
# 2. 重新编译服务器
.\quick-test.ps1 server
```

**修改 UI（TypeScript 代码）**：
```powershell
# 1. 编辑 ui/**/*.ts
# 2. 重新编译 UI
.\quick-test.ps1 ui
```

### 为什么快？

1. **分层缓存**：
   - Go/npm 依赖只在首次构建时安装
   - 只重新编译变更的代码

2. **Volume 挂载**：
   - 源代码通过 volume 挂载，无需复制到容器
   - 修改立即同步到容器内

3. **增量编译**：
   - `make` 只重新编译变更的文件
   - Go 和 TypeScript 都支持增量编译

4. **本地生成数据库**：
   - 数据库生成在本地运行（不在 Docker 内）
   - 生成后通过 volume 自动同步到容器

### 性能对比

| 操作 | 生产模式 | 开发模式 |
|------|----------|----------|
| 首次构建 | ~10分钟 | ~10分钟 |
| 修改装备重新生成 | ~5分钟 | ~10秒 |
| 修改 Go 代码重新编译 | ~5分钟 | ~30秒 |
| 修改 UI 代码重新编译 | ~5分钟 | ~1分钟 |

## 故障排除

### 端口被占用

如果 3333 端口被占用，可以修改 `docker-compose.yml` 中的端口映射：

```yaml
ports:
  - "8080:3333"  # 改为使用 8080 端口
```

### 构建失败

如果构建失败，可以查看详细日志：
```bash
docker-compose build --no-cache
```

### 查看程序日志（容器输出）

容器内程序（npm、make、wowsimwotlk）的 stdout/stderr 都会进容器日志，用下面任一方式查看：

**PowerShell：**
```powershell
# 实时查看（持续输出）
.\docker.ps1 logs

# 或直接用 docker
docker logs -f wowsims-wotlk

# 只看最后 200 行
docker logs --tail 200 wowsims-wotlk
```

**Bash：**
```bash
./docker.sh logs
# 或
docker logs -f wowsims-wotlk
```

**Docker Compose：**
```bash
docker compose logs -f wowsims-wotlk
```

### 404：访问 /wotlk/xxx 仍 404 时排查

**原因说明**：`docker.ps1` 使用 `docker-compose.yml`，启动时会执行 `npm install && make binary_dist && make devserver`，会先构建前端到 `dist/wotlk` 再启动服务；`docker-compose.dev.yml` 也必须包含 `make binary_dist`（以及前面的 `npm install`），否则 `--usefs=true` 时服务从 `./dist` 读文件，`dist` 未构建就会 404。两者启动命令需一致。

1. **进容器看 dist 是否存在：**
   ```powershell
   docker exec -it wowsims-wotlk sh
   # 在容器内执行：
   pwd
   ls -la dist
   ls -la dist/wotlk
   ls dist/wotlk
   exit
   ```
   若没有 `dist/wotlk` 或下面没有 `mage`、`raid` 等目录，说明前端没在容器里正确构建。

2. **在容器内测服务：**
   ```powershell
   docker exec -it wowsims-wotlk sh -c "wget -q -O - http://127.0.0.1:3333/wotlk/mage/ 2>&1 | head -5"
   ```
   若返回 HTML 则服务正常，问题在浏览器或端口映射；若 404 则服务端没找到文件。

3. **确认启动命令在项目根执行：**
   服务器用 `./dist` 做静态目录，工作目录必须是项目根（即存在 `dist` 的目录）。当前 `docker-compose` 的 `command` 已在 `/wotlk` 下执行，一般无需改。

### 容器无法启动

查看容器日志：
```bash
docker logs wowsims-wotlk
```

或使用脚本：
```bash
./docker.sh logs
```

### 清理所有数据

如果需要完全清理（包括镜像和卷）：
```bash
docker-compose down -v --rmi all
```

## 手动操作

如果不使用脚本，也可以直接使用 Docker Compose 命令：

```bash
# 构建并启动
docker-compose up -d --build

# 停止
docker-compose stop

# 重启
docker-compose restart

# 查看日志
docker-compose logs -f

# 停止并删除容器
docker-compose down
```

## 注意事项

1. **首次构建**：第一次构建可能需要较长时间，因为需要下载依赖和编译代码
2. **代码更新**：使用 `frestart` 命令可以确保使用最新代码
3. **数据持久化**：容器内的数据在删除容器后会丢失，如果需要持久化，可以配置 Docker 卷
4. **资源占用**：确保系统有足够的内存和 CPU 资源
