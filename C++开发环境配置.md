### C++ 开发环境配置

##### 操作系统

Ubuntu 22.04

建议采用最小安装

##### 配置开发环境

```shell
sudo apt install -y \
	build-essential pkg-config \
	cmake ninja-build lcov \
	git repo \
	libgl1-mesa-dev libglu1-mesa-dev \
	'^libxcb.*-dev' libxcb-xinerama0 libx11-xcb-dev \
	libxkbcommon-dev libxkbcommon-x11-dev \
	libxi-dev libxrender-dev
sudo apt install -y docker.io docker-compose docker-clean
sudo gpasswd -a $USER docker
#以下为可选性能分析工具
sudo apt install linux-tools-common linux-tools-generic linux-tools-`uname -r`
sudo apt install valgrind
sudo snap install kcachegrind
```

**此步操作后需要重新启动电脑*

###### docker buildx跨平台安装配置说明（用于x86_64/arm64服务端容器构建）

安装docker buildx

```shell
sudo apt install docker-buildx
```

支持跨平台构建器

```shell
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

跨平台运行器

```shell
docker run --platform=linux/arm64 --rm arm64v8/ubuntu uname -m
```

###### 解决GCC 11兼容问题

Ubuntu 22.04默认安装GCC11，该版本对GCC8构建的absl、sqlite_orm等库可能存在不兼容问题，解决方案是使用GCC9替换GCC11

```shell
sudo apt install -y gcc-9 g++-9
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 90 \
            --slave /usr/bin/g++ g++ /usr/bin/g++-9 \
            --slave /usr/bin/gcc-ar gcc-ar /usr/bin/gcc-ar-9 \
            --slave /usr/bin/gcc-nm gcc-nm /usr/bin/gcc-nm-9 \
            --slave /usr/bin/gcc-ranlib gcc-ranlib /usr/bin/gcc-ranlib-9
sudo update-alternatives --install /usr/bin/cpp cpp /usr/bin/cpp-9 90
```

###### 解决连接CH340 GPS模块失败问题

1. 下载并安装最新CH340驱动：https://www.wch.cn/downloads/file/177.html?time=2024-04-21%2018:34:31&code=A75HCuwCkpdyZlnlyj15y8LLgHACtzvA1BpVW6FW

   ```shell
   cd CH341SER_LINUX/driver
   make
   sudo make install
   ```

2. 卸载brltty

   ```shell
   sudo apt remove brltty
   ```

3. 查看USB转串口设备

   ```shell
   lsusb
   ls /dev | grep USB
   ```

4. 安装串口工具

   ```shell
   sudo apt install cutecom
   ```

##### 安装CLion / QtCreator

联网机器使用CLion

```shell
sudo snap install clion --classic #CLion安装
```

内网机器使用QtCreator

QtCreater：https://download.qt.io/official_releases/qtcreator/latest/

##### 安装Makrdown编辑器

```shell
sudo snap install typora #收费
#或
sudo snap install typora-alanzanattadev #免费
```

##### 开发资源

###### 跨平台项目

HXAppPlatform - Qt应用开发

HXProjectTemplate - 共享库、插件开发

###### 构建容器

code-compiler

###### 跨平台Qt SDK

cross-library.tar - /opt/cross-library/

###### 跨平台开源库

qt5-x86_64-gl.tar.gz - /opt/qt5-x86_64-gl

##### CLion使用构建容器配置

跨平台模块开发时，需要使用构建容器作为Toolchains：

###### 配置本地容器

1. 下载跨平台第三方库：/opt/cross-library

   ```shell
   sudo tar -xf cross-library.tar -C /
   ```

2. 加载构建容器

   ```shell
   cd code-compiler && ./load.sh
   ```

3. 设定构建容器

   Settings -> Build, Execution, Deployment -> Toolchains -> "+" Docker -> Image: linux_gcc_cl:v1.3

   Settings -> Build, Execution, Deployment -> Toolchains -> "+" Docker -> Container Settings -> Volume bindings: 

   | Host path          | Container path     | Read-only |
   | ------------------ | ------------------ | --------- |
   | /opt/cross-library | /opt/cross-library | &check;   |

###### CLion推荐插件

AceJump / IdeaVim / IdeaVimExtension / IdeaVim-EasyMotion

##### QtCreator15使用构建容器配置

参考：https://doc.qt.io/qtcreator/creator-adding-docker-devices.html

##### 使用跨平台Qt SDK

Qt桌面应用开发时，可以使用系统默认编译链，同时使用跨平台Qt SDK：

1. 下载跨平台Qt SDK：/opt/qt5-x86_64-gl

   ```shell
   sudo tar -xf qt5-x86_64-gl.tar.gz -C /opt
   ```

2. 修改项目的 CMAKE_PREFIX_PATH 为跨平台 Qt SDK 的安装路径：/opt/qt5-x86_64-gl

##### GammaRay分析Qt程序

1. 下载GammaRay3.1.0(基于Qt5.15.12)：/opt/gammaray-3.1.0

2. 临时授权Yama安全模块支持附加非子进程调试能力

   ```shell
   sudo sysctl -w kernel.yama.ptrace_scope=0
   ```

3. 执行

   ```shell
   /opt/gammaray-3.1.0/bin/gammaray
   ```

##### Git分支合并流程

假定基于feature分支开发完毕

```shell
# 1. 确保本地 master 是最新的
git fetch origin master:master

