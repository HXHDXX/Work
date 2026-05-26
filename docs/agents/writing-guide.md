# 文档编写规范

> 本项目文档遵循渐进式披露原则，分三层管理。

## 通用规则

### 语言

- 技术文档：中英混合，中文为主，代码/命令/术语用英文
- commit message：英文，Conventional Commits 格式
- 知识库模块页：中文描述，英文代码

### 格式

- Markdown 格式
- 表格优先于列表（当数据有结构时）
- 代码块必须标注语言：`bash`, `cpp`, `cmake`
- 文件路径用行内代码格式：`./path/to/file`
- 相对路径以 `./` 开头

### 长度

| 层级 | 目标长度 | 说明 |
|------|---------|------|
| AGENTS.md 清单项 | 1 行 | 简明要点 |
| docs/agents/ 说明页 | 50-150 行 | 完整但不冗长 |
| knowledge/modules/ 模块页 | 50-100 行 | 经验摘要，非教程 |

## AGENTS.md（Layer 1）

### 写法

```markdown
### 小节标题
> 详细: `./docs/agents/xxx.md`
- 清单项（不超过 1 行）
- 清单项
```

### 规则

- 每项一行，不展开说明
- 说明通过 `> 详细:` 链接指向 Layer 2
- 不放代码示例、不放详细解释
- 新增小节必须创建对应的 Layer 2 文档

## docs/agents/ 说明页（Layer 2）

### 结构

```markdown
# 标题

> AGENTS.md「XXX」清单的详细说明。

## 背景（为什么需要这个规则）
## 详细规则
## 操作流程（如有）
## 注意事项（如有）
```

### 规则

- 标题说明本页是哪个清单项的展开
- 按需分段，不强制使用所有章节
- 代码示例可以有，但要精简
- 引用其他文档用相对路径

## knowledge/modules/ 模块页（Layer 3）

### 结构

遵循 `project-compound` skill 定义的模板：

```markdown
# {Module Name}

> Last updated: {YYYY-MM-DD}

## Overview
## Decisions
## Strategies
## Bug Experience
## Open Questions
```

### 规则

- 一个事实一个 bullet，不写段落
- 使用相对路径（`./` 前缀）
- 不用 emoji
- 日期格式 YYYY-MM-DD
- 新决策覆盖旧决策时，旧决策标注 `> **Superseded by:**`
- 每条记录必须追加入 `log.md`

## 知识库操作

详见 `project-compound` skill。三种操作：

| 操作 | 触发 | 产出 |
|------|------|------|
| ingest | 任务完成、决策做出 | 更新模块页 + log.md |
| query | 遇到不熟悉的模块 | 合成答案，有价值则归档 |
| lint | 定期或重大变更前 | 修复矛盾、孤儿页、缺口 |
