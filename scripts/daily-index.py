#!/usr/bin/env python3
"""生成 daily/INDEX.md：日报主题索引 + 时间线索引。

用法: python3 scripts/daily-index.py
输入: daily/日报-*.txt（新旧两种格式）
输出: daily/INDEX.md（覆盖生成）
"""
import re
from pathlib import Path

DAILY = Path(__file__).resolve().parent.parent / "daily"

# 主题 -> 关键词（命中任一即归入；一条工作线可多主题）
THEMES = {
    "导航引导（HXNavigation/HXGuidance）": ["导航", "HXGuidance", "HXNavigation", "引导", "选路", "路线", "RouteOverview"],
    "地图渲染（maplibre/HXMapWidget）": ["地图", "渲染", "maplibre", "HXMapWidget", "相机", "图层", "DMA-BUF", "纹理", "离屏", "镜像"],
    "RDSS/短报文": ["RDSS", "Rdss", "短报文", "北斗", "GBQ", "EPQ", "OFQ", "TBQ", "ICR", "ICG", "FKI", "RMO"],
    "NMEA 协议": ["NMEA", "Nmea"],
    "数据编译（OSM/GJB）": ["OSM", "GJB", "POI", "电子导航图", "Shapefile"],
    "空间测量（HXSpatialMeasure）": ["HXSpatialMeasure", "空间测量"],
    "路由/GIS 服务": ["HXRouteServer", "HXGISServer", "路由"],
    "TitanNavi": ["TitanNavi", "titan 分支", "Titan"],
    "测试与质量基建": ["测试", "sanitizer", "ASAN", "hw-suite", "静态检查", "check 构建", "LSan"],
    "插件体系与发布": ["插件", "Plugin", "发布", "二进制"],
    "工程基建与知识沉淀": ["agent", "知识", "经验记忆", "文档", "构建", "基建", "架构", "AGENTS"],
}

SEC_NEW = re.compile(r"^[一二三四五六七八九十]+、(.+?)(?:（[^）]*）)?$")
SEC_OLD = re.compile(r"^\d+\.\s*(.+?)(?:（\d+ commits?）)?$")


def work_lines(path: Path) -> list[str]:
    lines = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        raw = raw.strip()
        m = SEC_NEW.match(raw) or SEC_OLD.match(raw)
        if m:
            lines.append(m.group(1).strip())
    return lines


def main() -> None:
    entries = []  # (date, [work lines])
    for f in sorted(DAILY.glob("日报-*.txt")):
        date = f.stem.removeprefix("日报-")
        entries.append((date, work_lines(f)))

    # 主题 -> [(date, work line)]
    theme_map: dict[str, list[tuple[str, str]]] = {t: [] for t in THEMES}
    for date, lines in entries:
        for line in lines:
            for theme, kws in THEMES.items():
                if any(kw in line for kw in kws):
                    theme_map[theme].append((date, line))

    out = ["# 日报索引", "",
           f"> 自动生成：`python3 scripts/daily-index.py`（覆盖本文件）。共 {len(entries)} 篇，{entries[0][0]} ~ {entries[-1][0]}。",
           "", "## 主题索引（按工作线关联各日）", ""]
    for theme, items in theme_map.items():
        if not items:
            continue
        dates = sorted({d for d, _ in items})
        out.append(f"### {theme}（{len(dates)} 天）")
        out.append("日期：" + "、".join(dates))
        out.append("")
    out += ["## 时间线索引", ""]
    cur_month = ""
    for date, lines in entries:
        month = date[:7]
        if month != cur_month:
            cur_month = month
            out += ["", f"### {month}", ""]
        body = "；".join(lines) if lines else "（旧格式无工作线标题，见原文）"
        out.append(f"- [{date}](日报-{date}.txt)：{body}")
    out.append("")

    (DAILY / "INDEX.md").write_text("\n".join(out), encoding="utf-8")
    print(f"INDEX.md written: {len(entries)} reports, {sum(1 for v in theme_map.values() if v)} themes")


if __name__ == "__main__":
    main()
