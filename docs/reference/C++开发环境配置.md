### C++ 开发环境配置

##### 操作系统

Ubuntu 24.04

建议采用最小安装

##### 配置开发环境

```shell
sudo apt update
sudo apt install -y \
	build-essential clangd pkg-config \
	cmake ninja-build lcov \
	git git-lfs repo \
	gdb valgrind \
	jq miller ripgrep fd-find btop entr \
	libgl1-mesa-dev libglu1-mesa-dev \
	'^libxcb.*-dev' libxcb-xinerama0 libx11-xcb-dev \
	libxkbcommon-dev libxkbcommon-x11-dev \
	libxi-dev libxrender-dev \
	filezilla imagemagick lua5.1 luarocks
sudo luarocks install luacheck

# Node.js 24（与当前开发机一致，npm 随 NodeSource nodejs 提供）
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g @ast-grep/cli

# Compose V1 供现有 HXAppPlatform 脚本使用；V2 用于逐项目迁移验证
sudo apt install -y docker.io docker-compose docker-compose-v2 docker-clean
sudo gpasswd -a $USER docker

#以下为可选性能分析工具；HWE 内核按当前内核安装匹配版本
sudo apt install linux-tools-common linux-tools-$(uname -r)
```

**加入 docker 用户组后需注销并重新登录；Docker Compose V1/V2 可并存，现有脚本继续用 `docker-compose`，迁移验证用 `docker compose`**

###### 配置GCC 9（项目必需）

Ubuntu 24.04默认安装GCC 13；项目需兼容GCC 8构建的absl、sqlite_orm等库，必须切换到GCC 9

```shell
sudo apt install -y gcc-9 g++-9
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 90 \
            --slave /usr/bin/g++ g++ /usr/bin/g++-9 \
            --slave /usr/bin/gcc-ar gcc-ar /usr/bin/gcc-ar-9 \
            --slave /usr/bin/gcc-nm gcc-nm /usr/bin/gcc-nm-9 \
            --slave /usr/bin/gcc-ranlib gcc-ranlib /usr/bin/gcc-ranlib-9
sudo update-alternatives --install /usr/bin/cpp cpp /usr/bin/cpp-9 90
```

##### 安装CLion / QtCreator

联网机器使用CLion

```shell
sudo snap install clion --classic #CLion安装
```

内网机器使用QtCreator

QtCreater：https://download.qt.io/official_releases/qtcreator/latest/

##### 开发资源

###### 构建容器

code-compiler

```shell
cd code-compiler && ./load.sh
```

###### 跨平台Qt SDK

cross-library.tar

```shell
sudo tar -xf cross-library.tar -C /
```

###### 跨平台开源库

qt5-x86_64-gl.tar

```shell
sudo tar -xf qt5-x86_64-gl.tar -C /
```

###### 跨平台项目

HXProjectTemplate - 共享库、插件开发

HXAppPlatform - Qt应用开发

同步HXAppPlatform版本库

```shell
export REPO_URL='ssh://git@192.168.1.100:2222/HXHDXX/git-repo.git'
mkdir HXAppPlatform && cd HXAppPlatform
repo init -u ssh://git@192.168.1.100:2222/HXHDXX/app-platform-manifest.git -b master
repo sync
repo start master --all
repo forall -c 'git lfs pull' # repo forall -p -j1 -c 'GIT_LFS_FORCE_PROGRESS=1 git lfs pull'
```

构建并运行Qt应用

```shell
cd HXAppPlatform/HXNativeApp
./container/build.sh linux-x86_64

# 地图数据存储在：<应用程序根目录>/data/map_data
# ftp上下载地图数据
mkdir ./hx-native-app-linux/x86_64/data
tar -xf algeria-mvt-data.tar -C ./hx-native-app-linux/x86_64/data
mv ./hx-native-app-linux/x86_64/data/algeria-mvt-data ./hx-native-app-linux/x86_64/data/map_data

(cd ./hx-native-app-linux/x86_64 && ./hx-native-app)
```

##### CLion使用构建容器配置

跨平台模块开发时，需要使用构建容器作为Toolchains：

###### 配置本地容器

Settings -> Build, Execution, Deployment -> Toolchains -> "+" Docker -> Image: linux_gcc_cl:v1.3

Settings -> Build, Execution, Deployment -> Toolchains -> "+" Docker -> Container Settings -> Volume bindings: 

| Host path          | Container path     | Read-only |
| ------------------ | ------------------ | --------- |
| /opt/cross-library | /opt/cross-library | &check;   |

###### CLion推荐插件

AceJump / IdeaVim / IdeaVimExtension / IdeaVim-EasyMotion

##### QtCreator15使用构建容器配置

参考：https://doc.qt.io/qtcreator/creator-adding-docker-devices.html

##### GammaRay分析Qt程序

1. lib-GammaRay

2. 临时授权Yama安全模块支持附加非子进程调试能力

   ```shell
   sudo sysctl -w kernel.yama.ptrace_scope=0
   ```

3. 执行

   ```shell
   HXAppPlatform/lib-GammaRay/x86_64/bin/gammaray
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

##### ASAN调试

基于HXAppPlatform、HXProjectTemplate开发项目时，将“Build type”改为ASAN，即可激活ASAN调试，或者直接使用./container/build.sh check构建

*ASAN问题*

*遗留构建环境注记：GCC-8/Linux 6.5下曾发现激活ASAN后程序启动随机崩溃，原因如下：*

https://github.com/google/sanitizers/issues/1716

*发生该问题，最简单、安全的做法是在系统启动后稍微减少地址空间随机化(ASLR)量：*

```shell
sudo sysctl vm.mmap_rnd_bits=30
```

*系统默认是32，改为30即可*

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
