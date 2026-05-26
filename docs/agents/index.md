# docs/agents/ 索引

> 本目录存放 AGENTS.md 清单的详细说明文档。

## 目录结构

```
docs/agents/
├── index.md              ← 本文件：文档索引与元规则
├── core/                 ← 核心规则
│   ├── principles.md     ← 原则与行为准则
│   ├── context-strategy.md ← 上下文与沙盒策略
│   └── structure.md      ← 项目目录结构规范
├── writing-guide.md      ← 文档编写规范
└── knowledge/            ← 知识库（project-compound 管理）
    ├── knowledge-index.md
    ├── log.md
    └── modules/
```

## 元规则

### 读写规则

1. **只写清单，不写说明** — AGENTS.md 是入口清单，说明性内容写在本目录下
2. **遵循渐进式披露** — 三层结构：
   - Layer 1: `AGENTS.md` — 清单入口（Agent 首先读取）
   - Layer 2: `docs/agents/*.md` — 分类详细说明（按需深入）
   - Layer 3: `docs/agents/knowledge/modules/*.md` — 具体经验记录（任务驱动）
3. **双向链接** — 每层通过 `> 详细:` 和 `See also` 相互引用

### 新增文档规则

- 新增分类说明 → 放在 `docs/agents/` 对应子目录
- 新增经验记录 → 通过 `project-compound` skill 的 ingest 操作写入 `knowledge/modules/`
- 新增全局主题 → 更新 `knowledge/knowledge-index.md` 的「全局主题」表

### 文档命名

- 小写 + 连字符: `context-strategy.md`
- 模块知识页: `{module-name}.md`（与 knowledge-index 中的模块名一致）
