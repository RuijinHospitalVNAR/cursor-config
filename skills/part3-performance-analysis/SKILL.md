---
name: part3-performance-analysis
description: Diagnose and optimize Part3 MD performance (ns/day, GPU/CPU usage, pinning) for multi-GPU runs.
---

# Part3 性能分析与优化（多 GPU 场景）

Use this skill when investigating Part3 性能（ns/day）、GPU/CPU 利用率，或调整并行/绑核策略。

> 以下示例路径基于当前项目：`/data/wcf/protein_filter_lib` 与 `AF3_prediction/IgGM_2d4d2_sh3_op_...`，在其他项目上请替换为对应路径结构。

## 1. 收集基础信息

1. **确认脚本与参数**：\n\
   - 统一脚本：`run_part3_unified_relaxed_nvt310_ff14sb.sh`；\n\
   - 单结构脚本：`YZC_MD_SCRIPT/run_part3_md_single.sh`；\n\
   - Python 驱动：`scripts/run_md_mmgbsa_rmsd.py`；\n\
   - 当前 `--ntomp`、`--n_gpu`、`--production_ns`、`--npt_ns` 等参数。\n\
\n\
2. **查看现有文档**：\n\
   - 流程与参数总结：`protein_filter_lib/docs/PART3_AMBER_WORKFLOW_SUMMARY.md`；\n\
   - CPU 绑核说明：`CPU核占用分隔修复说明.md`（若存在）；\n\
   - 性能分析文档：`提速效果分析_*.md`、`运行情况分析_*.md` 等。

## 2. 收集 Performance (ns/day)

1. 从日志中提取 GROMACS 的 `Performance:` 行：\n\
   ```bash\n\
   grep -h \"Performance:\" /path/to/part3_output/gpu*/run_resume_*.log \\\n\
     /path/to/part3_output/gpu*/*/NVT.log \\\n\
     /path/to/part3_output/gpu*/*/NPT.log \\\n\
     /path/to/part3_output/gpu*/*/Production.log 2>/dev/null | tail -40\n\
   ```\n\
2. 按 GPU 分组，记录每块 GPU 上代表性的 ns/day 区间（例如 1.3–1.7 ns/day）。\n\
3. 找到**基线**：\n\
   - 单 GPU 独占时的最佳 ns/day；\n\
   - 多 GPU 并行修复前的 ns/day 区间。

## 3. 检查 GPU 与 CPU 使用情况

1. **GPU 使用**：\n\
   - `nvidia-smi` / `watch -n 1 nvidia-smi` 查看各 GPU 利用率与显存；\n\
   - 注意：Part3 中 CPU 往往是瓶颈，GPU 利用率低不一定是问题。\n\
\n\
2. **CPU 使用（等价 htop 顶部）**：\n\
   ```bash\n\
   mpstat -P ALL 1 1\n\
   ```\n\
   - 关注 0–50 多个核是否被持续占用；\n\
   - 若仅少数核接近 100%、其它几乎 0%，说明可能存在绑核/调度问题。\n\
\n\
3. **进程级 CPU（等价 htop 进程列表）**：\n\
   ```bash\n\
   ps -e -o pid,pcpu,pmem,comm,args --no-headers | sort -k2 -rn | head -30\n\
   ```\n\
   - 正常情况下，每个 `gmx mdrun` 会占用数百 % CPU（表示多核并行）。\n\
   - 若所有 gmx 都只有极低 CPU%（且长时间不变），则需要排查是否在 I/O 或死锁。

## 4. 检查 CPU 绑核（pinoffset + Cpus_allowed）

1. 查看 gmx 命令行中的 pinoffset：\n\
   ```bash\n\
   pgrep -af \"gmx mdrun\" | grep -v \"pgrep\\\\|grep\"\n\
   ```\n\
   - 预期看到多组 `-pinoffset 0, 12, 24, 36, 48, 60, 72, 84` 等。\n\
   - 若全部是 `-pinoffset 0`，说明 CPU 核未按任务分隔。\n\
\n\
2. 查看每个 gmx 的 Cpus_allowed：\n\
   ```bash\n\
   for pid in $(pgrep -f \"gmx mdrun\"); do\n\
     echo \"--- PID $pid ---\";\n\
     ps -p $pid -o args= 2>/dev/null | grep -oE \"pinoffset [0-9]+\";\n\
     grep \"^Cpus_allowed:\" /proc/$pid/status 2>/dev/null;\n\
   done\n\
   ```\n\
   - 若不同 PID 的 `Cpus_allowed` 掩码不同，说明各任务绑在不同核段上；\n\
   - 若所有 gmx 的 `Cpus_allowed` 完全一样（尤其是 `...,00000001`），说明所有任务挤在同一批核。\n\
\n\
3. 对照脚本实现：\n\
   - `run_part3_md_single.sh` 是否支持 `--pinoffset`；\n\
   - `run_md_mmgbsa_rmsd.py` 是否按 `logical_gpu_id * ntomp` 传入 pinoffset；\n\
   - `run_part3_unified_*.sh` 是否为 WT 或特殊任务设置了合适的 pinoffset。

## 5. 形成结论与优化建议

- 综合前面信息，回答几个关键问题：\n\
  1. 当前多 GPU 并行的 ns/day 与单 GPU 基线相比如何？\n\
  2. 是否存在明显的 CPU 绑核问题（所有任务挤在少数核）？\n\
  3. 各 GPU/ns/day 之间的差异，是否主要来自结构/阶段/I/O，而非资源分配错误？\n\
- 形成一份短报告（建议写入 `运行情况分析_YYYYMMDD.md` 类文档）：\n\
  - 概要：是否存在性能瓶颈或异常；\n\
  - 证据：日志中的 Performance 行、mpstat/ps/htop 截图或统计；\n\
  - 建议：是否需要进一步减少并行度、调整 ntomp、优化 I/O 或修改脚本逻辑。\n\
\n\
在后续对 Part3 做任何结构性修改（如 CPU 绑核策略/并行度/阶段参数）前，建议先运行本 skill 的流程，以便有一套可重复的分析与对比基础。+
