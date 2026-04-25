四-五月份的工作============================

0. 下载OSM全球0-9级PNG地图 - 完成!
1. 下载OSM阿尔及利亚10-14级PNG地图 - 实施中*
2. 优化全球底图的中国合规和10段线 - 完成!
3. 优化地图渲染效果 - 完成！
4. 处理地图构建警告 - 实施中*
5. 建立跨平台插件运行时：HXPluginRuntime - 计划中?
6. 建立Linux\麒麟插件运行时Shell：HXPluginShell - 计划中?
7. 在HXPluginShell基础上引入跨平台gis server - 计划中?

三-四月份的工作============================

0. 下载OSM全球0-9级PNG地图 - 实施中*
1. OSM pbf 实时渲染服务开发初版：windows\android - 完成一版，后期优化!
2. 建立跨平台 Qt 应用开发环境 - 完成!
3. 编译 osm 数据到 mvt - 完成!
4. 引入封装 native 地图引擎 - 初步完成！独立进程方案，今后逐步封装地图指令和状态
5. 建立 demo 应用，显示矢量瓦片数据 - 完成！
6. 建立跨平台插件运行时：HXPluginRuntime - 暂停，目标改为先在3588设备上运行测试地图$
7. 在HXPluginRuntime基础上引入跨平台gis server - 暂停，目标改为先在3588设备上运行测试地图$
8. 单独引入跨平台gis server - 先在3588设备上运行测试地图, 完成!
9. 集成地图控件与gis server，实现离线地图渲染测试程序，完成!
10. 在Linux下搭建Qt-Android开发环境 - 完成！
11. 基于Linux下Qt-Android开发环境，使用MapLibre-Native-Qt+HXGISServer开发离线地图显示Demo - 完成!
12. 实现全球底图和区域地图的数据结合 - 完成！


待改进
1. ZMQClient代码通过AI检测一边，尤其是stop的作用，是否是线程安全
2. HXNativeApp/HXCEFApp引入Template的更新cross-library、打包能力和新skill
3. HXNativeApp关联HXMapWidgetNative
4. HXPluginRuntime引入Template的更新cross-library、打包能力和新skill
5. 引入HXPluginRuntime的情况下，实现HXMapWidgetNative的消息总线
6. OSMDataCompiler 更新技能llmwiki\zhongwen, update doc, 总结构件打包的doc

HXNativeApp/HXCefApp/HXMapWidgetCef

