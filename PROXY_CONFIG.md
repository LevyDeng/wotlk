# Docker Build Proxy Configuration Guide

This guide explains how to configure proxy settings for Docker builds in China.

## Quick Start

### Method 1: Use Proxy Parameter (Recommended)

```powershell
.\docker.ps1 start -Proxy http://127.0.0.1:7890
```

### Method 2: Set Environment Variables

```powershell
$env:HTTP_PROXY = "http://127.0.0.1:7890"
$env:HTTPS_PROXY = "http://127.0.0.1:7890"
.\docker.ps1 start
```

### Method 3: Create .env File

Create a `.env` file in the project root:

```env
HTTP_PROXY=http://127.0.0.1:7890
HTTPS_PROXY=http://127.0.0.1:7890
http_proxy=http://127.0.0.1:7890
https_proxy=http://127.0.0.1:7890
NO_PROXY=localhost,127.0.0.1
no_proxy=localhost,127.0.0.1
```

Then run:
```powershell
.\docker.ps1 start
```

## Common Proxy Ports

- **Clash**: `http://127.0.0.1:7890` (default HTTP port)
- **V2Ray**: `http://127.0.0.1:10808` (default HTTP port)
- **Shadowsocks**: Usually requires SOCKS5 proxy, e.g., `socks5://127.0.0.1:1080`

## SOCKS5 Proxy Support

For SOCKS5 proxies, use the following format:

```powershell
.\docker.ps1 start -Proxy socks5://127.0.0.1:1080
```

Or in `.env` file:
```env
HTTP_PROXY=socks5://127.0.0.1:1080
HTTPS_PROXY=socks5://127.0.0.1:1080
```

## Verify Proxy Configuration

After setting up proxy, you can verify it's being used by checking the build output. You should see:
```
[INFO] Using proxy: http://127.0.0.1:7890
```

## Troubleshooting

1. **Proxy not working**: Make sure your proxy software is running and the port is correct
2. **Connection timeout**: Check if your proxy allows Docker connections
3. **Still slow**: Try using a different proxy server or check your network connection

## Pre-built Protobuf Image (No `go get` / `go install`)

The Dockerfile uses **rvolosatovs/protoc** as a stage to copy `protoc` and `protoc-gen-go` from. That image already has `google.golang.org/protobuf` tooling installed, so the build does **not** run `go get` or `go install` for protobuf. This avoids network/proxy issues for those steps. The Go module `google.golang.org/protobuf` (library) is still pulled when your project is built, via `GOPROXY` or `HTTP_PROXY`.

## Go Modules in China

The Dockerfile sets **GOPROXY=https://goproxy.cn,direct** so `go get` uses a China mirror for most modules (e.g. `google.golang.org/protobuf`) without needing your HTTP proxy.

- If **goproxy.cn** works: no need to set HTTP_PROXY for Go; just run `.\docker.ps1 start` (or with proxy only for apt/npm if needed).
- If **goproxy.cn** is blocked or slow: set your HTTP proxy when building. Go will use **HTTP_PROXY** for requests. Example:
  ```powershell
  $env:HTTP_PROXY = "http://192.168.1.3:7897"
  $env:HTTPS_PROXY = "http://192.168.1.3:7897"
  .\docker.ps1 start
  ```
- If the build runs inside Docker and cannot reach `192.168.1.3`, try the host from the container, e.g. `http://host.docker.internal:7897` (Windows/Mac).

## Notes

- The proxy configuration only affects the Docker build process
- Proxy settings are passed to the Dockerfile via build arguments
- The `.env` file is automatically loaded if it exists in the project root
- Environment variables take precedence over `.env` file settings
