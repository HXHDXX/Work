# 知识库索引

> 本索引遵循渐进式披露原则。

## 模块列表

> 模块摘要位于 `./modules/`，每个模块 50-100 行

| 模块 | 描述 | 摘要路径 |
|------|------|---------|
| infra | 项目基础设施、工具链配置、知识管理策略 | `./modules/infra.md` |
| cpp-env | C++ 开发环境配置：GCC/Docker/Qt/调试分析 | `./modules/cpp-env.md` |
| agent-guidelines | Agent 编码行为原则、经验记忆半自动捕获 | `./modules/agent-guidelines.md` |

## 全局主题

> 跨模块的通用知识

| 主题 | 描述 | 路径 |
|------|------|------|
<!-- Add global topics here -->

---

## 经验记忆层（独立于语义记忆）
- **Skill:** `agent-experience`（capture/query/lifecycle）
- **存储位置：** `~/.dotfiles/.agent-experiences/`，由 `agent-experience` skill 管理（query/capture）
- **边界：** 经验记忆 = 原始事件流（跨项目，按 project 字段标注来源）；语义记忆 = 综合结论（per-project）
- **升华路径：** confirmed 经验 → 手动 `project-compound ingest` → 语义层
- **See also:** `.opencode/skills/agent-experience/SKILL.md`（skill）、`../core/experience-memory.md`（设计文档）

---

## 操作日志

> 时间线记录，参见 `./log.md`
> 快速查看: `grep "^## \[" ./log.md | tail -5`

---

## 如何使用此索引

### 主 Agent

1. 阅读此索引了解项目有哪些模块
2. 根据任务需求，指示子 Agent 加载特定模块摘要
3. 查询时先读索引定位相关模块，再深入读取

### 子 Agent

1. 根据任务提示加载指定的模块摘要（Layer 2）
2. 需要实现细节时，加载对应的详情文档（Layer 3）
3. 不要加载不相关的文档
4. 完成任务后按 project-compound skill 记录知识

---

## 相关文档

- [./log.md](./log.md) - 操作日志