# 2. feature分支变基到master分支，保证提交信息串行化
git checkout feature
git rebase master

# 3. 强制采用fast-forward方式合并分支，保证提交信息串行化
git checkout master
git merge feature --ff-only
```

*Git教程：https://learngitbranching.js.org/?locale=zh_CN*

##### 使用Meld解决代码冲突

1. 安装Meld并配置为Git默认处理冲突的工具

   ```        shell
   sudo apt install meld
   git config --global merge.tool meld
   ```

2. 使用Meld解决冲突

   在执行 git merge 或 git rebase 命令后，Git 会标记出发生冲突的文件，为解决冲突执行以下命令

   ```        shell
   git mergetool
   ```

   解决完所有冲突后，保存您的更改，并关闭 Meld，Git 会自动标记这些文件的冲突为已解决。

##### Repo管理私有库

```shell
# 确保环境变量仍然设置
export REPO_URL='https://mirrors.tuna.tsinghua.edu.cn/git/git-repo'

# 进入工作目录（空目录或已清理的目录）
cd ~/workspace

# 重新初始化
repo init -u <MANIFEST_GIT_URL> -m <manifest.xml> -b <commit-sha>
```

##### ASAN调试

基于HXAppPlatform、HXProjectTemplate开发项目时，将“Build type”改为ASAN，即可激活ASAN调试，或者直接使用./container/build.sh check构建

*ASAN问题*

*在GCC-8\Linux6.5情况下，发现激活ASAN后程序启动会随机崩溃，原因如下：*

https://github.com/google/sanitizers/issues/1716

*发生该问题，最简单、安全的做法是在系统启动后稍微减少地址空间随机化(ASLR)量：*

```shell
sudo sysctl vm.mmap_rnd_bits=30
```

*系统默认是32，改为30即可*

##### OpenCode

HXAppPlatform、HXProjectTemplate均已经使用AGENTS.md支持OpenCode开发

###### OpenCode 安装

```shell
curl -fsSL https://opencode.ai/install | bash
```

###### oh-my-opencode插件安装

```shell
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install nodejs -y
npm i -g bun --registry https://registry.npmmirror.com
bunx oh-my-openagent install
```

###### 配置OpenCode

```shell
/connect 连接购买的模型服务
/models 选择使用的模型

#查看OpenCode支持的模型
opencode models

#修改omo使用的模型
vim ~/.config/opencode/oh-my-openagent.json #建议使用GLM5.1作为Sisyphus使用的LLM
```

###### 安装Superpowers Skill

在OpenCode中输入

```shell
Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.opencode/INSTALL.md
```

###### 融合OMO和Superpowers

在OpenCode中输入

```shell
根据每个 agent 的职责，在 ~/.config/opencode/oh-my-openagent.json 中为其配置合适的 superpowers skills
```

```shell
列出当前所有 Skill，请为每个 Skill 添加中文描述(description)
```

###### 改进Agent环境、学习Agent协作

```shell
https://github.com/forrestchang/andrej-karpathy-skills
https://github.com/shanraisshan/claude-code-best-practice
```

##### 代码静态分析

```shell
./container/build.sh check 2>&1 | tee log.txt
```

##### 应用调试分析

###### 使用gdb分析Core Dump

1. 允许生成core dump文件

   ```shell
   ulimit -c unlimited #设置core dump文件大小为无限制
   sudo sysctl -w kernel.core_pattern=/var/crash/core.%e.%p #设置core dump文件保存路径
   ```

2. 运行程序产生崩溃

3. 使用gdb分析core dump

   ```shell
   gdb /path/to/my_program /path/to/core
   ```

   查看调用栈

   ```shell
   (gdb) bt
   ```

   查看变量

   ```shell
   (gdb) info locals
   ```

   查看变量值

   ```shell
   (gdb) print variable_name
   ```

   查看线程

   ```shell
   (gdb) info threads
   ```

   切换线程

   ```shell
   (gdb) thread thread_number
   ```

   查看源码

   ```shell
   (gdb) list
   ```

###### 采用valgrind对应用进行分析

安装分析工具

```shell
sudo apt install valgrind kcachegrind
```

分析应用性能

```shell
valgrind --tool=callgrind ./demo --license=./license.dat --navi_data=./navi_data --plugins=./libs/plugins --breakpad=./apps/crash_log --rw_data=./apps
```

使用KCachegrind可视化分析结果

```shell
kcachegrind callgrind.out.<pid>
```

分析内存问题

```shell
valgrind --tool=memcheck --log-file=log ./demo --license=./license.dat --navi_data=./navi_data --plugins=./libs/plugins --breakpad=./apps/crash_log --rw_data=./apps
```

分析应用多线程竞态

```shell
valgrind --tool=helgrind --log-file=log ./demo --license=./license.dat --navi_data=./navi_data --plugins=./libs/plugins --breakpad=./apps/crash_log --rw_data=./apps
```

分析应用堆栈使用情况

```shell
valgrind --tool=massif --log-file=log ./demo --license=./license.dat --navi_data=./navi_data --plugins=./libs/plugins --breakpad=./apps/crash_log --rw_data=./apps
```

