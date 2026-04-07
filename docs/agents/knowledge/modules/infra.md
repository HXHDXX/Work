# Infra

> Last updated: 2026-04-07

## Overview
- 项目基础设施与工具链配置
- Key files: `./AGENTS.md`, `./.opencode/skills/project-compound/SKILL.md`, `./docs/agents/knowledge/`
- Git remote: `git@github.com:HXHDXX/Work.git` (origin, master)
- Dependencies: opencode runtime (`.opencode/node_modules/`, 不提交)

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

## Open Questions
- 是否需要 `.github/` CI/CD 配置？
- 项目实际业务代码结构尚未确定
