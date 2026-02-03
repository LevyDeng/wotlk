# 数据库重新生成指南

本文档说明如何重新生成 WoW WOTLK 模拟器的数据库文件。

## 概述

数据库生成工具位于 `tools/database/gen_db/main.go`，它从多个数据源收集物品、宝石、附魔等信息，最终生成 `assets/database/db.bin` 和 `assets/database/db.json` 文件。

## 数据源

数据库生成需要以下输入文件（位于 `assets/db_inputs/` 目录）：

1. **wowhead_item_tooltips.csv** - 从 Wowhead 抓取的物品提示信息
2. **wowhead_spell_tooltips.csv** - 从 Wowhead 抓取的法术提示信息
3. **wowhead_gearplannerdb.txt** - 从 Wowhead 抓取的装备规划数据库
4. **atlasloot_db.json** - 从 AtlasLoot 生成的数据
5. **wago_db2_items.csv** - 从 wago.tools 下载的 ItemSparse 数据（用于阵营限制）
6. **glyph_id_map.json** - 雕文ID映射

## Item.csv 文件说明

你已经提取了 `assets/database/dbfilesclient/Item.csv` 文件。这个文件是从 WoW 客户端 DB2 文件中提取的物品基础数据。

**注意**：当前代码中并没有直接使用 `Item.csv` 文件。代码使用的是 `wago_db2_items.csv`，它是从 wago.tools 网站下载的 ItemSparse 数据，主要用于获取物品的阵营限制信息（Alliance Only / Horde Only）。

如果你想要使用本地的 `Item.csv` 文件，可能需要：
1. 修改代码以支持从 `Item.csv` 读取数据
2. 或者将 `Item.csv` 转换为 `wago_db2_items.csv` 的格式

## 生成步骤

### 方法一：使用 make 命令（推荐）

```bash
make items
```

这会自动运行数据库生成工具。

### 方法二：直接运行 Go 程序

**Linux/macOS**（shell 会展开 `*`）:
```bash
go run tools/database/gen_db/*.go -outDir=./assets -gen=db
```

**Windows (PowerShell)**（不要用 `*`，用包路径）:
```powershell
go run ./tools/database/gen_db -outDir=./assets -gen=db
```

## 完整的数据抓取流程

如果需要从头开始重新抓取所有数据，按以下顺序执行：

### 1. 生成 AtlasLoot 数据

```bash
go run ./tools/database/gen_db -outDir=assets -gen=atlasloot
```

这会生成 `assets/db_inputs/atlasloot_db.json`

### 2. 抓取 Wowhead 物品提示

```bash
go run ./tools/database/gen_db -outDir=assets -gen=wowhead-items
```

这会抓取物品的提示信息并保存到 `assets/db_inputs/wowhead_item_tooltips.csv`

**注意**：这个过程可能需要很长时间，因为它需要访问 Wowhead 网站抓取每个物品的信息。

### 3. 抓取 Wowhead 法术提示

```bash
go run ./tools/database/gen_db -outDir=assets -gen=wowhead-spells -maxid=75000
```

这会抓取法术的提示信息并保存到 `assets/db_inputs/wowhead_spell_tooltips.csv`

### 4. 抓取 Wowhead 装备规划数据库

```bash
go run ./tools/database/gen_db -outDir=assets -gen=wowhead-gearplannerdb
```

这会从 Wowhead 下载装备规划数据库并保存到 `assets/db_inputs/wowhead_gearplannerdb.txt`

### 5. 下载 Wago DB2 物品数据

```bash
go run ./tools/database/gen_db -outDir=assets -gen=wago-db2-items
```

这会从 wago.tools 下载 ItemSparse 数据并保存到 `assets/db_inputs/wago_db2_items.csv`

**或者**，如果你已经有本地的 `Item.csv` 文件，你可以：
- 检查 `Item.csv` 的格式是否与 `wago_db2_items.csv` 兼容
- 如果兼容，可以直接复制：`cp assets/database/dbfilesclient/Item.csv assets/db_inputs/wago_db2_items.csv`
- 注意：`wago_db2_items.csv` 需要包含 `ID` 和 `Flags_1` 列

### 6. 生成最终数据库

当所有输入文件都准备好后，运行：

```bash
go run ./tools/database/gen_db -outDir=assets -gen=db
```

或者：

```bash
make items
```

这会生成：
- `assets/database/db.bin` - 二进制格式的数据库（用于程序加载）
- `assets/database/db.json` - JSON 格式的数据库（用于调试）
- `assets/database/leftover_db.bin` - 非模拟物品的数据库
- `assets/database/leftover_db.json` - 非模拟物品的 JSON 数据库

## 从客户端数据生成数据库（泰坦重铸服务器）

对于泰坦重铸服务器等没有外部数据库网站的情况，你可以从游戏客户端提取数据来生成数据库。

### 必需的文件

数据库生成需要以下文件（位于 `assets/db_inputs/` 目录）：

