---
name: write-plan-generic
description: Create concise, executable implementation plans (.plan.md) before making non-trivial changes.
---

# 写计划（Write Plan）通用流程

Use this skill after brainstorming, before implementing non-trivial changes.

## 1. When to Write a Plan

建议在以下情况**必须**写 `.plan.md`（或更新已有 plan）：\n\
- 涉及多个文件 / 脚本的修改；\n\
- 影响重要流程（如 pipeline、编排器、部署脚本）；\n\
- 可能影响性能/资源占用（GPU/CPU/内存/I/O）；\n\
- 需要分多次对话/多天完成的任务。

## 2. Plan 文件推荐结构

在项目根或 `.cursor/plans/` 下创建类似文件：\n\
`<project>_<topic>_<short-id>.plan.md`

建议包含以下部分：

1. **name**：计划名称，简短清晰。\n\
2. **overview**：1–3 句描述目标、背景和范围。\n\
3. **todos**：拆分成若干条 todo，每条包含：\n\
   - `id`：简短英文 id；\n\
   - `content`：要做什么；\n\
   - `status`：`pending | in_progress | completed | cancelled`。\n\
4. **details**（可选）：设计细节、数据流图、注意事项。\n\
5. **verification**：如何验证本计划完成且正确（命令/脚本/日志/性能指标等）。

## 3. 拆 todo 的原则

- 每个 todo 目标要**单一明确**（“改某个脚本的某部分逻辑”、“新增一个文档章节”等）；\n\
- 控制在 **2–10 分钟** 可执行完的粒度（偏向 superpowers 的 small tasks）；
- 尽量**避免**“大杂烩型 todo”（例如“重构整个 Part3 并写文档”），而是拆成：\n\
  - 修改脚本 A；\n\
  - 修改脚本 B；\n\
  - 更新文档；\n\
  - 运行验证脚本并记录结果。

## 4. 结合 Cursor 的使用方式

- 在 plan 文件中：\n\
  - 用 `todos` 字段管理任务状态；\n\
  - 在对话中让助手**严格按 todo 顺序执行**，并在每步后更新状态。\n\
- 对于已经有的 plan（例如 `protein_filter_pipeline_系统优化_*.plan.md`）：\n\
  - 优先在现有 plan 上追加新的 todo，而不是另起一个零散文档；\n\
  - 保持“一个 topic / 项目一条主线 plan”的风格，便于长期维护。

## 5. 小示例

```yaml
name: Part3 CPU 绑核与性能优化
overview: 诊断并优化 Part3 在 8 GPU 并行下的 CPU 核使用与 ns/day 性能。
todos:
  - id: analyze-current
    content: 分析当前 Part3 日志与 CPU 使用情况（htop/mpstat/Cpus_allowed）
    status: completed
  - id: design-pinoffset
    content: 设计并实现基于 logical_gpu_id 的 pinoffset 方案
    status: completed
  - id: benchmark
    content: 重启 Part3，采集 ns/day 与 CPU 利用率，对比优化前后
    status: pending
  - id: doc-update
    content: 在 PART3_AMBER_WORKFLOW_SUMMARY.md 中记录本次优化与结论
    status: pending
```

写完 plan 后，再调用“execute-plan-generic”相关流程，按 todo 一个个推进实现与验证。

