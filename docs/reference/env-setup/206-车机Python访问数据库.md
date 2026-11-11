# 206 车机 Python 访问数据库指南

> 适用：已按 `206/dm8/INSTALL.md` 完成 DM8 + dmPython + 四依赖部署的 206 车机（飞腾 ARM64 / 麒麟 V10 SP1）。
> 读者：在车机上开发/部署 Python 业务程序（PHM）的工程师。事实依据：`206/dm8/INSTALL.md`（部署实录）。

## 1. 环境形态

| 项 | 值 |
|---|---|
| 数据库 | DM8，`dmdba` 用户运行，systemd 服务 `DmServiceDMSERVER` 管理 |
| 监听 | `127.0.0.1:5236`（仅本机 TCP） |
| 库 / 实例 | DAMENG / DMSERVER |
| Python | 3.12.2（客户基准，`/usr/local/bin/python3.12`） |
| venv 建议路径 | `/home/kylin/venvs/phm` |
| 业务运行账号 | `kylin` |
| 四包 | numpy / pandas / statsmodels / openpyxl（wheelhouse 离线装） |

分工边界：`kylin` 只通过 TCP 访问数据库，**不直接读写 `/dm8` 下任何文件，也不加入 `dinstall` 组**——DM8 文件属 `dmdba:dinstall`，业务侧仅需网络可达。

## 2. 前提检查

```bash
systemctl is-active DmServiceDMSERVER     # 期望 active
ss -ltn | grep 5236                       # 期望 LISTEN 127.0.0.1:5236
source /home/kylin/venvs/phm/bin/activate
pip check                                 # 期望 No broken requirements found.
```

## 3. dmPython 连接

dmPython 经 DPI 走 TCP，运行库已在安装期注册进 `/etc/ld.so.conf.d/dm8.conf`，**无需设置 `LD_LIBRARY_PATH`**：

```python
import dmPython

conn = dmPython.connect(
    user="PHMAPP",         # 独立业务账号，禁止业务直连 SYSDBA
    password="********",   # 占位符：真实密码只放 dm.ini，勿写入代码
    server="127.0.0.1", port=5236)
```

## 4. 连接配置文件

`/home/kylin/.config/phm/dm.ini`（创建后 `chmod 600`，属主 kylin）：

```ini
[dm]
user = PHMAPP
password = ********
server = 127.0.0.1
port = 5236
```

读取示例：

```python
from configparser import ConfigParser
import dmPython

cp = ConfigParser()
cp.read("/home/kylin/.config/phm/dm.ini")
sec = cp["dm"]
conn = dmPython.connect(user=sec["user"], password=sec["password"],
                        server=sec["server"], port=sec.getint("port"))
```

## 5. 查询并转 DataFrame

dmPython 无 SQLAlchemy dialect，**不要用 `pandas.read_sql` 直接驱动 dmPython**；统一 `cursor.execute` + `fetchall` 后手工建 DataFrame：

```python
import pandas as pd

cur = conn.cursor()
cur.execute("SELECT ts, load, vibration FROM phm_readings WHERE device = ?", ("DEV01",))
df = pd.DataFrame(cur.fetchall(), columns=[d[0] for d in cur.description])
cur.close()
```

## 6. 四包引用与组合示例

```python
import numpy as np
import pandas as pd
import statsmodels.api as sm
import openpyxl   # to_excel 的写入引擎
```

接第 5 节的 `df`，做 OLS 统计并导出 Excel：

```python
X = sm.add_constant(df["load"].to_numpy())
model = sm.OLS(df["vibration"].to_numpy(), X).fit()

out = pd.DataFrame({"coef": model.params, "pval": model.pvalues})
out.to_excel("/home/kylin/phm-report/ols.xlsx", engine="openpyxl")
```

## 7. systemd 服务化

业务程序做成服务运行，**不依赖 `.bashrc` 与 `LD_LIBRARY_PATH`**——全部用绝对路径：

```ini
# /etc/systemd/system/phm-app.service
[Unit]
After=network.target DmServiceDMSERVER.service

[Service]
User=kylin
ExecStart=/home/kylin/venvs/phm/bin/python /home/kylin/phm-app/main.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

启用：`sudo systemctl enable --now phm-app.service`。

## 8. 一次性验收（干净环境）

`env -i` 剥掉一切环境变量，验证连接与四包 import 均不依赖 shell 环境：

```bash
env -i /home/kylin/venvs/phm/bin/python - <<'PY'
import dmPython
conn = dmPython.connect(user="PHMAPP", password="********",
                        server="127.0.0.1", port=5236)
conn.close()
print("DB_OK")
import numpy, pandas, statsmodels, openpyxl
print("PY_DEPS_OK")
PY
/home/kylin/venvs/phm/bin/pip check
```

期望输出含 `DB_OK`、`PY_DEPS_OK`，且 `pip check` 无告警。

## 9. 常见问题

| 症状 | 原因 | 处置 |
|---|---|---|
| `No module named dmPython` | 用了系统 Python 而非 venv | 一律用 `/home/kylin/venvs/phm/bin/python`；缺包则重装 `wheels/dmpython-*.whl` |
| 连接报错 `-70089` | dmPython 依赖的 crypto 库缺失 | 重跑 `install_dm8_qt.sh`（安装期拷 crypto 库已修复，幂等） |
| `import ssl` / `_ssl` 失败 | python3.12 编译期缺 libssl-dev | 按 `206/dm8/INSTALL.md` §五重跑脚本阶段 8c 重编 |
| 连接超时/拒绝 | `DmServiceDMSERVER` 未起或 5236 未监听 | `systemctl status DmServiceDMSERVER`；`ss -ltn \| grep 5236` |
| `pandas.read_sql` 报错 | dmPython 无 SQLAlchemy dialect | 改 `cursor.execute` + `fetchall` 转 DataFrame（第 5 节） |

## 10. 权限与安全边界

| 边界 | 约定 |
|---|---|
| 账号分工 | `dmdba` 只管数据库本体；`kylin` 只做 TCP 客户端，不碰 `/dm8` 文件、不入 `dinstall` 组 |
| 业务账号 | 业务程序连 `PHMAPP` 等独立账号，禁止用 SYSDBA |
| 配置文件 | `/home/kylin/.config/phm/dm.ini` 权限 600，属主 kylin |
| 密码管理 | 密码只存 dm.ini，不写入代码、不进 git 仓库 |
