# PocketBase deployment

This directory contains the server hook required by the Flutter app. It targets
PocketBase v0.39.7. The collections must match the schema configured in the
PocketBase dashboard.

Before deployment, fix the `locations` View API rule to:

```text
@request.auth.id != "" && family.family_members_via_family.user ?= @request.auth.id
```

From Windows PowerShell in the repository root, upload both hook files:

```powershell
scp "pocketbase/pb_hooks/main.pb.js" root@YOUR_SERVER_IP:/tmp/main.pb.js
scp "pocketbase/pb_hooks/findit.js" root@YOUR_SERVER_IP:/tmp/findit.js
```

Then run these commands on the server:

```bash
install -d -o pocketbase -g pocketbase /opt/pocketbase/pb_hooks
install -o pocketbase -g pocketbase -m 0640 /tmp/main.pb.js /opt/pocketbase/pb_hooks/main.pb.js
install -o pocketbase -g pocketbase -m 0640 /tmp/findit.js /opt/pocketbase/pb_hooks/findit.js
systemctl restart pocketbase
systemctl status pocketbase --no-pager -l
journalctl -u pocketbase -n 50 --no-pager
```

Replace `YOUR_SERVER_IP` with the server IP. PocketBase on Linux also reloads
hooks when they change, but restarting explicitly makes deployment failures
visible.

The hook provides these authenticated routes:

```text
POST /api/findit/create-family  {"name":"My family"}
POST /api/findit/join-family    {"invite_code":"ABCDEFGH"}
```

It also prevents clients from changing a business record's family and rejects
location, category, and parent relations that belong to another family.

## Required collections

The app expects the following non-system collections and fields:

```text
users (auth)
families: name, invite_code, owner -> users
family_members: family -> families, user -> users, role(owner|member)
locations: family -> families, sync_id, name, parent -> locations,
           sort_order, is_deleted
categories: family -> families, sync_id, name, icon, color, sort_order,
            is_deleted
items: family -> families, sync_id, name, location -> locations,
       category -> categories, notes, photos, item_created_at, is_deleted
```

Required unique indexes:

```text
families(invite_code)
family_members(family, user)
family_members(user)
locations(sync_id)
categories(sync_id)
items(sync_id)
```

`items.photos` must be a protected multi-file field with a maximum of 20 files
and 10485760 bytes per file. Allow `image/jpeg`, `image/png`, and `image/webp`.

`families` and `family_members` create/update/delete rules must remain
superusers-only because the custom routes perform those writes. Business
collection rules must require membership through:

```text
@request.auth.id != "" && family.family_members_via_family.user ?= @request.auth.id
```
