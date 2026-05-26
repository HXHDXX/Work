# AGENTS.md

> **意图驱动：AI 为剑，概念为刃，约束为柄**

## AGENTS.md 读写元规则
> 详细: `./docs/agents/index.md`
- 只写清单，不写说明
- 说明写在 `./docs/agents`
- 遵循渐进式披露

## 开发指南

### 核心原则
> 详细: `./docs/agents/core/principles.md`
- 中英双语思维链
- 先理解再行动
- 通过构建系统理解
- 交付结果必须有验证方案
- 遇到问题先检索 `./docs`

### 行为准则
> 详细: `./docs/agents/core/principles.md`
- 澄清意图再动手（需求有歧义就问，不假设）
- 深度调研（理解需求时，必须输出概念现状，明确并清理盲区）
- 简单优先（不写超出需求的代码，不过度抽象）
- 精准修改（只改必须改的，不附带重构）
- 验证先行（行动前，必须设计验收标准，提供可执行的验证方案）
- Trivial 豁免（≤ 1 文件且 ≤ 20 行直接执行）

### 上下文与沙盒策略 (Context-Mode)
> 详细: `./docs/agents/core/context-strategy.md`
- **默认粗筛**：优先使用 `ctx_search` / `ctx_execute_file`（98% 压缩率）
- **按需放行**：涉及内存安全、跨进程寻址、构建环境修改时，通过钩子请求原始数据
- **决策对焦**：关键决策点需询问用户: `基于摘要判断，还是查看原始数据?`
- **沙盒强制**：所有非交互式脚本、网络请求、大文件扫描必须路由至 `ctx_execute`
- **指令拦截**：禁用原生 `curl`, `find`, `grep`，由 MCP Hooks 强制重定向

### 项目目录结构
> 详细: `./docs/agents/core/structure.md`
- 新建/调整目录前必读
- 跨模块调用、引入第三方依赖前必读
- 提交代码前用于验证布局合规性必读

### 库
- 优先: C++ 标准库
- 开源库: 参考 `./cross-library-examples/`（可用库及使用方式）
- 私有库: `./libs/`（项目级私有库，按需创建）

### Worktree 规则
- 目录: `.worktrees/<分支名>`
- 分支命名: `feature/<功能名>` | `fix/<问题名>`
- 完成后清理 worktree，保证线性历史

### 验证
- 代码修改后必须通过构建验证
- **调试与检查统一命令：`./container/build.sh check`（默认 ASAN + clang-tidy）**
  - 禁止直接使用 `./container/build.sh linux` 或其他平台命令做验证
  - 如需其他模式显式声明：`./container/build.sh check Debug`（Valgrind）、`./container/build.sh check ASAN`
- 所有警告必须修复
- 关键重构需在 `ctx_execute` 沙盒中通过单元测试验证

### 知识查询与沉淀
> 详细: `./docs/agents/knowledge/knowledge-index.md`
- 操作前先加载 `project-compound` skill（提供 ingest/query/lint 三种操作模板）
- 开始模块任务前，先查 `./docs/agents/knowledge/` 了解已有经验
- 功能迭代后通过 project-compound ingest 更新知识库
- 任务完成后记录决策、策略、bug 经验（非 trivial 变更必须归档）
