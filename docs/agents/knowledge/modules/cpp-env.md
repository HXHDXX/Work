# C++ Dev Environment

> Last updated: 2026-04-10

## Overview
- C++ 开发环境完整配置指南（Ubuntu 22.04）
- Key files: `./C++开发环境配置.md`
- IDE: CLion（联网）/ QtCreator（内网，latest 版本）
- 构建容器: `code-compiler` (Docker, `linux_gcc_cl:v1.3`)
- 跨平台 Qt SDK: `/opt/qt5-x86_64-gl`
- 跨平台第三方库: `/opt/cross-library/`
- See also: [[infra]]

## Decisions

### GCC9 替代 GCC11 解决兼容问题 (2026-04-08)
- **Chosen:** 使用 `update-alternatives` 将 GCC9 设为默认，优先级 90
- **Alternatives:** 容器内编译 / 升级依赖库
- **Reason:** Ubuntu 22.04 默认 GCC11 与 GCC8 构建的 absl、sqlite_orm 等库 ABI 不兼容
- **Tradeoff:** 全局降级编译器版本，新项目无法使用 GCC11 特性

### Docker buildx 跨平台构建 (2026-04-08)
- **Chosen:** 使用 `multiarch/qemu-user-static` 实现 x86_64/arm64 交叉构建
- **Alternatives:** 原生 arm64 构建机 / 交叉编译工具链
- **Reason:** 在 x86_64 开发机上构建 arm64 服务端容器，无需额外硬件
- **Tradeoff:** QEMU 模拟性能较低，仅适合 CI/CD 构建，不适合日常编译

### ASAN 调试 + ASLR 调整 (2026-04-08)
- **Chosen:** 使用 CMake ASAN build type + `vm.mmap_rnd_bits=30`
- **Alternatives:** 完全禁用 ASLR / 不使用 ASAN
- **Reason:** GCC-8 + Linux 6.5 下 ASAN 启动随机崩溃（google/sanitizers#1716），降低 ASLR 位数可规避
- **Tradeoff:** 略微降低系统安全防护等级

## Strategies

### CLion Docker Toolchain 配置 (2026-04-08)
- **Problem:** 跨平台模块需要在不同编译环境中构建
- **Approach:** Docker image 作为 CLion Toolchain，Volume binding 挂载 `/opt/cross-library`
- **When to reuse:** 任何需要容器化编译环境的 C++ 项目

### Qt 应用调试分析工具链 (2026-04-08)
- **Problem:** Qt 应用需要运行时检查（内存泄漏、竞态、性能热点）
- **Approach:** valgrind 四工具（memcheck/helgrind/callgrind/massif）+ KCachegrind 可视化 + GammaRay Qt 对象检查
- **When to reuse:** 任何 Qt/C++ 应用的性能与内存分析

### Core Dump 分析流程 (2026-04-08)
- **Problem:** 崩溃后需要定位问题
- **Approach:** `ulimit -c unlimited` + `kernel.core_pattern` 配置 + gdb 分析 core dump
- **When to reuse:** 任何 C++ 应用的崩溃调试

### Git 分支合并采用 rebase + ff-only (2026-04-08)
- **Problem:** 保持提交历史线性、干净
- **Approach:** feature 分支 rebase 到 master，再用 `--ff-only` 合并
- **When to reuse:** 项目标准分支合并流程

## Bug Experience

### CH340 GPS 模块连接失败 (2026-04-08)
- **Symptom:** USB 转串口设备无法识别
- **Root cause:** brltty 服务占用串口设备 + 旧版 CH340 驱动不兼容
- **Fix:** 安装最新 CH340 驱动 + 卸载 brltty + 使用 cutecom 验证
- **Prevention:** 配置开发环境时优先处理 brltty 冲突

## Module Info

### 项目资源清单
- HXAppPlatform — Qt 应用开发框架
- HXProjectTemplate — 共享库、插件开发模板
- code-compiler — Docker 构建容器镜像
- cross-library.tar — 跨平台第三方库（`/opt/cross-library/`）
- qt5-x86_64-gl.tar.gz — 跨平台 Qt SDK（`/opt/qt5-x86_64-gl`）
- gammaray-3.1.0 — Qt 运行时分析工具（`/opt/gammaray-3.1.0/`）

### IDE 配置
- CLion: snap 安装，推荐插件 AceJump / IdeaVim / IdeaVimExtension / IdeaVim-EasyMotion
- QtCreator: 离线安装包（latest），支持 Docker 设备
- Markdown: typora（收费）或 typora-alanzanattadev（免费）

### 静态分析
- `./container/build.sh check` 执行代码静态分析

## Open Questions
- 构建容器 `linux_gcc_cl` 的 Dockerfile 是否需要纳入版本管理？
- GammaRay 3.1.0 基于 Qt5.15.12，Qt6 项目是否有对应版本？
