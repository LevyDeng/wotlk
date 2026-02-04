# Quick Test Guide - Fast Development Workflow

This guide explains how to quickly test code changes without full Docker rebuilds.

## Overview

The project provides two Docker configurations:

1. **Production** (`docker-compose.yml`) - Full build, optimized for deployment
2. **Development** (`docker-compose.dev.yml`) - Fast iteration with volume mounting

## Setup for Development

### 1. Start Development Container

```powershell
# Windows (recommended: use quick-test script)
.\quick-test.ps1 start

# Or with docker-compose directly
docker-compose -f docker-compose.dev.yml up -d
```

```bash
# Linux/macOS
./quick-test.sh start
```

This will:
- Build the container with cached dependencies
- Mount your source code as volumes
- Start the server at http://localhost:3333

**Fast startup**: The built frontend (`dist/wotlk`) is stored in a named volume `dist_dev`. The container only runs `npm install && make binary_dist` when `dist/wotlk` is missing or empty. So the **first** start (or after removing the volume) is slow; **later** starts skip the frontend build and are fast. After you change UI code, run `.\quick-test.ps1 ui` to rebuild the frontend, or remove the volume to force a full rebuild on next start.

**Item DB (import/gear picker)**: The **browser** loads the DB from `/wotlk/assets/database/db.json`, which is served from the container’s **dist** (volume `dist_dev`). The **server** uses an embedded `db.bin` at sim run time. After changing items (e.g. overrides) and running `.\quick-test.ps1 items` you must:

1. **`.\quick-test.ps1 ui`** — rebuilds dist inside the container and copies the new `assets/database/db.json` into dist, so the “not found in sim database” check and gear picker see the new items.
2. **`.\quick-test.ps1 server`** (or **`.\quick-test.ps1 restart`**) — rebuilds the server with embedded DB so the sim can resolve item IDs when running.

Then hard-refresh the page (Ctrl+F5). On startup the server logs `Database loaded: N items, ...` to confirm the embedded DB is loaded.

### 2. Verify Container is Running

```powershell
docker ps | Select-String "wowsims-wotlk-dev"
```

## Quick Test Commands

Use the `quick-test` scripts for fast iteration:

### Windows (PowerShell)

```powershell
# Start Docker dev container (do this first if container is not running)
.\quick-test.ps1 start

# Regenerate items database (after modifying overrides.go)
.\quick-test.ps1 items
.\quick-test.ps1 restart

# Rebuild server (after modifying Go code)
.\quick-test.ps1 server

# Rebuild UI (after modifying TypeScript code)
.\quick-test.ps1 ui

# Full rebuild
.\quick-test.ps1 full

# Just restart
.\quick-test.ps1 restart
```

### Linux/macOS (Bash)

```bash
chmod +x quick-test.sh

./quick-test.sh start    # start Docker dev container
./quick-test.sh items
./quick-test.sh restart
./quick-test.sh server
./quick-test.sh ui
./quick-test.sh full
```

## Common Workflows

### Workflow 1: Modify Item Stats / Add Custom Items

**Goal**: Change item stats or add custom items (e.g. 北境战盔), so import and gear picker recognize them.

```powershell
# 1. Edit tools/database/overrides.go (and ItemAllowList for new items)

# 2. Regenerate DB (writes assets/database/db.bin and db.json)
.\quick-test.ps1 items

# 3. Refresh the DB the browser uses (copy new db.json into dist)
.\quick-test.ps1 ui

# 4. Rebuild server so it embeds the new DB, then restart
.\quick-test.ps1 server
# Or: .\quick-test.ps1 restart

# 5. Hard-refresh the page (Ctrl+F5), then import again
```

**Why both ui and server?** The browser loads DB from `/wotlk/assets/database/db.json` (served from dist). The server uses an embedded `db.bin` when running sims. So after `items` you need `ui` (so dist gets the new db.json) and `server` (so the binary embeds the new db).

