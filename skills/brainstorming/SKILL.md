---
name: brainstorming
description: Clarify goals, constraints, and context before writing code or changing complex workflows.
---

# Brainstorming / 需求澄清

Use this skill **before** writing non-trivial code or modifying important workflows (e.g. pipelines, infrastructure, performance tuning).

## 1. Clarify the Goal

- 用自然语言回答三个问题：
  - **我们要解决什么问题？**（问题现象 / 背景）
  - **理想结果是什么？**（业务/科研上的“完成”定义）
  - **这次不打算做什么？**（明确 out-of-scope，避免过度设计）

示例：

> 问题：Part3 多 GPU 并行时 ns/day 明显低于单 GPU。  \n\
> 理想结果：在 8 GPU 并行下，每路 ns/day 接近或略低于单 GPU，整体吞吐提升。  \n\
> 本次不做：不改力场/物理参数，只优化调度和 CPU 绑核。

## 2. Map the System

- 简要列出本次涉及的组件/脚本/服务，例如：
  - 脚本：`run_part3_unified_*.sh`、`run_md_mmgbsa_rmsd.py`、`run_part3_md_single.sh`；
  - 外部工具：GROMACS、PyRosetta、MCP server 等；
  - 输入/输出：CSV、日志目录、结果文件。
- 用 3–5 行描述**数据流**：从哪来、经过哪些步骤、去哪儿。

## 3. Identify Constraints & Risks

- 资源约束：
  - GPU 数量与型号；
  - CPU 核数、是否有超线程（HT）；
  - 内存 / 磁盘 / I/O。
- 风险：
  - 是否会影响正在运行的任务；
  - 是否会破坏已有结果（例如误删输出目录）；
  - 性能优化是否可能影响科学结果（例如改变采样、物理设置）。

## 4. Draft High-Level Options

- 至少想出 **2–3 种可行思路**，不必很细：
  - 例如：\n\
    - A：保留现有架构，只调 CPU 绑核和 `ntomp`；\n\
    - B：减少并行度（少 GPU 并行），但保持单任务速度；\n\
    - C：重构 orchestrator，使 Part3 任务分批集中跑在少数 GPU 上。
- 对每个选项，简单写出优缺点（1–2 条即可）。

## 5. Decide & Hand Off to Planning

- 在上面选项中挑一个当前最合适的（可以“暂定”，以后再调整）。\n\
- 清晰写出后续 plan 的输入：\n\
  - 要改哪些文件/脚本；\n\
  - 预计需要多少步；\n\
  - 如何验证效果（性能/正确性）。

完成以上步骤后，再调用“写计划（write-plan-generic）”相关流程，把思路转成可执行的 TODO 列表。   \n在 Cursor 中，可以先让助手帮你总结这 5 步的内容，再一起 refine 成正式的 `.plan.md`。
