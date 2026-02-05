# cursor-config

Cursor IDE 全局配置：Rules、MCP、Skills。支持跨设备迁移。

## 目录结构

```
cursor-config/
├── rules/          # Cursor 规则 (.mdc) – 包含 testing/security/workflow 等
├── mcp/            # MCP 配置（已脱敏）
├── skills/         # Skills（包括 coding-workflows、brainstorming、write-plan-generic 等）
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

## Superpowers 风格工作流（简要）

本仓库集成了一些类似 `superpowers` 的工作流约定，主要包括：

- `rules/workflow.mdc`：全局工作流规则，强调：\n\
  - 写代码前先**澄清需求/约束**；\n\
  - 对非琐碎改动先写 `.plan.md`（目标 + TODO + 验证）；\n\
  - 按 plan 小步实现，每步都做一次验证并记录结论。
- `skills/brainstorming/`：在改动前梳理问题、目标、范围和约束。\n\
- `skills/write-plan-generic/`：帮助把想法拆成可执行的 `.plan.md` 计划。\n\
- `skills/execute-plan-generic/`：按 TODO 推进计划并更新状态。\n\
- `skills/part3-performance-analysis/`：针对 Part3 MD（多 GPU/CPU 绑核）的性能分析模板，可在类似 `protein_filter_lib` 的项目中复用。

在新的仓库或服务器上安装本配置后，建议：

1. 先用 `brainstorming` skill 澄清当前任务；\n\
2. 再用 `write-plan-generic` skill 生成/完善 `.plan.md`；\n\
3. 最后用 `execute-plan-generic` skill 按计划一步步实现与验证。\n\


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
