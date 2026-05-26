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
- **Chosen:** AGENTS.md 从纯清单扩展为包含行为准则、上下文沙盒策略、目录结构、库优先级、Worktree 规则、验证命令的完整入口文档
- **Alternatives:** 保持精简清单 / 各规则散落在不同文档
- **Reason:** 新增的 ctx_search/ctx_execute 沙盒机制需要明确规则；验证命令需要统一避免混乱；行为准则避免 agent 盲目执行
- **Tradeoff:** AGENTS.md 变长，但通过 `> 详细:` 链接保持渐进披露
- **新增规则:**
  - 行为准则：澄清意图、深度调研、简单优先、精准修改、验证先行、Trivial 豁免(≤1文件且≤20行)
  - 上下文沙盒：默认粗筛(ctx_search/ctx_execute_file, 98%压缩率)，按需放行，禁用原生 curl/find/grep
  - 验证：统一命令 `./container/build.sh check`（ASAN + clang-tidy）
  - 库优先级：C++ 标准库 → 开源库(`./cross-library-examples/`) → 私有库(`./libs/`)
  - Worktree：`.worktrees/<分支名>`，命名 `feature/` | `fix/`，完成后清理

## Directory Audit (2026-05-26)

### 当前实际目录结构
```
./
├── .git/
├── .opencode/
├── AGENTS.md
├── docs/
│   └── agents/
│       └── knowledge/
│           ├── knowledge-index.md
│           ├── log.md
│           └── modules/
│               ├── cpp-env.md
│               └── infra.md
├── pics/
├── plan.md
├── C++开发环境配置.md
├── Qt-Android开发环境配置.md
├── gammaray_remote_debug.md
├── 产品体系构想.md
├── 遥感地形图路线规划技术方案.md
```

### AGENTS.md 引用路径状态（2026-05-26 补充）
| 路径 | 用途 | 状态 |
|------|------|------|
| `./docs/agents/index.md` | 元规则详细说明 | ✅ 已创建 |
| `./docs/agents/core/principles.md` | 核心原则与行为准则 | ✅ 已创建 |
| `./docs/agents/core/context-strategy.md` | 上下文沙盒策略 | ✅ 已创建 |
| `./docs/agents/core/structure.md` | 项目目录结构 | ✅ 已创建 |
| `./docs/agents/writing-guide.md` | 文档编写规范 | ✅ 已创建 |
| `./libs/` | 私有库目录 | ✅ 已创建(含 README) |
| `./cross-library-examples/` | 开源库使用示例 | ✅ 已创建(含 README) |
| `./container/build.sh` | 统一构建验证脚本 | ✅ 已创建(骨架，待接入 CMake 项目) |
| `./.worktrees/` | Git worktree 目录 | 未创建(正常，按需) |

## Open Questions
- 是否需要 `.github/` CI/CD 配置？
- 项目实际业务代码结构尚未确定
- Phase 4 native 地图引擎选型？
- Phase 6 插件总线系统的接口设计？
- `./container/build.sh` 需要在接入 CMake 项目后补充实际构建逻辑
