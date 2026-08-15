# 🐳 DSH 自动启动器（DSH Launcher）

一个 Windows 小工具：**双击一下，自动找到并打开 DSH（DeepSeek Harness）的网页界面**，全程不需要手动输入地址、不需要看命令行窗口。

---

## 它是做什么的？

它会自动完成 3 件事：

1. **检查 DSH 是否在运行** —— 自动检测地址（默认 `http://localhost:3080/`，可自定义）
2. **自动挑选浏览器** —— 优先用夸克浏览器；**没装夸克也没关系，会自动改用你电脑的默认浏览器**（Chrome / Edge / Firefox 等都可以）
3. **打开 DSH 界面** —— 浏览器自动弹出 DSH 页面

全程**没有任何黑色窗口**，安静完成。

---

## 你需要准备什么？

| 条件 | 说明 |
|---|---|
| Windows 10 或 11 | 必须 |
| DSH 已经装好并正在运行 | 本工具是"打开 DSH"，不是"安装 DSH"。请先确保 DSH 服务已启动（浏览器手动访问 `http://localhost:3080/` 能看到界面） |
| 浏览器（任意） | 夸克、Chrome、Edge、Firefox……都行，没有夸克会自动用默认浏览器 |

---

## 安装步骤（3 步搞定）

1. **把整个文件夹复制到你的电脑**（放哪都行，比如 `D:\` 或桌面）
2. **双击 `启动DSH.vbs`**（无窗口，推荐）
3. 完成！浏览器自动打开 DSH 界面，不需要任何其他操作

> 💡 小提示：如果从微信/QQ 下载的文件夹被 Windows 拦截（提示"已阻止运行"），右键文件 → 属性 → 勾选"解除锁定" → 确定，再双击即可。

### 备用启动方式（任选其一）

| 方式 | 说明 |
|---|---|
| `启动DSH.vbs` | ⭐ 首选：完全无窗口，静默完成 |
| `启动DSH.bat` | 能看到详细文字输出，方便排查问题（会有黑色窗口） |
| 无窗口快捷方式 | 见下方"创建无窗口快捷方式" |

### 创建无窗口快捷方式（如果 VBS 被系统禁用时用这个）

某些电脑（企业策略/杀毒软件）会禁用 `.vbs` 脚本，此时可以创建一个不依赖 VBS 的无窗口快捷方式：

1. 右键桌面 → 新建 → 快捷方式
2. 位置填（把 `你的文件夹路径` 换成实际路径）：
   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "你的文件夹路径\open-dsh.ps1" -Log
   ```
3. 下一步 → 命名（如 `DSH 启动`）→ 完成
4. （可选）右键快捷方式 → 属性 → 更改图标 → 浏览选择文件夹里的 `whale.ico`

> 注意：`-WindowStyle Hidden` 就是"无窗口"的关键参数，其他启动方式也可以带上它。

---

## 出问题了？看这里

### Q1：双击后完全没反应？
- 打开同目录下的 **`launcher.log`** 文件，看最后几行日志（这个文件每次运行都会自动更新，记录了详细的执行过程）
- 先手动在浏览器访问 `http://localhost:3080/`，确认 DSH 真的在运行——**本工具只负责"打开"，不负责"启动 DSH"**
- 某些杀毒软件或企业策略会拦截 `.vbs` 文件：改用 **`启动DSH.bat`**，或按上文"创建无窗口快捷方式"的方法做一个 PowerShell 快捷方式（效果一样且不依赖 VBS）

### Q2：打开的是默认浏览器，不是夸克？
- 这是**正常设计**：说明你的电脑没装夸克（或夸克不在常见安装位置），工具自动改用系统默认浏览器了
- 想强制用夸克？命令行运行：
  `powershell -ExecutionPolicy Bypass -File open-dsh.ps1 -Browser quark`

### Q3：我的 DSH 不在 3080 端口？
- 命令行指定地址：
  `powershell -ExecutionPolicy Bypass -File open-dsh.ps1 -Url http://localhost:8080/`

### Q4：有黑色窗口一闪而过？
- 用 `启动DSH.vbs` 启动是**完全没有窗口**的；`启动DSH.bat` 是调试用的，会显示窗口和详细文字

---

## 高级用法（给爱折腾的人）

直接在命令行（或右键 → 用 PowerShell 运行）执行：

```powershell
# 打开 DSH（默认：优先夸克，否则默认浏览器）
powershell -ExecutionPolicy Bypass -File open-dsh.ps1

# 指定 DSH 地址
powershell -ExecutionPolicy Bypass -File open-dsh.ps1 -Url http://localhost:8080/

# 浏览器策略
powershell -ExecutionPolicy Bypass -File open-dsh.ps1 -Browser auto      # 优先夸克，没有就用默认（默认值）
powershell -ExecutionPolicy Bypass -File open-dsh.ps1 -Browser default   # 始终用系统默认浏览器
powershell -ExecutionPolicy Bypass -File open-dsh.ps1 -Browser quark     # 只用夸克

# 演示模式（只显示流程，不真正打开浏览器）
powershell -ExecutionPolicy Bypass -File open-dsh.ps1 -DryRun
```

---

## 文件说明

| 文件 | 用途 |
|---|---|
| `启动DSH.vbs` | ⭐ **日常使用入口**：双击运行，无窗口、静默完成 |
| `启动DSH.bat` | 调试入口：双击可看到详细文字输出 |
| `open-dsh.ps1` | 主脚本（真正的逻辑所在） |
| `whale.ico` | 快捷方式用的鲸鱼图标 |
| `launcher.log` | 运行日志（自动生成，排查问题时看它） |

## 想把它固定到桌面？

右键 `启动DSH.vbs` → 发送到 → 桌面快捷方式，再把快捷方式图标改成鲸鱼：
右键快捷方式 → 属性 → 更改图标 → 浏览选择 `whale.ico`。

---

## 开源信息

- 协议：MIT（详见 [LICENSE](LICENSE)）
- 图标 `whale.ico` 由 DSH 前端自带的 `favicon.svg`（DeepSeek 鲸鱼标识）转换而来，标识版权归 DeepSeek 所有
- 源码：https://github.com/SeaChou95/dsh-launcher
