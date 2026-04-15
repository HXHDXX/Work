1. OSM pbf 实时渲染服务开发初版：windows\android -- 完成一版，后期优化!
2. 建立跨平台 Qt 应用开发环境 - 完成!
3. 编译 osm 数据到 mvt - 完成!
4. 引入封装 native 地图引擎 - 初步完成！独立进程方案，今后逐步封装地图指令和状态
5. 建立 demo 应用，显示矢量瓦片数据 - 完成！
6. 建立跨平台插件运行时：HXPluginRuntime - 暂停，目标改为先在3588设备上运行测试地图$
7. 在HXPluginRuntime基础上引入跨平台gis server - 暂停，目标改为先在3588设备上运行测试地图$
8. 单独引入跨平台gis server - 先在3588设备上运行测试地图，实施中*
9. 集成地图控件与gis server，实现离线地图渲染测试程序，计划中？


待改进
1. ZMQClient代码通过AI检测一边，尤其是stop的作用，是否是线程安全
2. 写demo测试lib-plugin-HXGISServer
3. 打包arm64和arm64-v8a,统一目录
4. HXMapWidgetLite改名HXMapWidgetNative
5. HXNativeApp/HXCEFApp引入Template的更新cross-library、打包能力和新skill
6. HXNativeApp关联HXMapWidgetNative
7. HXPluginRuntime引入Template的更新cross-library、打包能力和新skill
8. 引入HXPluginRuntime的情况下，实现HXMapWidgetNative的消息总线

9. agents.md 引入:https://github.com/forrestchang/andrej-karpathy-skills

HXNativeApp/HXCefApp/HXMapWidgetCef

