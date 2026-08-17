# 经验记忆（agent-experience）

> 非 trivial 任务的原始经验捕获与检索系统，跨项目共享，半自动（draft → 人类确认 → confirmed/rejected）。

## 1. 三层记忆架构

- 工作记忆：opencode 上下文（当前任务窗口，任务结束即失效，不复利）
- 语义记忆：`project-compound` + `./docs/agents/knowledge/`（去重综合结论，随项目演进）
- 经验记忆：`agent-experience` skill + `~/.dotfiles/.agent-experiences/`（原始事件流，跨项目共享）
- 三者互补：工作记忆管当下，语义记忆管结论，经验记忆管原始经过

## 2. 经验记忆的角色

- 跨项目复利：一次调试踩坑，其他项目 agent 可通过 query 继承，避免重复试错
- 半自动捕获：任务后自动生成 draft，人类确认后才成为有效经验（防垃圾入库、防自动提取幻觉）
- agent 自动检索：非 trivial 任务开始前 MUST query，历史经验作为上下文背景注入

## 3. 与语义记忆（project-compound）的边界

- 经验 = 原始事件流（一次次的经过，允许重复与噪音，保留细节）
- 语义 = 去重综合结论（跨经验提炼，一句话可用，可被 ingest/query/lint）
- 升华路径：confirmed 经验具普适性 → 手动 `project-compound ingest` → 语义层
- 反向不成立：语义结论不回填经验层，保持原始痕迹可追溯
- ECC 决策（2026-05-26）：自动提取不可行，升华必须人工触发，禁止自动批量 ingest

## 4. Capture 操作详解

- 触发：非 trivial 任务完成（debug / architecture / integration 必选；trivial 豁免）
- ID 生成：`YYYYMMDD-HHMMSS-<4hex>`（如 `20260807-101530-a1b2`）
- Frontmatter schema（flat，单层键值，grep 兼容）：
  - `id`（YYYYMMDD-HHMMSS-<4hex>）/ `created_at`（YYYY-MM-DD）/ `type` / `project`（来源项目名）/ `tags`（逗号分隔）/ `status` / `schema_version`
- type 枚举：`debug`（Symptom→Reproduce→Hypotheses Tried→Root Cause→Fix→Prevention）/ `architecture`（Context→Options→Decision→Rationale→Tradeoffs）/ `integration`（Library→What Integrated→Approach→Gotchas）/ `tool`（Tool→Usage Pattern→Tips→Pitfalls）/ `decision`（原子单选用户偏好，捕获即 confirmed，rationale 标 `[inferred]`，`related:` peer 交叉引用）/ `other`（自由叙事）
- Dedup：写前 grep 经验目录查语义重复（grep-before-write），有则合并或标 `Supersedes-candidate:`
- 半自动流程：任务完成 → capture 生成 draft → 人类审核 → confirmed / rejected
- 文件落点：`~/.dotfiles/.agent-experiences/{YYYYMMDD-HHMMSS-<4hex>}.md`，按 project 字段标注来源

## 5. Query 操作详解

- 检索键：tags / type / project / 关键词（对 `~/.dotfiles/.agent-experiences/` 全文 grep，按 `created_at` 倒序）
- 上限：Top-5 by recency，防止旧经验淹没新经验（经验按创建时间倒序）
- 空结果处理：标注"无匹配经验"，照常进行，禁止编造相关经验凑数
- 结果注入：query 输出作为任务开始前的上下文背景，不替代语义记忆检索（两者并行）

## 6. 生命周期

- `draft`：capture 自动生成，等待人类确认（初始态）
- `confirmed`：人类审核通过，可被 query 命中
- `rejected`：人类否决，保留理由（防重提，不删除）
- `archived`：confirmed 经验升华入语义层后归档，或长期无引用折叠
- 升华：confirmed → 具普适性 → 手动 `project-compound ingest` → 语义层，原经验可归档

## 7. 常见错误

- 把 draft 当 confirmed 用：自动捕获未经人类确认，检索结果被未验证经验污染
- 把经验当语义用：query 到原始经验直接当结论引用，应看 status 与 tags 再判断
- 跳过 grep-before-write：同一条经验重复 capture，目录膨胀且检索噪音
- 跨项目经验不标 project：失去来源可追溯性，跨项目复利退化为孤儿记录
- 自动升华：未经人类确认批量 ingest，违反 ECC 决策（2026-05-26）
- 把 Y/N 确认掰成 2-options 凑 decision capture：只有真正 ≥2 并列候选且留下可复用偏好才记录，确认性提问不触发

## 8. See also

- [[../knowledge/knowledge-index.md]] - 语义记忆（升华目标层）
