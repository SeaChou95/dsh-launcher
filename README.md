# DSH 自动启动器 (DSH Launcher)

一个 Windows 下的自动化启动小工具：**自动获取 DSH（DeepSeek Harness）地址 → 自动找到夸克浏览器 → 一键打开 DSH Web 界面**。

## 功能流程

脚本自动执行三步：

1. **获取 DSH 地址**：检查 3080 端口监听状态 → 发送 HTTP 请求确认服务可用 → 列出本机访问地址（`http://localhost:3080/` 与局域网 IP）
2. **查找夸克浏览器**：依次从常见安装路径 → 开始菜单快捷方式 → 注册表卸载信息 三层查找；找不到时自动回退到系统默认浏览器
3. **打开 DSH**：用夸克浏览器打开 DSH Web 界面

## 使用方法

### 双击运行（推荐）

直接双击 `启动DSH.bat`，自动执行上述三步流程。

### 命令行运行

```powershell
powershell -ExecutionPolicy Bypass -File open-dsh.ps1
```

### 演示模式（不真正打开浏览器）

```powershell
powershell -ExecutionPolicy Bypass -File open-dsh.ps1 -DryRun
```

## 文件说明

| 文件 | 说明 |
|---|---|
| `启动DSH.bat` | 双击入口，调用 PowerShell 脚本 |
| `open-dsh.ps1` | 主脚本：地址检测、浏览器查找、启动逻辑 |
| `whale.ico` | 桌面快捷方式图标（黑色鲸鱼） |

## 环境要求

- Windows 10 / 11
- PowerShell（5.1 或 7+ 均可，脚本已处理 UTF-8 中文显示问题）

## 图标说明

`whale.ico` 由 DSH Web 前端自带的 `favicon.svg`（DeepSeek 鲸鱼标识）转换而来：
使用 GDI+ 编写 SVG 路径解析器渲染为 PNG，再打包为多尺寸 ICO。
DeepSeek 标识版权归 DeepSeek 所有，本仓库仅用于该工具的个人使用场景。

## 开源协议

[MIT](LICENSE)
