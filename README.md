# 物品管家 - 物品定位记录应用

记录物品位置，快速查找。支持 WebDAV 备份恢复，防止数据丢失。

**应用名称：物品管家**

## 功能特性

### 核心功能
- ✅ 物品记录（名称、位置、分类、照片）
- ✅ 位置管理（支持层级结构）
- ✅ 分类标签（10 种预设分类）
- ✅ 快速搜索（关键词、模糊匹配）
- ✅ 分类筛选

### 数据备份
- ✅ WebDAV 备份（支持坚果云、Nextcloud、群晖 NAS 等）
- ✅ 自动备份（每次添加/修改后）
- ✅ 增量备份（节省空间）
- ✅ 加密存储（AES-256）
- ✅ 保留最近 5 个版本
- ✅ 一键恢复（换机同步）

## 技术栈

- **框架**: Flutter 3.x
- **数据库**: SQLite (sqflite)
- **状态管理**: Provider
- **WebDAV**: webdav_client
- **图片压缩**: flutter_image_compress
- **加密**: encrypt (AES-256-CBC)

## 快速开始

### 环境要求
- Flutter SDK >= 3.0.0
- Dart >= 3.0.0
- iOS 12.0+ / Android 5.0+

### 安装依赖
```bash
cd findit
flutter pub get
```

### 运行应用
```bash
flutter run
```

### 构建发布版本
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## WebDAV 配置示例

### 坚果云
```
服务器地址：https://dav.jianguoyun.com/dav
用户名：你的坚果云账号
密码：你的坚果云应用密码（非登录密码）
```

### Nextcloud
```
服务器地址：https://你的域名/remote.php/dav/files/用户名
用户名：你的 Nextcloud 用户名
密码：你的 Nextcloud 密码
```

### 群晖 NAS
```
服务器地址：http://NAS_IP:5005/webdav
用户名：你的群晖用户名
密码：你的群晖密码
```

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型
│   ├── item.dart            # 物品模型
│   ├── location.dart        # 位置模型
│   └── category.dart        # 分类模型
├── providers/               # 状态管理
│   └── app_provider.dart    # 全局状态
├── screens/                 # 页面
│   ├── home/               # 首页
│   ├── add_item/           # 添加/编辑物品
│   ├── search/             # 搜索页面
│   └── settings/           # 设置页面
├── services/               # 服务层
│   ├── database.dart       # 数据库操作
│   ├── webdav_service.dart # WebDAV 备份恢复
│   ├── encryption_service.dart # 加密服务
│   └── image_service.dart  # 图片处理
└── widgets/                # 可复用组件
```

## 数据库设计

### items 表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| name | TEXT | 物品名称 |
| location_id | INTEGER | 位置 ID |
| category_id | INTEGER | 分类 ID |
| image_path | TEXT | 图片路径 |
| created_at | TEXT | 创建时间 |
| updated_at | TEXT | 更新时间 |
| is_deleted | INTEGER | 软删除标记 |

### locations 表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER | 主键 |
| name | TEXT | 位置名称 |
| parent_id | INTEGER | 父位置 ID |
| sort_order | INTEGER | 排序 |

## 备份流程

1. **检测变更**: 对比上次备份时间，找出变更物品
2. **增量打包**: 只打包变更的数据
3. **图片压缩**: 压缩到 500KB 以内
4. **加密**: AES-256 加密备份文件
5. **上传**: 上传到 WebDAV 服务器
6. **清理**: 保留最近 5 个版本

## 注意事项

1. **首次使用**: 建议先配置 WebDAV 并手动备份一次
2. **图片权限**: Android 需要申请相机和存储权限
3. **网络要求**: 备份恢复需要网络连接
4. **密码安全**: WebDAV 密码加密存储在本地
5. **备份频率**: 每次修改自动备份，无需手动操作

## 开发计划

- [ ] 位置层级管理（子位置）
- [ ] 自定义分类
- [ ] 物品借用记录
- [ ] 二维码/条形码扫描
- [ ] 语音输入
- [ ] 桌面小组件

## 许可证

MIT License
