# 物品管家 安装指南

## 第一步：安装 Flutter

### Windows 系统

1. **下载 Flutter SDK**
   - 访问：https://docs.flutter.dev/get-started/install/windows
   - 下载最新稳定版 Flutter SDK

2. **解压到合适位置**
   ```
   推荐路径：C:\src\flutter
   不要安装到：C:\Program Files\ 或带空格的路径
   ```

3. **添加环境变量**
   - 右键"此电脑" → 属性 → 高级系统设置
   - 点击"环境变量"
   - 在"系统变量"中找到 `Path`
   - 添加：`C:\src\flutter\bin`

4. **验证安装**
   ```bash
   flutter doctor
   ```

5. **安装 Android Studio**（如没有）
   - 下载：https://developer.android.com/studio
   - 安装后配置 Android SDK
   - 接受 Android 许可证：`flutter doctor --android-licenses`

6. **运行诊断**
   ```bash
   flutter doctor -v
   ```
   确保 Android toolchain 和 Chrome 显示为 ✓

## 第二步：克隆/复制项目

项目已创建在：`C:\Users\57064\app\findit`

## 第三步：安装依赖

```bash
cd C:\Users\57064\app\findit
flutter pub get
```

## 第四步：运行应用

### 连接设备或启动模拟器

**选项 1: 真机调试**
- Android 手机开启"开发者选项"和"USB 调试"
- USB 连接电脑
- 运行 `flutter devices` 查看设备

**选项 2: Android 模拟器**
- Android Studio → Tools → Device Manager
- 创建虚拟设备
- 启动模拟器

**选项 3: iOS 模拟器**（仅 Mac）
- 安装 Xcode
- 运行 `open -a Simulator`

### 启动应用

```bash
flutter run
```

## 第五步：配置 WebDAV（可选但推荐）

1. **注册坚果云**（推荐）
   - 访问：https://www.jianguoyun.com
   - 注册账号

2. **创建应用密码**
   - 登录后 → 账户信息 → 安全选项
   - 生成应用密码（用于 WebDAV）

3. **在 App 中配置**
   - 打开 FindIt App
   - 进入"设置" → "WebDAV 设置"
   - 填写：
     - 服务器地址：`https://dav.jianguoyun.com/dav`
     - 用户名：你的坚果云账号
     - 密码：应用密码（非登录密码）
   - 保存并测试连接

## 常见问题

### 1. flutter 命令不识别
**解决**: 重启终端或重新添加环境变量

### 2. Android licenses not accepted
**解决**: 
```bash
flutter doctor --android-licenses
```
全部选 y 同意

### 3. Gradle 构建失败
**解决**: 
- 打开 `android/build.gradle`
- 修改 `classpath 'com.android.tools.build:gradle:7.3.0'`
- 打开 `android/gradle/wrapper/gradle-wrapper.properties`
- 修改 `distributionUrl=https\://services.gradle.org/distributions/gradle-7.5-all.zip`

### 4. 找不到设备
**解决**:
- 真机：开启 USB 调试，重新插拔 USB
- 模拟器：先启动模拟器再运行 `flutter run`

### 5. 图片权限被拒绝（Android）
**解决**: 
- 在 `android/app/src/main/AndroidManifest.xml` 添加：
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

## 推荐开发工具

- **VS Code** + Flutter 扩展（轻量级）
- **Android Studio**（功能完整）
- **DevTools**: `flutter pub global activate devtools` + `flutter pub global run devtools`

## 下一步

应用运行后：
1. 添加几个位置（如：卧室、客厅、办公室）
2. 添加物品记录（名称、位置、拍照）
3. 配置 WebDAV 并测试备份
4. 尝试搜索功能

祝你使用愉快！🎉
