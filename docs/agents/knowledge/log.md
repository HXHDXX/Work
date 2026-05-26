# Knowledge Log

> Append-only chronological record of wiki operations.
> Parse: `grep "^## \[" log.md | tail -5` shows last 5 entries.

## Log

## [2026-05-26] lint + ingest | infra
- 删除 container/, cross-library-examples/, libs/ 占位目录（无实际内容）
- 更新 structure.md：移除目录树、代码依赖表、布局检查中对这三个目录的引用
- 更新 infra.md：Directory Audit 移除已删目录，Open Questions 移除 build.sh 相关条目
- 更新精简决策记录：补充目录删除信息
- Types: Decision, Module Info

## [2026-05-26] lint + ingest | infra
- AGENTS.md 精简：移除"库"和"验证" section，规则下沉至 structure.md
- infra.md lint：旧决策标记 Superseded，新增精简决策记录
- Directory Audit 更新：反映提交后的实际目录（含 container/, libs/, cross-library-examples/, docs/agents/core/）
- Types: Decision, Module Info

## [2026-05-26] ingest | infra
- AGENTS.md 扩展：新增行为准则、上下文沙盒策略、目录结构、库优先级、Worktree 规则、验证命令等 6 个小节
- 目录审计：AGENTS.md 引用的 8 个路径中 7 个尚未创建（docs/agents/index.md, docs/agents/core/*.md, writing-guide.md, libs/, cross-library-examples/, container/build.sh）
- Types: Decision, Module Info

## [2026-05-26] ingest | infra
- 创建 AGENTS.md 引用的全部缺失路径：docs/agents/index.md, docs/agents/core/{principles,context-strategy,structure}.md, docs/agents/writing-guide.md, libs/README.md, cross-library-examples/README.md, container/build.sh
- container/build.sh 为骨架脚本，支持 check(ASAN/Debug) 和 linux 命令，待接入实际 CMake 项目
- Types: Decision, Module Info

## [2026-04-08] ingest | infra
- 从 `plan.md` 提取项目路线图：6 阶段计划（OSM 渲染→Qt 环境→MVT 编译→native 地图引擎→demo 应用→插件总线+GIS server）
- Types: Strategy, Module Info

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
