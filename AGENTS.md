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
  - 静态：优先检索 `./docs`
  - 动态：通过构建系统理解
- 验证贯穿始终：前置设计验收标准，后置交付验证方案

### 行为准则
> 详细: `./docs/agents/core/principles.md`
- 澄清意图：需求存在歧义禁止假设，必须向用户提问
- 深度调研：编码前必须输出概念现状，清理技术盲区
- 简单优先：禁止编写超出当前需求的代码与过度抽象
- 精准修改：聚焦目标，禁止在非相关区域附带重构
- 验证先行：行动前必须设计并交付可执行的验收标准
- Trivial 豁免：单次变更 ≤ 1 文件且 ≤ 20 行允许直接执行，禁止通过连续拆分规避限制，且仍必须通过构建验证

### 上下文与沙盒策略 (Context-Mode)
> 详细: `./docs/agents/core/context-strategy.md`
- **默认粗筛**：优先使用 `ctx_batch_execute` / `ctx_search` / `ctx_execute_file`（98% 压缩率）
- **按需放行**：涉及内存安全、跨进程寻址、构建环境修改时，通过钩子请求原始数据
- **决策对焦**：关键决策点需询问用户: `基于摘要判断，还是查看原始数据?`
- **沙盒强制**：所有非交互式脚本、网络请求、大文件扫描必须路由至 `ctx_execute`
- **指令拦截**：禁用原生 `curl`, `find`, `grep`，由 MCP Hooks 强制重定向
- **沙盒断言**：关键重构必须在 `ctx_execute` 沙盒中通过单元测试验证
- **工具路由**：`ctx_batch_execute`(采集+索引+搜索) → `ctx_search`(查索引) → `ctx_execute`/`ctx_execute_file`(处理) → 原生 `Edit`/`Read`(输出 <20 行)
<!-- 来源: https://github.com/mksglu/context-mode -->

### 项目目录结构
> 详细: `./docs/agents/core/structure.md`
- 新建或调整目录结构前必读
- 跨模块调用与引入第三方依赖前必读
- 提交代码前合规性布局验证必读

### 依赖库使用优先级
- 第一优先级: C++ 标准库 (严格限定 C++17 标准)
- 开源库参考: `/opt/cross-library/`（跨平台第三方库）
- 项目私有库: 按模块 CMake 结构组织

### Git Worktree 线性历史铁律
- 零容忍政策：所有修改必须在独立 Worktree 中进行
- 目录规范：`.worktrees/<分支名>`
- 分支命名：`feature/<功能名>` | `fix/<问题名>`
- 线性历史：严格采用 Rebase 与 `--ff-only` 合并，禁止产生 Merge Commit
- 交付清理：任务完成后必须彻底清理对应的 Worktree 目录

### 编译与验证机制
- 编译合规：所有代码修改后必须通过构建验证，修复所有 Warning
- 统一调试检查命令：`./container/build.sh check`（默认激活 ASAN + clang-tidy，脚本待重建）
- 禁止直接调用：禁止直接使用平台原生命令（如 `./container/build.sh linux`）验证
- 显式模式声明：如需其他模式，必须显式声明如 `check Debug`、`check ASAN`
- 构建脚本位置：具体命令随项目构建系统确定，当前 `./container/build.sh` 尚未重建，编译验证命令待业务代码结构确定后补充

### 知识查询与沉淀
> 详细: `./docs/agents/knowledge/knowledge-index.md`
- 操作前必须加载 `project-compound` skill（提供 ingest/query/lint 模板）
- 开始模块任务前，先检索 `./docs/agents/knowledge/` 继承已有经验
- 功能迭代后，必须在清理 Worktree 前通过 `project-compound ingest` 更新知识库
- 任务完成后，必须在当前分支生命周期内归档记录核心决策、技术策略与 Bug 经验（非 trivial 变更必选）
<!-- 来源: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f -->
