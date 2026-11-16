# 奇安信浏览器 Swagger UI 白屏修复记录

> 日期：2026-11-16 ｜ 设备：kylin@192.168.1.20（银河麒麟 aarch64）｜ 项目：`/home/kylin/bushu/backend-bushu`（FastAPI 0.162.5 + pydantic 2.14.3）

## 问题现象

| 现象 | 环境 |
|---|---|
| 本地浏览器经 SSH 隧道访问 `127.0.0.1:8000/docs` 正常 | 本地现代 Chromium |
| 设备端奇安信可信浏览器打开 `127.0.0.1:8000/docs` 白屏 | 奇安信浏览器 1.0.42005.2 |
| curl 与无头模式均能取回 HTML（200），网络层无问题 | 设备端 |

## 根因链（证据）

1. 控制台报 `Uncaught TypeError: Object.hasOwn is not a function`（swagger-ui-bundle.js 第 2 行）——运行时错误而非 SyntaxError，说明 v5 bundle 语法层可解析
2. 运行时特性探测定位内核版本：有 `replaceAll`/`??=`/`?.`（85 特性），缺 `Object.hasOwn`(93)/`Array.at`(92) → **内核为 Chromium 85~91**
3. 注意：奇安信浏览器 UA 与二进制 strings 里的版本号均伪装（`HeadlessChrome/1.0.42005.2`、`Chrome/96`），**只有运行时特性探测可信**
4. swagger-ui v5 依赖 `Object.hasOwn` 等新 API → JS 崩溃 → Swagger UI 不渲染 → 白屏

## 方案取舍

| 方案 | 结果 | 原因 |
|---|---|---|
| 换 swagger-ui v4.19.1 旧版资源 | ❌ 已回滚 | v4 不支持 OpenAPI 3.1（本地实测报 "Unable to render this definition"）；项目 openapi.json 为 3.1.0 |
| 降级 `openapi_version="3.0.2"` | ❌ 放弃 | FastAPI 0.162.5 已移除该构造参数；且 `get_openapi` 只改版本号不做 schema 转换，Optional 字段仍输出 3.1 风格 `anyOf`，v4 仍认不出 |
| **保留 v5 + `/docs` 注入运行时垫片** | ✅ 采用 | 内核只缺 2 个 API，polyfill 3 行即可；不动 OpenAPI 版本、不动静态资源 |

## 最终改动

仅改 `main.py` 一处（设备 `/home/kylin/bushu/backend-bushu/main.py`）：

```python
from fastapi.responses import HTMLResponse

# 奇安信浏览器内核(Chromium 85~91)缺 Object.hasOwn/Array.at，v5 swagger-ui 运行时崩溃，注入垫片
_LEGACY_SHIM = (
    "<script>"
    "Object.hasOwn=Object.hasOwn||function(o,p){return Object.prototype.hasOwnProperty.call(o,p)};"
    "if(!Array.prototype.at){Array.prototype.at=function(i){i=Math.trunc(i)||0;"
    "if(i<0)i+=this.length;return i>=0&&i<this.length?this[i]:void 0};"
    "String.prototype.at=Array.prototype.at;}"
    "</script>"
)

@app.get("/docs", include_in_schema=False)
async def custom_swagger_ui_html():
    html = get_swagger_ui_html(
        openapi_url=app.openapi_url,
        title=app.title + " - Swagger UI",
        swagger_js_url="/static/swagger-ui-bundle.js",
        swagger_css_url="/static/swagger-ui.css",
    )
    return HTMLResponse(html.body.decode().replace("<head>", "<head>" + _LEGACY_SHIM))
```

## 验证结果

| 验收项 | 结果 |
|---|---|
| 设备端 headless 奇安信引擎加载 /docs | 无 JS 报错，v5 UI 异步渲染节点出现（information-container/opblock） |
| 本地 playwright 加载 localhost:8000/docs | 全量端点列表正常渲染（OAS 3.1 标识正确） |
| curl /openapi.json | 仍为 3.1.0，未降级 |

## 设备侧残留状态

| 项 | 说明 |
|---|---|
| 服务进程 | nohup 启动（日志 `/tmp/bushu-backend.log`）；回 PyCharm 终端跑需先 `pkill -f "python3.12 main.py"` |
| 回滚件 | `main.py.bak`（改前原件）；`static/backup-v5/`（v5 静态资源原件） |
| 本地隧道 | `ssh -f -N -L 8000:127.0.0.1:8000 kylin@192.168.1.20`，关闭：`pkill -f "ssh -f -N -L 8000"` |

## 经验沉淀

- 奇安信浏览器版本号全面伪装，判定内核只能靠运行时特性探测（`typeof Object.hasOwn` 等逐版本标记法）
- FastAPI 0.162.5：`FastAPI()` 已无 `openapi_version` 参数；`get_openapi(openapi_version=)` 仅改版本号、不做 3.1→3.0 schema 转换
- 无头 `--dump-dom` 复现 + data: URL 特性探测是国产浏览器排障的两把快刀，全程无需 GUI
- 静态文件替换后 StaticFiles 直接生效无需重启；但改 main.py 必须重启，浏览器缓存可能干扰验证（换全新 `--user-data-dir`）
