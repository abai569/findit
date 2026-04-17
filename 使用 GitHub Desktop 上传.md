# 使用 GitHub Desktop 上传代码（无需 Git 命令行）

## 第 1 步：下载 GitHub Desktop

1. 访问：https://desktop.github.com
2. 点击 **Download for Windows**
3. 安装程序下载后，双击安装
4. 安装完成后打开 GitHub Desktop

## 第 2 步：登录 GitHub

1. 打开 GitHub Desktop
2. 点击 **Sign in to GitHub.com**
3. 浏览器会自动打开登录页面
4. 输入你的 GitHub 账号密码登录
5. 授权 GitHub Desktop
6. 回到 GitHub Desktop，点击 **Finish**

## 第 3 步：添加项目

1. 点击 **File** → **Add local repository**
2. 点击 **Choose...**
3. 选择文件夹：`C:\Users\57064\app\findit`
4. 点击 **Select Folder**
5. 如果提示"not a Git repository"，点击 **create a repository**
6. 输入描述：`物品管家 - 物品定位记录应用`
7. 点击 **Create repository**

## 第 4 步：首次提交

1. 在左下角 **Summary** 输入：`Initial commit`
2. 点击 **Commit to main**

## 第 5 步：发布到 GitHub

1. 点击顶部的 **Publish repository**
2. 填写：
   - Name: `wuping-guanjia`
   - Description: `物品管家 - 物品定位记录应用`
   - ✅ 取消勾选 "Keep this code private"（免费账户必须公开）
3. 点击 **Publish repository**
4. 等待上传完成

## 第 6 步：触发自动编译

1. 浏览器打开：https://github.com/你的用户名/wuping-guanjia
2. 点击顶部 **Actions** 标签
3. 点击 **I understand my workflows, go ahead and enable them**（如果提示）
4. 点击左侧的 **Build Flutter APK**
5. 点击右侧 **Run workflow**
6. 点击 **Run workflow** 确认

## 第 7 步：等待并下载

1. 等待 10-15 分钟
2. 状态变为 ✅ 后，点击进入
3. 滚动到页面底部
4. 点击 **物品管家-app** 下载
5. 解压得到 APK 文件

---

## 后续更新

修改代码后：
1. 在 GitHub Desktop 中看到变更
2. 输入 Summary（如：修复 XXX 问题）
3. 点击 **Commit to main**
4. 点击 **Push origin**
5. GitHub Actions 会自动编译新版本

---

## 常见问题

### Q: 发布时提示需要登录？
A: 确保已在 GitHub Desktop 登录 GitHub 账号

### Q: 上传速度慢？
A: 正常现象，代码量约几 MB，等待 2-5 分钟即可

### Q: 找不到 Actions 标签？
A: 仓库创建后需要几分钟才会显示 Actions

---

**预计总耗时**：15-20 分钟（含下载和编译时间）

祝你成功！🎉
