# PocketBase 部署说明

本目录包含 Flutter 应用所需的服务端 Hook，适用于 PocketBase v0.39.7。
PocketBase 管理后台中配置的数据集合必须与本文档描述的结构一致。

部署前，请将 `locations` 集合的 View API Rule 修正为：

```text
@request.auth.id != "" && family.family_members_via_family.user ?= @request.auth.id
```

在仓库根目录打开 Windows PowerShell，然后上传以下两个 Hook 文件：

```powershell
scp "pocketbase/pb_hooks/main.pb.js" root@YOUR_SERVER_IP:/tmp/main.pb.js
scp "pocketbase/pb_hooks/findit.js" root@YOUR_SERVER_IP:/tmp/findit.js
```

随后在服务器上执行以下命令：

```bash
install -d -o pocketbase -g pocketbase /opt/pocketbase/pb_hooks
install -o pocketbase -g pocketbase -m 0640 /tmp/main.pb.js /opt/pocketbase/pb_hooks/main.pb.js
install -o pocketbase -g pocketbase -m 0640 /tmp/findit.js /opt/pocketbase/pb_hooks/findit.js
systemctl restart pocketbase
systemctl status pocketbase --no-pager -l
journalctl -u pocketbase -n 50 --no-pager
```

请将 `YOUR_SERVER_IP` 替换为实际服务器 IP。Linux 上的 PocketBase 在 Hook
发生变化时也会自动重新加载，但这里仍建议明确重启服务，以便及时发现部署失败。

Hook 提供以下需要用户身份认证的接口：

```text
POST /api/findit/create-family  {"name":"My family"}
POST /api/findit/join-family    {"invite_code":"ABCDEFGH"}
```

Hook 还会阻止客户端修改业务记录所属的家庭，并拒绝引用其他家庭的位置、分类和
上级位置记录。

## 广告管理

应用首页可以展示一条公开横幅广告。广告通过 PocketBase 自带的网页管理后台维护，
后台地址为 `https://YOUR_POCKETBASE_DOMAIN/_/`。请创建名为 `ads` 的 Base
collection，并添加以下字段：

```text
name: text，必填，最多 100 个字符
placement: select，必填，单选值 (home_top, settings_top)
title: text，必填，最多 40 个字符
subtitle: text，最多 80 个字符
image: file，必填，单文件，最大 5242880 bytes
       (image/jpeg, image/png, image/webp)
target_url: url
button_text: text，最多 20 个字符
enabled: bool
starts_at: date
ends_at: date
priority: number，最小值 0，最大值 10000
background_color: text，正则表达式 ^#[0-9A-Fa-f]{6}$
```

广告需要在用户登录前显示，因此 `image` 字段不能启用 Protected。将 List API
Rule 和 View API Rule 都设置为：

```text
enabled = true && (starts_at = "" || starts_at <= @now) && (ends_at = "" || ends_at >= @now)
```

Create、Update 和 Delete API Rule 保持锁定，只允许 PocketBase 超级管理员维护
广告。应用要求 PocketBase 地址使用 HTTPS，只会打开初始地址为 HTTPS 的广告链接，
并从对应 placement 记录中选择 `priority` 最高的一条。横幅比例为 3:1，建议使用
1200 x 400 图片。不需要点击跳转时，将 `target_url` 留空。由于图片允许未登录用户
访问，禁用或下架广告后如果图片也不应继续公开访问，需要删除该记录或删除其图片。

### 广告位列表

| placement | 展示位置 |
|-----------|----------|
| `home_top` | 首页搜索栏下方 |
| `settings_top` | 设置页顶部 |

## 必需的数据集合

应用依赖以下非系统集合及字段：

```text
users (auth 认证集合)
families: name, invite_code, owner -> users
family_members: family -> families, user -> users, role(owner|member)
locations: family -> families, sync_id, name, parent -> locations,
           sort_order, is_deleted
categories: family -> families, sync_id, name, icon, color, sort_order,
             is_deleted
items: family -> families, sync_id, name, location -> locations,
       category -> categories, notes, photos, item_created_at, is_deleted
ads: name, placement, title, subtitle, image, target_url, button_text,
     enabled, starts_at, ends_at, priority, background_color
```

必须创建以下唯一索引：

```text
families(invite_code)
family_members(family, user)
family_members(user)
locations(sync_id)
categories(sync_id)
items(sync_id)
```

`items.photos` 必须是启用 Protected 的多文件字段，最多允许 20 个文件，每个文件
最大为 10485760 bytes。允许的文件类型为 `image/jpeg`、`image/png` 和
`image/webp`。

`families` 和 `family_members` 的 Create、Update、Delete API Rule 必须保持为
仅超级管理员可操作，因为这些写入由自定义接口负责。业务集合的 API Rule 必须通过
以下规则检查用户是否属于对应家庭：

```text
@request.auth.id != "" && family.family_members_via_family.user ?= @request.auth.id
```
