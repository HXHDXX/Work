# Harness 反思与复利

> 任务完成后对 harness 环境（元层）进行反思，把单次任务体验转化为 AGENTS.md / skill / hook 的改进提案。

## 1. 触发条件与时机

- 非 trivial 任务完成后触发（trivial 不触发）
- 顺序：**先 `project-compound ingest`，再 `harness-reflection`**
  - 原因：反思可能派生独立的 harness 任务（改规则、改 skill、改 hook），先固化业务知识再处理元层
- 失败/中止任务同样触发；harness 失败信号最丰富
- 聚焦点："harness 何处使任务更难"，而非自责

## 2. 与 project-compound 的边界

- `project-compound`：项目业务知识（决策 / bug / 策略，过去式）
- `harness-reflection`：元层环境体验（提案，未来式）
- 两者互不重叠，同期执行
- 当 harness 提案兑现后，通过 `project-compound ingest` 写入 `agent-guidelines.md` 的 Decisions（审计链不断）

## 3. 四维度引导问题

### Skill 体验

- 本次任务哪个 skill 帮上忙？
- 哪步反复手动重复，本该被 skill 自动化？
- 是否感觉缺某个 skill？

### AGENTS.md 规则

- 哪条规则造成摩擦 / 歧义 / 遗漏？
- 哪条规则本次救了你？
- 是否有规则与本次实际流程脱节？

### Hook / MCP 机制

- 是否缺某个 hook（例如改文档前强制 lint 链接）？
- Context-Mode 沙盒是否误拦或漏拦？
- 工具路由是否在某个环节不顺畅？

### 文档验证链

- AGENTS.md 清单项与 `./docs/agents/` 详情是否一一对应（无死链）？
- `> 详细:` 引用与 `See also` 双向链接是否完整？
- writing-guide.md 的格式规则（路径前缀、表格优先、行数目标）是否被遵守？
- knowledge 库是否健康（无孤儿页、无矛盾决策、log 可解析）？

## 4. 提案格式

```markdown
### [{date}] {简述}
- 位置: AGENTS.md 的 ### XXX 节 / .opencode/skills/xxx / ...
- 现状→提案: 当前 X → 改为 Y（具体可 diff）
- 理由: 本次任务中观察到 Z
- 风险(可选): 仅非显然时填
- 状态: open | done | rejected | needs-user-decision | closed-not-acted
- 维度: skill | rules | hook-mcp | doc-verify（主维度，可加 also:）
```

## 5. 治理规则

- **"值得提案？"门槛**：一次性摩擦、显而易见的本地修、已被既有规则覆盖 → 不入 backlog（直接修或在 ingest 间隙处理）
- **"无提案合法"**：无可提案观察是合法结果，禁止为凑数编造
- **可执行性杠**：每提案必含具体 `位置` + 具体 `现状→提案`；纯吐槽拒收
- **去重**：写前 grep backlog 查语义重复，有则合并或标 `Supersedes-candidate:`
- **僵尸防治**：折叠进 `project-compound` 的 `lint` 周期——`open` 超 5 个任务无动作 → 标 stale；再 stale 2 个任务 → `closed-not-acted` + 理由
- **拒绝归档**：`rejected` + `reason` 入 `## Rejected` 小节，不删（防重提）
- **元提案路由**：反思机制自身的提案（如"砍字段""删机制"）→ `needs-user-decision`，禁自动应用
- **生命周期桥**：backlog 提案兑现后 → `status: done` + 触发 `project-compound ingest` 入 `agent-guidelines` 为 Decision

## 6. 嵌入式 Backlog 小节

- 文档末尾保留 `## Backlog`（open）+ `## Rejected` 两小节
- bootstrap 时空白合法
- 硬拆分阈值：`## Backlog` 中 open 提案 > 15 时，提升为独立 `core/harness-backlog.md` + `./docs/agents/index.md` 加行
- 拆分后本文件保留规则说明，backlog 仅保留引用链接

## 7. Bootstrap 说明

- 首次反思时 backlog 为空属正常
- "query backlog" 返回空 = 无继承提案，照常进行
- 空反思直接产出 `## Backlog` 空节，不补无关内容

## 8. See also

- [[agent-guidelines]] - 行为准则与 Decisions 归档位置

## Backlog

- （初始为空）

## Rejected

- （初始为空）
