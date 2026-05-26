# Infra

> Last updated: 2026-05-26

## Overview
- 项目基础设施与工具链配置
- Key files: `./AGENTS.md`, `./plan.md`, `./.opencode/skills/project-compound/SKILL.md`, `./docs/agents/knowledge/`
- Git remote: `git@github.com:HXHDXX/Work.git` (origin, master)
- Dependencies: opencode runtime (`.opencode/node_modules/`, 不提交)
- See also: [[cpp-env]]

## Decisions

### Agent 配置采用清单式 AGENTS.md (2026-04-07)
- **Chosen:** AGENTS.md 只写清单，不写说明；说明下沉到 `./docs/agents/`
- **Alternatives:** 所有信息集中在 AGENTS.md / 使用多个配置文件
- **Reason:** 渐进式披露，减少主 agent 上下文占用，按需深入
- **Tradeoff:** 需要多一层文件读取

### 知识管理采用 project-compound skill (2026-04-07)
- **Chosen:** 使用 opencode skill 定义知识积累流程（ingest/query/lint 三操作）
- **Alternatives:** 手动维护文档 / 使用外部 wiki
- **Reason:** skill 可被主 agent 和子 agent 自动发现并加载，流程标准化
- **Tradeoff:** 依赖 opencode 平台的 skill 机制

### .opencode/ 目录管理策略 (2026-04-07)
- **Chosen:** `.opencode/` 提交到版本库，但 `node_modules/`、`package.json`、`bun.lock`、`.gitignore` 通过子目录 `.gitignore` 排除
- **Alternatives:** 整个 `.opencode/` 加入 .gitignore / 全部提交
- **Reason:** skills 定义需要版本控制；依赖文件和锁文件不需要
- **Tradeoff:** 需要每个开发者本地安装 `.opencode/` 依赖

## Strategies

### 渐进式披露文档结构 (2026-04-07)
- **Problem:** Agent 上下文有限，不能一次加载所有项目知识
- **Approach:** 三层结构 — AGENTS.md(清单) → docs/agents/(说明) → knowledge/modules/(详情)
- **When to reuse:** 任何需要 agent 知识管理的项目

## Roadmap

### 项目路线图 (2026-04-08, updated 2026-04-10)
- Source: `./plan.md`
- Phase 1: OSM pbf 实时渲染服务 (Windows/Android) — **已完成**
- Phase 2: 跨平台 Qt 应用开发环境 — **已完成**
- Phase 3: 编译 OSM 数据到 MVT — **已完成**
- Phase 4: 引入封装 native 地图引擎 — **进行中**
- Phase 5: Demo 应用显示矢量瓦片数据 — **进行中**
- Phase 6: HXPluginRuntime — **暂停**，目标改为先在3588设备上运行测试地图
- Phase 7: 跨平台 GIS server (基于 HXPluginRuntime) — **暂停**，目标改为先在3588设备上运行测试地图
- Phase 8: 单独引入跨平台 GIS server — **进行中** (先在3588设备上运行测试地图)
- 技术栈: Qt / C++ / OSM / MVT / Docker / native 地图引擎
- See also: [[cpp-env]]

### 路线图策略调整：3588 设备优先 (2026-04-10)
- **Chosen:** 暂停 HXPluginRuntime 跨平台插件运行时，优先在 3588 设备上运行测试地图
- **Alternatives:** 继续推进 HXPluginRuntime / 先完成通用 demo 再上设备
- **Reason:** 需要在实际硬件上验证地图引擎能力，降低后期集成风险
- **Tradeoff:** HXPluginRuntime 推迟，跨平台能力延后

### 路线图拆分：GIS server 独立推进 (2026-04-10)
- **Chosen:** 将 Phase 7 (基于 HXPluginRuntime 的 GIS server) 暂停，新增 Phase 8 单独引入跨平台 GIS server，直接在3588设备上实施
- **Alternatives:** 等 HXPluginRuntime 完成后再启动 GIS server / 不上3588先做通用方案
- **Reason:** 3588设备验证更紧迫，GIS server 不必依赖 HXPluginRuntime，可独立先行
- **Tradeoff:** Phase 7 和 Phase 8 后续可能需要合并/对齐架构

### AGENTS.md 扩展：行为准则与验证规则 (2026-05-26)
> **Superseded by:** AGENTS.md 精简：移除库与验证 section，删除占位目录 (2026-05-26)
- AGENTS.md 曾扩展为包含行为准则、沙盒策略、目录结构、库优先级、Worktree 规则、验证命令的完整入口
- 后因"库"和"验证" section 不适合放在入口清单层，已精简回核心行为准则
- "库"和"验证"的具体规则下沉至 `./docs/agents/core/structure.md`；`container/`、`libs/`、`cross-library-examples/` 目录已删除

### AGENTS.md 精简：移除库与验证 section，删除占位目录 (2026-05-26)
- **Chosen:** 从 AGENTS.md 删除"库"和"验证"两个 section；删除不再需要的 `container/`、`cross-library-examples/`、`libs/` 占位目录
- **Alternatives:** 保留空目录占位 / 仅删除 AGENTS.md section
- **Reason:** 这些目录是上次扩展时创建的骨架，无实际内容；AGENTS.md 不再引用它们，保留会造成混淆
- **Tradeoff:** 后续如需这些目录需重新创建
- **Supersedes:** AGENTS.md 扩展：行为准则与验证规则 (2026-05-26)

## Directory Audit (2026-05-26)

当前项目为纯文档/知识库结构，无业务代码目录。所有 AGENTS.md `> 详细:` 引用的路径均已提交。唯一按需目录 `.worktrees/` 尚未创建（正常）。详见 `./docs/agents/core/structure.md`。

## Open Questions
- 是否需要 `.github/` CI/CD 配置？
- 项目实际业务代码结构尚未确定
- Phase 4 native 地图引擎选型？
- Phase 6 插件总线系统的接口设计？
