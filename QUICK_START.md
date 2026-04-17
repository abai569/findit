# 物品管家 - 5 分钟快速打包指南

## 🚀 最简单方法（推荐新手）

### 第 1 步：上传到 GitHub（3 分钟）

1. **下载 GitHub Desktop**（如果没安装 Git）
   - 访问：https://desktop.github.com
   - 下载并安装

2. **上传代码**
   - 打开 GitHub Desktop
   - 点击 **Add** → **Add Existing Repository**
   - 选择文件夹：`C:\Users\57064\app\findit`
   - 输入描述：`FindIt - 物品定位应用`
   - 点击 **Add repository**
   - 点击 **Publish repository**
   - 输入仓库名：`findit`
   - 设为 **Public**
   - 点击 **Publish**

### 第 2 步：自动编译（10 分钟）

1. **打开 GitHub 仓库页面**
   - 浏览器访问：https://github.com/你的用户名/findit

2. **触发编译**
   - 点击顶部 **Actions** 标签
   - 点击 **Build Flutter APK**
   - 点击 **Run workflow**（绿色按钮）
   - 点击 **Run workflow** 确认

3. **等待完成**
   - 状态从 ⏳ Queued → 🟡 In progress → ✅ Complete
   - 约需 10-15 分钟

### 第 3 步：下载 APK（1 分钟）

1. **下载**
   - 点击绿色的 ✅ 完成状态
   - 在页面底部找到 **Artifacts**
   - 点击 **findit-app** 下载

2. **解压**
   - 解压 `findit-app.zip`
   - 得到 `app-release.apk`（约 40-60MB）

3. **安装到手机**
   - 通过微信/QQ/数据线发送到手机
   - 在手机上打开 APK 文件
   - 允许安装 → 完成

---

## 📱 安装到手机

### Android 手机安装步骤：

1. **传输 APK**
   - 微信文件传输助手
   - QQ 数据线
   - USB 连接电脑复制

2. **安装**
   - 打开手机文件管理器
   - 找到 APK 文件
   - 点击安装
   - 如果提示"未知来源"，允许即可

3. **打开应用**
   - 找到 FindIt 图标
   - 打开开始使用

---

## ⚠️ 常见问题

### 编译失败怎么办？
1. 点击失败的构建查看日志
2. 通常是网络问题，重新运行 workflow 即可
3. 或使用方法二（Codemagic）

### 手机上无法安装？
1. 确保 Android 版本 >= 5.0
2. 开启"允许未知来源应用"
3. 检查 APK 是否下载完整（文件大小）

### 如何更新应用？
1. 修改代码
2. 在 GitHub Desktop 提交并推送
3. 自动编译新版本
4. 下载新 APK 覆盖安装

---

## 🎯 成功标志

✅ GitHub Actions 显示绿色对勾  
✅ 下载到的 APK 文件大小约 40-60MB  
✅ 手机能正常安装并打开  

---

## 需要帮助？

遇到问题可以：
1. 查看项目的 Issues
2. 检查 GitHub Actions 日志
3. 重新运行 workflow

祝你成功！🎉
