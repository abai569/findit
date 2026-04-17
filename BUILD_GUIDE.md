# 物品管家 - 在线编译 APK 指南

## 方法一：GitHub Actions（推荐，完全免费）

### 步骤 1：创建 GitHub 仓库

1. 访问 https://github.com
2. 登录/注册账号
3. 点击右上角 **+** → **New repository**
4. 仓库名：`findit`
5. 设为 **Public**（免费）
6. 点击 **Create repository**

### 步骤 2：上传代码到 GitHub

**使用 Git 命令行：**

```bash
# 进入项目目录
cd C:\Users\57064\app\findit

# 初始化 Git 仓库
git init

# 添加所有文件
git add .

# 创建提交
git commit -m "Initial commit - FindIt app"

# 添加远程仓库（替换 YOUR_USERNAME 为你的 GitHub 用户名）
git remote add origin https://github.com/YOUR_USERNAME/findit.git

# 推送代码
git push -u origin main
```

**或使用 GitHub Desktop（图形界面）：**
1. 下载：https://desktop.github.com
2. 添加本地仓库 → 选择 `C:\Users\57064\app\findit`
3. 提交并推送到 GitHub

### 步骤 3：触发自动编译

**方式 A：推送代码自动编译**
- 每次推送代码到 GitHub 都会自动编译

**方式 B：手动触发编译**
1. 进入 GitHub 仓库页面
2. 点击 **Actions** 标签
3. 左侧选择 **Build Flutter APK**
4. 点击 **Run workflow** 按钮
5. 等待编译完成（约 10-15 分钟）

### 步骤 4：下载 APK

1. 编译完成后，进入 **Actions** → 点击最近的构建
2. 在 **Artifacts** 区域下载 `findit-app.zip`
3. 解压后得到 `app-release.apk`

**如果创建了 Release：**
- 点击右侧 **Releases**
- 下载最新版本的 APK

---

## 方法二：Codemagic（备选，每月免费 500 分钟）

### 步骤 1：注册 Codemagic

1. 访问 https://codemagic.io
2. 使用 GitHub 账号登录

### 步骤 2：添加项目

1. 点击 **Add application**
2. 选择你的 `findit` 仓库
3. 选择 **Generic Flutter**

### 步骤 3：配置构建

1. 构建配置会自动读取 `codemagic.yaml`
2. 点击 **Save changes**

### 步骤 4：开始构建

1. 点击 **Start new build**
2. 等待构建完成
3. 在 **Builds** 页面下载 APK

---

## 安装 APK 到手机

### 方式 1：直接传输
1. 将 APK 文件发送到手机（微信/QQ/数据线）
2. 在手机上打开 APK 文件
3. 允许安装未知来源应用
4. 点击安装

### 方式 2：ADB 安装（需要 USB 调试）
```bash
adb install app-release.apk
```

---

## 常见问题

### Q1: GitHub Actions 一直显示 queued
**A**: 免费账户需要排队，通常等待 2-5 分钟

### Q2: 编译失败
**A**: 检查日志，常见原因：
- 依赖包版本不兼容 → 更新 `pubspec.yaml`
- 签名配置错误 → 暂时移除签名配置

### Q3: 安装时提示"解析包时出现问题"
**A**: 
- 确保 Android 版本 >= 5.0
- 检查是否下载完整 APK（约 40-60MB）

### Q4: 如何禁用签名配置（调试用）
编辑 `android/app/build.gradle`，注释掉签名相关配置：
```gradle
// signingConfigs { ... }
buildTypes {
    release {
        // signingConfig signingConfigs.release
    }
}
```

---

## 快速操作清单

- [ ] 注册 GitHub 账号
- [ ] 创建仓库 `findit`
- [ ] 推送代码到 GitHub
- [ ] 进入 Actions 标签
- [ ] 点击 Run workflow
- [ ] 等待 10-15 分钟
- [ ] 下载 APK 文件
- [ ] 安装到手机测试

---

## 后续更新

修改代码后重新编译：
```bash
# 修改代码后
git add .
git commit -m "更新说明"
git push
```

GitHub Actions 会自动编译新版本！
