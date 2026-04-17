# 物品管家 - 打包成 APK 安装包的完整步骤

## 📋 前提条件

- ✅ 有一个 GitHub 账号（免费注册）
- ✅ 项目代码已准备好（当前目录）

---

## 🎯 方案一：GitHub Actions（完全免费，推荐）

### 步骤详解

#### 1️⃣ 创建 GitHub 仓库（2 分钟）

1. 访问 https://github.com
2. 登录账号
3. 点击右上角 **+** → **New repository**
4. 填写：
   - Repository name: `findit`
   - 选择 **Public**（免费账户只能用 Public）
5. 点击 **Create repository**

#### 2️⃣ 上传代码（3 分钟）

**方法 A：使用批处理脚本（最简单）**

1. 双击运行项目根目录的：
   ```
   upload_to_github.bat
   ```

2. 按提示输入你的 GitHub 仓库地址：
   ```
   https://github.com/你的用户名/findit.git
   ```

3. 等待上传完成

**方法 B：手动 Git 命令**

```bash
cd C:\Users\57064\app\findit
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/你的用户名/findit.git
git push -u origin main
```

**方法 C：GitHub Desktop（图形界面）**

1. 下载：https://desktop.github.com
2. 安装后打开
3. File → Add local repository → 选择 `C:\Users\57064\app\findit`
4. 点击 Publish repository

#### 3️⃣ 触发自动编译（1 分钟）

1. 浏览器打开你的仓库：
   ```
   https://github.com/你的用户名/findit/actions
   ```

2. 点击左侧的 **Build Flutter APK**

3. 点击右侧的 **Run workflow** 按钮

4. 选择分支 `main`，点击 **Run workflow**

#### 4️⃣ 等待编译（10-15 分钟）

- 状态变化：⏳ Queued → 🟡 In progress → ✅ Complete
- 免费账户可能需要排队

#### 5️⃣ 下载 APK（1 分钟）

1. 点击绿色的 ✅ 完成状态

2. 滚动到页面底部

3. 在 **Artifacts** 区域点击 **findit-app**

4. 下载 `findit-app.zip`（约 40-60MB）

5. 解压得到 `app-release.apk`

---

## 📱 安装到手机

### Windows 传输到 Android

**方法 1：微信文件传输助手**
1. 电脑登录微信
2. 发送 APK 到"文件传输助手"
3. 手机微信接收并打开

**方法 2：QQ**
1. 发送到"我的电脑"
2. 手机 QQ 接收

**方法 3：数据线**
1. USB 连接手机
2. 复制 APK 到手机存储
3. 手机文件管理器找到并安装

**方法 4：网盘**
1. 上传到百度网盘/阿里云盘
2. 手机下载

---

## 🔄 如何更新版本

修改代码后重新打包：

```bash
# 修改代码后
git add .
git commit -m "修复 XXX 问题"
git push
```

GitHub Actions 会自动编译新版本！

---

## ⚠️ 常见问题

### Q1: Git 命令不识别
**解决**：安装 Git
- 下载：https://git-scm.com/download/win
- 安装时一路 Next 即可

### Q2: GitHub Push 失败
**解决**：
- 检查网络连接
- 确认仓库地址正确
- 确认已登录 GitHub

### Q3: Actions 一直显示 Queued
**解决**：
- 免费账户需要排队，等待 5-10 分钟
- 或稍后再试

### Q4: 编译失败
**解决**：
1. 点击失败的构建查看日志
2. 常见原因：网络超时
3. 重新运行 workflow 即可

### Q5: 手机无法安装 APK
**解决**：
1. 开启"允许未知来源"
2. 确保 Android >= 5.0
3. 检查 APK 是否下载完整

---

## 🎯 方案二：Codemagic（备选）

如果 GitHub Actions 不可用，使用 Codemagic：

1. 访问：https://codemagic.io
2. GitHub 账号登录
3. Add application → 选择 findit 仓库
4. 点击 Start new build
5. 完成后下载 APK

---

## 📊 对比

| 方式 | 优点 | 缺点 |
|------|------|------|
| GitHub Actions | 完全免费，无限次 | 需要排队 |
| Codemagic | 速度快 | 每月 500 分钟限制 |
| 本地编译 | 最快 | 需安装 Flutter |

---

## ✅ 完成清单

- [ ] 注册 GitHub 账号
- [ ] 创建 findit 仓库
- [ ] 上传代码
- [ ] 触发 Actions 编译
- [ ] 下载 APK
- [ ] 安装到手机
- [ ] 打开应用测试

---

**预计总耗时**：20-30 分钟（含等待编译时间）

**实际动手时间**：5 分钟

祝你成功！🎉