**Total time**: ~1–2 min (ui build can be slow)

### Workflow 2: Modify Spell Damage

**Goal**: Increase Death Strike base damage

```powershell
# 1. Edit sim/deathknight/death_strike.go
# Change: baseDamage := 297 + ... to baseDamage := 400 + ...

# 2. Rebuild server (~30 seconds)
.\quick-test.ps1 server

# 3. Test in browser (server auto-restarts)
```

**Total time**: ~30 seconds

### Workflow 3: Modify UI

**Goal**: Change UI layout or styling

```powershell
# 1. Edit ui/**/*.ts or ui/**/*.scss

# 2. Rebuild UI (~1 minute)
.\quick-test.ps1 ui

# 3. Refresh browser
```

**Total time**: ~1 minute

### Workflow 4: Add New Custom Item

**Goal**: Add a completely new item for time-travel server

```powershell
# 1. Edit tools/database/overrides.go
# Add new item to ItemOverrides array

# 2. Regenerate database
.\quick-test.ps1 items

# 3. Restart server
.\quick-test.ps1 restart

# 4. Import gear from addon JSON
```

**Total time**: ~15 seconds

## Why is This Fast?

### Docker Layer Caching

The `Dockerfile.dev` uses multi-stage caching:

```dockerfile
# These layers are cached and only rebuilt when dependencies change
COPY go.mod go.sum package.json package-lock.json ./
RUN go mod download
RUN npm ci

# This layer rebuilds when proto files change
COPY proto ./proto
RUN protoc ...

# This layer rebuilds when code changes
COPY . .
```

### Volume Mounting

Source code is mounted as volumes, so changes are immediately visible:

```yaml
volumes:
  - ./sim:/wotlk/sim
  - ./tools:/wotlk/tools
  - ./assets:/wotlk/assets
  - ./ui:/wotlk/ui
```

### Local Database Generation

Database generation runs **outside Docker** on your local machine:
- No container overhead
- Full CPU/disk performance
- Results immediately available via volume mount

### Incremental Compilation

- `make` only recompiles changed files
- Go compiler uses build cache
- TypeScript uses incremental compilation

## Performance Comparison

| Operation | Production Build | Development Mode |
|-----------|------------------|------------------|
| First build | ~10 minutes | ~10 minutes |
| Modify overrides.go | ~5 minutes | **~15 seconds** |
| Modify Go code | ~5 minutes | **~30 seconds** |
| Modify UI code | ~5 minutes | **~1 minute** |
| Just restart | ~30 seconds | **~5 seconds** |

## Troubleshooting

### Container not found

```powershell
# Start the dev container
docker-compose -f docker-compose.dev.yml up -d
```

### Database generation fails

```powershell
# Check if required input files exist
ls assets/db_inputs/

# Ensure you have wowhead_item_tooltips.csv and wowhead_spell_tooltips.csv
```

### Build fails inside container

```powershell
# Check container logs
docker logs wowsims-wotlk-dev

# Enter container to debug
docker exec -it wowsims-wotlk-dev sh
```

### Changes not reflected

```powershell
# Verify volumes are mounted
docker inspect wowsims-wotlk-dev | Select-String "Mounts" -Context 5,10

# Force restart
docker restart wowsims-wotlk-dev
```

## Best Practices

1. **Use development mode for iteration**: Don't rebuild production image for every change
2. **Test incrementally**: Test after each small change rather than batching
3. **Use `items` command frequently**: It's very fast (~10s)
4. **Keep container running**: Start once, restart only when needed
5. **Monitor logs**: Use `docker logs -f wowsims-wotlk-dev` to watch for errors

## Related Files

- `Dockerfile.dev` - Development Dockerfile with caching
- `docker-compose.dev.yml` - Development compose configuration
- `quick-test.ps1` - Windows quick test script
- `quick-test.sh` - Linux/macOS quick test script
