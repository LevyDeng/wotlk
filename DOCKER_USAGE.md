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

## 开发模式

如果你需要在开发模式下运行（代码变更自动生效），可以修改 `docker-compose.yml`：

```yaml
volumes:
  - .:/wotlk  # 挂载源代码目录
environment:
  - WATCH=1   # 启用文件监听
```

然后使用 `frestart` 命令重新启动。

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
