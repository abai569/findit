# 物品管家 架构设计

## 系统架构

```
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐ │
│  │  Home    │  │  Search  │  │  Add     │  │Settings│ │
│  │  Screen  │  │  Screen  │  │  Item    │  │ Screen │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───┬────┘ │
└───────┼─────────────┼─────────────┼─────────────┼──────┘
        │             │             │             │
┌───────▼─────────────▼─────────────▼─────────────▼──────┐
│                   Provider Layer                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │              AppProvider                         │  │
│  │  - State Management                              │  │
│  │  - Business Logic                                │  │
│  │  - Data Coordination                             │  │
│  └────────────────────┬─────────────────────────────┘  │
└─────────────────────┬──────────────────────────────────┘
                      │
┌─────────────────────▼──────────────────────────────────┐
│                   Service Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────────┐ │
│  │  Database   │  │   WebDAV    │  │     Image      │ │
│  │  Service    │  │   Service   │  │    Service     │ │
│  │             │  │             │  │                │ │
│  │  - SQLite   │  │  - Backup   │  │  - Pick        │ │
│  │  - CRUD     │  │  - Restore  │  │  - Compress    │ │
│  │  - Query    │  │  - Sync     │  │  - Store       │ │
│  └─────────────┘  └─────────────┘  └────────────────┘ │
│  ┌──────────────────────────────────────────────────┐  │
│  │           Encryption Service                     │  │
│  │           - AES-256-CBC                          │  │
│  │           - Credentials                          │  │
│  │           - Backup Files                         │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                      │
┌─────────────────────▼──────────────────────────────────┐
│                   Data Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────────┐ │
│  │   SQLite    │  │   Local     │  │    WebDAV      │ │
│  │   Database  │  │   Storage   │  │    Server      │ │
│  │             │  │             │  │                │ │
│  │  - items    │  │  - Images   │  │  - .enc files  │ │
│  │  - locations│  │  - Cache    │  │  - Backups     │ │
│  │  - categories                      │                │ │
│  └─────────────┘  └─────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## 数据流

### 添加物品流程

```
User Input → AddItemScreen → AppProvider.addItem()
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
              ImageService      DatabaseService    WebDAVService
              - Pick image      - Insert item     - Auto backup
              - Compress        - Update state    - Upload .enc
```

### 搜索流程

```
Search Input → SearchScreen → AppProvider.searchItems()
                                       │
                                 DatabaseService
                                 - Query with LIKE
                                 - Return filtered list
                                       │
                                 Update UI State
```

### 备份流程

```
User Action / Auto Trigger
           │
    ┌──────▼──────┐
    │ Check Last  │
    │ Backup Time │
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │ Find Changed│
    │    Items    │
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │  Compress   │
    │   Images    │
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │   Create    │
    │ Backup Pkg  │
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │  Encrypt    │
    │  (AES-256)  │
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │  Upload to  │
    │   WebDAV    │
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │  Cleanup    │
    │ Old Backups │
    └─────────────┘
```

## 备份文件结构

```
findit_backup_v1_device123_full_1234567890.zip.enc
│
├── metadata.json      # 备份元数据
│   ├── backup_time
│   ├── is_full_backup
│   ├── last_sync_version
│   └── device_id
│
├── items.json         # 物品数据
│   ├── id
│   ├── name
│   ├── location_id
│   ├── category_id
│   ├── image_path
│   ├── created_at
│   └── updated_at
│
├── locations.json     # 位置数据
│   ├── id
│   ├── name
│   ├── parent_id
│   └── sort_order
│
├── categories.json    # 分类数据
│   ├── id
│   ├── name
│   ├── icon
│   └── color
│
└── database.db        # 完整数据库（仅全量备份）
```

## 加密方案

### 密钥生成
```
Password = PBKDF2(salt='findit_backup_salt_2024', 
                  password='findit_app_key',
                  iterations=1000,
                  key_length=32,
                  hash=SHA256)
```

### 加密算法
- **算法**: AES-256-CBC
- **IV**: 固定 16 字节 'findit_iv_16bytes!'
- **填充**: PKCS7

### 凭证存储
```
SharedPreferences (encrypted)
└── webdav_config (AES-256 encrypted JSON)
    ├── url
    ├── username
    └── password
```

## 状态管理

### AppProvider 状态
```dart
class AppProvider with ChangeNotifier {
  // Data
  List<Item> _items
  List<Location> _locations
  List<Category> _categories
  
  // UI State
  bool _isLoading
  String? _error
  bool _hasWebDAVConfig
  List<Map> _backupHistory
  
  // Methods
  init()
  loadAllData()
  addItem()
  updateItem()
  deleteItem()
  searchItems()
  manualBackup()
  restoreFromWebDAV()
}
```

## 性能优化

1. **图片压缩**: 限制 1024x1024, quality 70%
2. **增量备份**: 只备份变更数据
3. **懒加载**: 列表分页加载
4. **缓存**: 常用数据内存缓存
5. **异步**: 所有 I/O 操作异步执行

## 安全考虑

1. **本地加密**: WebDAV 凭证加密存储
2. **传输加密**: 强制 HTTPS
3. **备份加密**: AES-256 加密备份文件
4. **权限最小化**: 仅申请必要权限
5. **数据隔离**: 应用沙盒存储

## 扩展性设计

1. **模块化**: Services 独立，易替换
2. **接口抽象**: 便于单元测试
3. **Provider 模式**: 状态管理解耦
4. **配置化**: WebDAV 支持多服务商
5. **版本控制**: 数据库迁移支持
