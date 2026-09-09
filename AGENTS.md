# AGENTS.md

## 上下文与沙盒策略 (Context-Mode)
> 详细: `./docs/agents/core/context-strategy.md`
- 默认粗筛: 优先使用 `ctx_batch_execute` / `ctx_search` / `ctx_execute_file`（98% 压缩率）
- 按需放行: 涉及内存安全、跨进程寻址、构建环境修改时，通过钩子请求原始数据
- 决策对焦: 关键决策点需询问用户: `基于摘要判断，还是查看原始数据?`
- 沙盒强制: 所有非交互式脚本、网络请求、大文件扫描必须路由至 `ctx_execute`
- 指令拦截: 禁用原生 `curl`, `find`, `grep`，由 MCP Hooks 强制重定向
- 沙盒断言: 关键重构必须在 `ctx_execute` 沙盒中通过单元测试验证
- 工具路由: `ctx_batch_execute`(采集+索引+搜索) → `ctx_search`(查索引) → `ctx_execute`/`ctx_execute_file`(处理) → 原生 `Edit`/`Read`(输出 <20 行)
<!-- 来源: https://github.com/mksglu/context-mode -->

## Trivial 豁免验证
- 本仓库无构建系统：Trivial 变更（≤1 文件且 ≤20 行）的验证以链接/引用验证替代全局 AGENTS.md 的构建验证