1. **wowhead_item_tooltips.csv** - 物品提示信息（必需）
2. **wowhead_spell_tooltips.csv** - 法术提示信息（必需）
3. **wowhead_gearplannerdb.txt** - 可选，用于过滤物品
4. **atlasloot_db.json** - 可选，用于物品来源信息
5. **wago_db2_items.csv** - 可选，用于阵营限制（如果不需要阵营限制，可以忽略）

### 从客户端提取数据

你需要从客户端提取以下数据：

1. **物品提示信息**：需要从游戏客户端或服务器提取物品的 tooltip 数据
   - 格式：CSV 文件，包含物品 ID 和对应的 tooltip HTML
   - 如果没有，你可能需要编写脚本从客户端 DB2 文件或其他数据源提取

2. **法术提示信息**：类似地，需要法术的 tooltip 数据

### 使用 Item.csv

`Item.csv` 文件是从客户端 `Item.db2` 提取的基础物品信息。**注意**：

- `Item.csv` 不包含 tooltip 信息，而数据库生成主要依赖 tooltip 来解析物品属性
- 如果只有 `Item.csv`，你可能需要：
  1. 从客户端提取 ItemSparse 数据（包含更多信息）
  2. 或者编写自定义解析器来从 Item.csv 读取基础信息

### 简化流程（不依赖外部网站）

如果不需要阵营限制，代码已经修改为可以处理可选文件：

1. **准备必需文件**：
   - `wowhead_item_tooltips.csv` - 物品提示信息
   - `wowhead_spell_tooltips.csv` - 法术提示信息

2. **可选文件**（如果不存在，代码会自动跳过）：
   - `wowhead_gearplannerdb.txt` - 如果不存在，所有可装备物品都会被包含
   - `atlasloot_db.json` - 如果不存在，物品来源信息会缺失
   - `wago_db2_items.csv` - 如果不存在，阵营限制会被忽略

3. **生成数据库**：
   ```bash
   make items
   ```
   或
   ```bash
   go run tools/database/gen_db/*.go -outDir=./assets -gen=db
   ```

代码已经修改为：
- ✅ 支持可选文件（文件不存在时不会报错）
- ✅ 阵营限制是可选的（如果没有 Flags_1 列，会忽略阵营限制）
- ✅ 如果没有 wowhead_gearplannerdb.txt，会包含所有可装备物品

## 自定义装备数据

对于时光服等自定义服务器，如果某些装备在数据库中找不到，你可以手动添加自定义装备数据。

**详细指南请查看**: `CUSTOM_ITEMS_GUIDE.md`

### 快速步骤

1. **找到缺失的装备ID**：
   - 使用插件导入功能，查看导入错误信息
   - 记录所有缺失的物品ID、宝石ID和附魔ID

2. **添加自定义数据**：
   - 编辑 `tools/database/overrides.go`，在 `ItemOverrides` 中添加装备
   - 在 `GemOverrides` 中添加宝石（如果需要）
   - 编辑 `tools/database/enchant_overrides.go`，在 `EnchantOverrides` 中添加附魔（如果需要）

3. **最小配置示例**：
   ```go
   &proto.UIItem{
       Id: 257631,  // 从插件JSON中获取
       Type: proto.ItemType_ItemTypeHead,  // 根据实际部位设置
       Stats: stats.Stats{
           stats.Strength: 100,
           stats.Stamina: 150,
           // 添加你知道的属性
       }.ToFloatArray(),
       Ilvl: 200,
       Quality: proto.ItemQuality_ItemQualityEpic,
   }
   ```

4. **重新生成数据库**：
   ```bash
   make items
   ```

5. **测试**：重新导入插件JSON，检查是否还有缺失的装备

**注意**：你只需要填写 ID 和属性即可，特殊效果可以忽略或手动折算为属性值。

## 数据库加载

生成的数据库在运行时通过 `assets/database/loader.go` 加载：

```go
//go:embed db.bin
var dbBytes []byte

func Load() *proto.UIDatabase {
    db := &proto.UIDatabase{}
    if err := googleProto.Unmarshal(dbBytes, db); err != nil {
        panic(err)
    }
    return db
}
```

数据库以 Protocol Buffer 格式嵌入到程序中。

## 故障排除

1. **缺少输入文件**：确保 `assets/db_inputs/` 目录下有所需的所有文件
2. **网络问题**：抓取 Wowhead 数据需要稳定的网络连接
3. **格式错误**：检查 CSV 文件的格式和编码
4. **权限问题**：确保有写入 `assets/database/` 目录的权限

## 相关文件

- `tools/database/gen_db/main.go` - 数据库生成主程序
- `tools/database/database.go` - 数据库结构定义
- `tools/database/wago_db.go` - Wago DB2 数据解析
- `tools/database/wowhead_db.go` - Wowhead 数据解析
- `assets/database/loader.go` - 数据库加载器
