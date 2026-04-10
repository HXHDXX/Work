# Knowledge Log

> Append-only chronological record of wiki operations.
> Parse: `grep "^## \[" log.md | tail -5` shows last 5 entries.

## Log

## [2026-04-08] ingest | infra
- 从 `plan.md` 提取项目路线图：6 阶段计划（OSM 渲染→Qt 环境→MVT 编译→native 地图引擎→demo 应用→插件总线+GIS server）
- Types: Strategy, Module Info

## [2026-04-10] ingest | infra
- 路线图状态更新：Phase 5 (demo 应用) 从准备中升级为实施中；Phase 6 (HXPluginRuntime) 暂停，目标改为先在3588设备上运行测试地图
- Types: Decision, Module Info

## [2026-04-10] ingest | infra
- 路线图拆分：Phase 7 (GIS server 基于 HXPluginRuntime) 暂停，新增 Phase 8 单独引入跨平台 GIS server，直接在3588设备上实施
- Types: Decision, Module Info

## [2026-04-08] ingest | cpp-env
- 从 `C++开发环境配置.md` 提取知识：GCC9 兼容方案、Docker buildx 跨平台构建、ASAN+ASLR 调试策略、valgrind 工具链、Core Dump 分析流程、CH340 驱动 bug、Git 分支合并流程
- Types: Decision, Strategy, Bug Experience, Module Info

## [2026-04-07] ingest | infra
- 项目初始化完成：AGENTS.md 清单式配置、docs/agents/knowledge/ 知识库骨架、project-compound skill
- Types: Decision, Strategy, Module Info
