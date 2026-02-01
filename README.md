# cursor-config

Cursor IDE 全局配置：Rules、MCP、Skills。支持跨设备迁移。

## 目录结构

```
cursor-config/
├── rules/          # Cursor 规则 (.mdc)
├── mcp/            # MCP 配置（已脱敏）
├── skills/         # Skills
└── scripts/        # 安装脚本
```

## 安装

### Windows

```powershell
cd cursor-config\scripts
.\install.ps1 -GitRepoPath "F:\path\to\your\git\repo" -PythonPath "python"
```

### macOS / Linux

```bash
cd cursor-config/scripts
chmod +x install.sh
./install.sh --git-repo-path /path/to/your/repo
```

## 安装后配置

1. **FIRECRAWL_API_KEY**：如使用 firecrawl-mcp，设置环境变量
2. **GIT_REPO_PATH**：安装时未指定则需手动编辑 `~/.cursor/mcp.json`，将 `{{GIT_REPO_PATH}}` 替换为你的仓库路径
3. 重启 Cursor 使配置生效

## MCP 占位符说明

| 占位符 | 说明 | 安装脚本处理 |
|--------|------|--------------|
| `{{USER_HOME}}` | 用户主目录 | 自动替换 |
| `{{PYTHON_PATH}}` | Python 可执行路径 | 自动替换（默认 python / python3） |
| `{{GIT_REPO_PATH}}` | mcp_server_git 仓库路径 | 安装时指定或手动替换 |
| `YOUR_FIRECRAWL_API_KEY_HERE` | Firecrawl API Key | 需设置环境变量 |

## Cursor 配置目录（各平台）

| 平台 | Rules | MCP | Skills |
|------|-------|-----|--------|
| Windows | `%USERPROFILE%\.cursor\rules\` | `%USERPROFILE%\.cursor\mcp.json` | `%USERPROFILE%\.cursor\skills-cursor\` |
| macOS | `~/.cursor/rules/` | `~/.cursor/mcp.json` | `~/.cursor/skills-cursor/` |
| Linux | `~/.cursor/rules/` | `~/.cursor/mcp.json` | `~/.cursor/skills-cursor/` |

## 推送到 GitHub

```bash
cd cursor-config
git init
git add .
git commit -m "Initial cursor-config"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/cursor-config.git
git push -u origin main
```

## 新设备安装

```bash
git clone https://github.com/YOUR_USERNAME/cursor-config.git
cd cursor-config/scripts
# 运行对应平台的安装脚本
```
