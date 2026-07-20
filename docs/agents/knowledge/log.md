# Knowledge Log

> Append-only chronological record of wiki operations.
> Parse: `grep "^## \[" log.md | tail -5` shows last 5 entries.

## Log

## [2026-07-20] ingest | agent-guidelines
- 新增 harness 反思与复利机制：AGENTS.md 新节 + core/harness-reflection.md 详情（适配 Work 文档项目，将"构建验证链"维度改为"文档验证链"）+ index.md 目录树更新 + writing-guide.md 维护规则
- 业务知识进 project-compound，元层提案进 harness-reflection.md，兑现后 ingest 入 agent-guidelines Decisions
- Cross-ref: [[infra]]
- Types: Decision

## [2026-06-08] ingest | infra
- AGENTS.md 完善：依赖路径恢复（`./cross-library-examples/`、`./libs/`）、Worktree 防冲突命名规范（物理拓扑对齐+时间戳+Hash）、新增跨项目静态检索规则、编译验证命令修正、Context-Mode 格式统一
- infra.md 决策记录：依赖路径恢复与 Worktree 命名规范扩展 (2026-06-08)，Supersedes 05-26 精简决策
- 新增策略：跨项目知识借鉴策略
- Types: Decision, Strategy, Module Info

## [2026-05-28] lint | 全局
- AGENTS.md：修复已删除目录引用（`./cross-library-examples/` → `/opt/cross-library/`、`./libs/` → CMake 结构组织、新增构建脚本位置说明）
- context-strategy.md：同步 `ctx_batch_execute` 工具路由和沙盒断言
- principles.md：同步 AGENTS.md 措辞（"验证贯穿始终"合并两条、"先理解再行动"拆分静态/动态、Trivial 豁免补充禁止连续拆分和构建验证）
- infra.md：路线图从 Phase 4-8 更新到 Phase 1-24（与 plan.md 同步）；旧路线图决策标记 Superseded
- Types: Module Info, Decision

## [2026-05-26] lint | infra, cpp-env, docs
- AGENTS.md 精简：移除"库"和"验证" section → 下沉至 structure.md
- 删除 container/, cross-library-examples/, libs/ 占位目录（无实际内容）
- principles.md: 移除 `./container/build.sh` 引用
- cpp-env.md: 静态分析引用改为待定描述
- infra.md: 旧决策标记 Superseded 并压缩；Directory Audit 压缩为一行摘要
- structure.md: 目录树/依赖表/布局检查同步清理
- Types: Decision, Module Info

## [2026-04-10] ingest | infra
- 路线图状态更新：Phase 5 (demo 应用) 从准备中升级为实施中；Phase 6 (HXPluginRuntime) 暂停，目标改为先在3588设备上运行测试地图
- Types: Decision, Module Info

## [2026-04-10] ingest | infra
- 路线图拆分：Phase 7 (GIS server 基于 HXPluginRuntime) 暂停，新增 Phase 8 单独引入跨平台 GIS server，直接在3588设备上实施
- Types: Decision, Module Info

## [2026-04-10] ingest | cpp-env
- QtCreator 下载链接改为 latest 通用地址，不再固定版本号
- Types: Module Info

## [2026-04-08] ingest | cpp-env
- 从 `C++开发环境配置.md` 提取知识：GCC9 兼容方案、Docker buildx 跨平台构建、ASAN+ASLR 调试策略、valgrind 工具链、Core Dump 分析流程、CH340 驱动 bug、Git 分支合并流程
- Types: Decision, Strategy, Bug Experience, Module Info

## [2026-04-07] ingest | infra
- 项目初始化完成：AGENTS.md 清单式配置、docs/agents/knowledge/ 知识库骨架、project-compound skill
- Types: Decision, Strategy, Module Info
