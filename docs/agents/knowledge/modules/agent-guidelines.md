# Agent Guidelines

> Last updated: 2026-07-20

## Overview

- AGENTS.md 行为准则的归档位置，记录 Agent 编码纪律与 harness 元层机制的 Decisions
- 关键文件: `./AGENTS.md`, `./docs/agents/core/principles.md`
- See also: [[infra]], [[context-mode]]

## Decisions

### 新增 harness 反思与复利机制 (2026-07-20)
- **Chosen:** AGENTS.md 新增 `### harness 反思与复利` 节 + `docs/agents/core/harness-reflection.md` 详情文档（含触发/四维度/提案格式/治理规则/backlog），元层反思复用 project-compound 的 `[[ref]]` 与 log 结构；业务知识进 `project-compound`，元层提案进 `harness-reflection.md`，兑现后 ingest 入本模块
- **Alternatives:** 新增独立 skill（YAGNI，skill 偏执行而非反思）、复用 log.md 承载 backlog（时序语义不符，log 是已完成记录非待办）、将 backlog 放 knowledge/modules（扩 lint 范围，混淆业务知识与元层治理）
- **Reason:** harness 元层反思存在缺口（原只有项目业务知识的沉淀，缺少对 harness 环境的系统性反思），复用既有结构（AGENTS.md 清单 + core 详情 + project-compound ingest/query/lint）实现最小代价增量
- **Tradeoff:** 依赖 agent 纪律无自动化强制（与既有规则一致，无额外机制开销）
- **Adapted from:** HXProjectTemplate commit `b8f5ea7`，"构建验证链"维度改为"文档验证链"（Work 为文档主导项目，无 container/build.sh/ASAN）
> **Superseded by:** 移除 harness 反思与复利机制 (2026-08-07)

### 经验记忆：半自动捕获机制 (2026-08-07)
- **Chosen:** 建立 agent-experience skill（.opencode/skills/agent-experience/SKILL.md），agent 在任务完成后自动生成经验草稿（status: draft），人类审核确认（status: confirmed），跨项目存储于 ~/.dotfiles/.agent-experiences/
- **Alternatives:** (1) 完全自动 — 仍不采用；(2) 纯手动 — 捕获率低（依赖人类记得写）
- **Reason:** 半自动保留人类把关同时降低捕获门槛；agent 自动检索历史经验可跨项目复用，避免重复踩坑。对齐 HXProjectTemplate 56ac45d
- **Tradeoff:** 人类审核可能成为瓶颈（V1 可接受）；写入质量依赖 agent 草稿完整性
- **See also:** .opencode/skills/agent-experience/SKILL.md

### 移除 harness 反思与复利机制 (2026-08-07)
- **Chosen:** 删除 harness-reflection.md + AGENTS.md `### harness 反思与复利` 节 + 所有交叉引用；harness 摩擦改为当场修复或记入 agent-experience（type: other）
- **Alternatives:** 保留但加强兑现管道（自动化 lint/查询 hook）
- **Reason:** 3 周内 4 条提案 0 兑现——靠纪律驱动的"任务后反思"退化为仪式；维护成本 > 价值。对齐 HXProjectTemplate 56ac45d
- **Tradeoff:** 失去结构化的 harness 改进追踪；但 harness 摩擦仍可通过 agent-experience 或直接修复处理
- **Supersedes:** 新增 harness 反思与复利机制 (2026-07-20)

## Open Questions
<!-- Gaps that future work should address -->
- log.md 顺序与 project-compound skill 设计不一致（待提案）
