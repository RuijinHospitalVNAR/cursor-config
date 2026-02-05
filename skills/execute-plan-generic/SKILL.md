---
name: execute-plan-generic
description: Execute existing .plan.md files step-by-step, updating TODO statuses and verifying results.
---

# 执行计划（Execute Plan）通用流程

Use this skill when there is an existing `.plan.md` 文件需要执行或继续推进。

## 1. 准备：读取并理解 Plan

- 打开对应的 `.plan.md` 文件，确认：\n\
  - 目标和范围（overview）；\n\
  - 当前 todos 列表与状态；\n\
  - 验证方式（verification，若有）。\n\
- 简要复述一下当前**剩余任务**和**优先级**，避免跑偏。

## 2. 严格按 TODO 顺序推进

- 选择第一个 `status = pending` 的 todo，将其标记为 `in_progress`。\n\
- 在实现过程中：\n\
  - 尽量所有改动都围绕这一个 todo 展开；\n\
  - 需要新增小任务时，可以在 todo 列表中插入新的条目（保持清晰）。\n\
- 完成后：\n\
  - 将该 todo 状态改为 `completed`；\n\
  - 简短记录一下具体做了什么（可写在 plan 或相关文档中）。\n\
\n\
> 注意：不要在多个 todo 之间频繁跳来跳去，避免产生“完成了一半但不好回滚”的状态。

## 3. 每步都要“验证一次”

对每个 todo，尽可能执行一次对应的验证动作，例如：\n\
- 跑单元测试 / 集成测试；\n\
- 执行某个脚本、查看 log / ns/day / 资源使用；\n\
- 在 htop/mpstat 中确认资源是否按预期变化。\n\
\n\
如果验证不通过：\n\
- 直接在当前 todo 下修复问题，不要贸然推进下一条；\n\
- 实在无法修复时，可以将该 todo 标记为 `cancelled`，并在 plan 中写明原因与后续打算。

## 4. 与文档/配置联动

- 涉及流程/性能/资源优化的 todo 完成后：\n\
  - 更新相应文档（例如 `PART3_AMBER_WORKFLOW_SUMMARY.md`、`CPU核占用分隔修复说明.md` 等）；\n\
  - 如本次改动会影响其他项目/服务器，记得在 Cursor 配置仓库（如 `cursor-config`）中同步规则/skill。\n\
- 这样可以确保后续在**新服务器或新项目中重用同一方案**。

## 5. 收尾：检查是否还有遗留 TODO

- 当所有 todo 都是 `completed` 或 `cancelled` 时：\n\
  - 回顾 plan，确认是否有新增的风险/后续工作需要开新 plan；\n\
  - 在项目 README 或变更日志中简短记录本次计划的完成情况。\n\
- 若还有 pending 的 todo：\n\
  - 要么继续执行；\n\
  - 要么明确说明为何推迟（并在 plan 中更新说明）。\n\
\n\
在 Cursor 中执行 plan 时，建议每完成/变更一步，就让助手帮你更新 plan 文件中的状态，保持计划和实际始终一致。\n+
