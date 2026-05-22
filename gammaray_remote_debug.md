## Agent 远程调试 Qt 程序方案

---

### 步骤 1：启动远程程序

```bash
ssh target "
    export DISPLAY=:0
    nohup gammaray --listen 0.0.0.0:11732 ./test \
        > /tmp/app.log 2>&1 &
    echo \$!
"
```

记录输出 PID。

---

### 步骤 2：建立 SSH 隧道

```bash
ssh -N -L 11732:localhost:11732 target &
```

---

### 步骤 3：本地 GammaRay GUI 连接

```bash
gammaray --connect localhost:11732
```

---

### 步骤 4：实时读取远程日志

```bash
ssh target "tail -f /tmp/app.log"
```

---

### 步骤 5：自动化控制

**修改对象属性**：

```bash
gammaray-cli --connect localhost:11732 --script "
    var obj = findObject('MainWindow');
    obj.setProperty('windowTitle', 'Agent Controlled');
"
```

**发射信号**：

```bash
gammaray-cli --connect localhost:11732 --script "
    var button = findObject('submitButton');
    button.clicked();
"
```

**输入文本**：

```bash
gammaray-cli --connect localhost:11732 --script "
    var input = findObject('lineEdit');
    input.setProperty('text', 'test data');
    input.editingFinished();
"
```

---

### 步骤 6：模拟用户操作（xdotool）

**查找窗口并点击**：

```bash
ssh target "
    export DISPLAY=:0
    WIN=\$(xdotool search --name 'Agent Controlled' | head -1)
    xdotool click --window \$WIN 1
"
```

**输入文本**：

```bash
ssh target "
    export DISPLAY=:0
    WIN=\$(xdotool search --name 'Agent Controlled' | head -1)
    xdotool type --window \$WIN 'hello'
"
```

**按键**：

```bash
ssh target "
    export DISPLAY=:0
    WIN=\$(xdotool search --name 'Agent Controlled' | head -1)
    xdotool key --window \$WIN Return
"
```

---

### 步骤 7：结束调试

```bash
# 停止隧道
kill %1

# 停止远程程序
ssh target "kill <PID>"
```

---

### 完整命令速查

| 操作 | 命令 |
|------|------|
| 启动程序 | `ssh target "export DISPLAY=:0 && nohup gammaray --listen 0.0.0.0:11732 ./test > /tmp/app.log 2>&1 & echo \$!"` |
| 建立隧道 | `ssh -N -L 11732:localhost:11732 target &` |
| GUI 连接 | `gammaray --connect localhost:11732` |
| 读日志 | `ssh target "tail -f /tmp/app.log"` |
| 改属性 | `gammaray-cli --connect localhost:11732 --script "findObject('X').setProperty('Y', 'Z');"` |
| 发信号 | `gammaray-cli --connect localhost:11732 --script "findObject('X').clicked();"` |
| 模拟点击 | `ssh target "export DISPLAY=:0 && WIN=\$(xdotool search --name 'X' | head -1) && xdotool click --window \$WIN 1"` |
| 模拟输入 | `ssh target "export DISPLAY=:0 && WIN=\$(xdotool search --name 'X' | head -1) && xdotool type --window \$WIN 'text'"` |
| 模拟按键 | `ssh target "export DISPLAY=:0 && WIN=\$(xdotool search --name 'X' | head -1) && xdotool key --window \$WIN Return"` |
| 停止程序 | `ssh target "kill <PID>"` |
