# 自定义装备数据指南

本指南说明如何为时光服（泰坦重铸服务器）添加自定义装备数据。

## 概述

项目支持通过 `ItemOverrides`、`GemOverrides` 和 `EnchantOverrides` 添加自定义装备、宝石和附魔数据。这些覆盖数据会在数据库生成时合并到主数据库中。

## 文件位置

- **物品覆盖**: `tools/database/overrides.go` - `ItemOverrides` 变量
- **宝石覆盖**: `tools/database/overrides.go` - `GemOverrides` 变量
- **附魔覆盖**: `tools/database/enchant_overrides.go` - `EnchantOverrides` 变量

## 修改已有装备

可以像添加新装备一样，在 `ItemOverrides` 里用**相同 ID** 覆盖已有装备的属性。生成数据库时，会先加载主库，再合并覆盖；若覆盖项带了 `Stats`，会**整体替换**该装备的 `Stats` 数组。

**示例：把 Darkmoon Card: Berserker!（ID 42989）的攻强从 100 改为 200**

```go
// Darkmoon Card: Berserker! - override AP to 200 (default 100)
{Id: 42989, Stats: stats.Stats{stats.AttackPower: 200, stats.RangedAttackPower: 200, stats.Resilience: 100}.ToFloatArray()},
```

注意：覆盖时若提供了 `Stats`，会替换整条属性，所以需要把要保留的属性（如韧性 100）一起写上。

## 添加自定义物品

### 最小必需字段

对于时光服的自定义装备，你只需要提供以下字段：

```go
&proto.UIItem{
    Id: 257631,  // 物品ID（必需）
    Name: "自定义装备名称",  // 可选，但建议填写
    Icon: "inv_icon_name",  // 可选，图标名称
    Type: proto.ItemType_ItemTypeHead,  // 物品类型（必需）
    Stats: stats.Stats{
        stats.Strength: 100,
        stats.Stamina: 150,
        stats.AttackPower: 50,
        // ... 其他属性
    }.ToFloatArray(),
    Ilvl: 200,  // 物品等级（建议填写）
    Quality: proto.ItemQuality_ItemQualityEpic,  // 品质（建议填写）
}
```

### 完整示例

```go
var ItemOverrides = []*proto.UIItem{
    // 时光服自定义装备示例
    {
        Id: 257631,  // 从插件JSON中获取的item ID
        Name: "时光重铸头盔",
        Icon: "inv_helmet_plate_25",
        Type: proto.ItemType_ItemTypeHead,
        ArmorType: proto.ArmorType_ArmorTypePlate,
        Stats: stats.Stats{
            stats.Strength: 100,
            stats.Stamina: 150,
            stats.AttackPower: 50,
            stats.MeleeCrit: 30,
            stats.MeleeHit: 20,
        }.ToFloatArray(),
        Ilvl: 200,
        Phase: 1,
        Quality: proto.ItemQuality_ItemQualityEpic,
        // 如果有套装，可以添加
        // SetName: "时光重铸套装",
    },
    {
        Id: 259904,  // 另一个装备
        Name: "时光重铸护腕",
        Type: proto.ItemType_ItemTypeWrist,
        ArmorType: proto.ArmorType_ArmorTypePlate,
        Stats: stats.Stats{
            stats.Strength: 50,
            stats.Stamina: 75,
            stats.AttackPower: 25,
        }.ToFloatArray(),
        Ilvl: 200,
        Quality: proto.ItemQuality_ItemQualityEpic,
    },
    // ... 更多装备
}
```

**重要**：若装备仅来自自定义（不在 Wowhead/gearplanner 等主数据源中），需把该装备的 **Id** 加入同文件中的 **`ItemAllowList`**，否则可能被过滤掉。例如：`257631: {}, // 北境战盔 (custom override)`。

修改装备或 `ItemOverrides` 后：

1. **`.\quick-test.ps1 items`** — 生成新 `assets/database/db.bin` 和 `db.json`。
2. **`.\quick-test.ps1 ui`** — 在容器内重新执行 `make binary_dist`，把新的 `db.json` 拷进 dist，这样**页面**用的 DB（导入/装备选择器）才会更新；否则会出现 “IDs were not found in the sim database”。
3. **`.\quick-test.ps1 server`**（或 **`.\quick-test.ps1 restart`**）— 重新编译并嵌入新 DB，**服务端**跑模拟时才能解析装备。
4. 浏览器**强制刷新**（Ctrl+F5）后再导入。

若导入时提示 **Enchants: xxx not found**，说明这些附魔不在库里，需要在 `tools/database/enchant_overrides.go` 的 **EnchantOverrides** 里按 ID 添加或覆盖。

### 物品类型 (ItemType)

常用类型：
- `proto.ItemType_ItemTypeHead` - 头部
- `proto.ItemType_ItemTypeNeck` - 项链
- `proto.ItemType_ItemTypeShoulder` - 肩膀
- `proto.ItemType_ItemTypeBack` - 背部
- `proto.ItemType_ItemTypeChest` - 胸部
- `proto.ItemType_ItemTypeWrist` - 护腕
- `proto.ItemType_ItemTypeHands` - 手部
- `proto.ItemType_ItemTypeWaist` - 腰带
- `proto.ItemType_ItemTypeLegs` - 腿部
- `proto.ItemType_ItemTypeFeet` - 脚部
- `proto.ItemType_ItemTypeFinger` - 戒指
- `proto.ItemType_ItemTypeTrinket` - 饰品
- `proto.ItemType_ItemTypeWeapon` - 武器
- `proto.ItemType_ItemTypeRanged` - 远程武器

### 护甲类型 (ArmorType)

- `proto.ArmorType_ArmorTypeCloth` - 布甲
- `proto.ArmorType_ArmorTypeLeather` - 皮甲
- `proto.ArmorType_ArmorTypeMail` - 锁甲
- `proto.ArmorType_ArmorTypePlate` - 板甲

### 武器类型 (WeaponType)

如果是武器，需要设置：
- `WeaponType: proto.WeaponType_WeaponTypeSword` - 剑
- `WeaponType: proto.WeaponType_WeaponTypeAxe` - 斧
- `WeaponType: proto.WeaponType_WeaponTypeMace` - 锤
- `WeaponType: proto.WeaponType_WeaponTypeDagger` - 匕首
- `WeaponType: proto.WeaponType_WeaponTypeStaff` - 法杖
- 等等...

武器还需要设置：
- `HandType: proto.HandType_HandTypeOneHand` 或 `HandType_HandTypeTwoHand`
- `WeaponDamageMin: 100.0`
- `WeaponDamageMax: 150.0`
- `WeaponSpeed: 2.6`

### 可用属性 (Stats)

所有可用的属性常量（在 `sim/core/stats/stats.go` 中定义）：

```go
stats.Strength          // 力量
stats.Agility          // 敏捷
stats.Stamina          // 耐力
stats.Intellect        // 智力
stats.Spirit           // 精神
stats.SpellPower       // 法术强度
stats.MP5              // 每5秒回蓝
stats.SpellHit         // 法术命中
stats.SpellCrit        // 法术暴击
stats.SpellHaste       // 法术急速
stats.SpellPenetration // 法术穿透
stats.AttackPower      // 攻击强度
stats.MeleeHit         // 近战命中
stats.MeleeCrit        // 近战暴击
stats.MeleeHaste       // 近战急速
stats.ArmorPenetration // 护甲穿透
stats.Expertise        // 精准
stats.Armor            // 护甲值
stats.RangedAttackPower // 远程攻击强度
stats.Defense          // 防御等级
stats.Block            // 格挡等级
stats.BlockValue       // 格挡值
stats.Dodge            // 躲闪等级
stats.Parry            // 招架等级
stats.Resilience       // 韧性
stats.ArcaneResistance // 奥术抗性
stats.FireResistance   // 火焰抗性
stats.FrostResistance  // 冰霜抗性
stats.NatureResistance // 自然抗性
stats.ShadowResistance // 暗影抗性
stats.BonusArmor       // 额外护甲
```

### 品质 (Quality)

- `proto.ItemQuality_ItemQualityPoor` - 灰色
- `proto.ItemQuality_ItemQualityCommon` - 白色
- `proto.ItemQuality_ItemQualityUncommon` - 绿色
- `proto.ItemQuality_ItemQualityRare` - 蓝色
- `proto.ItemQuality_ItemQualityEpic` - 紫色
- `proto.ItemQuality_ItemQualityLegendary` - 橙色
- `proto.ItemQuality_ItemQualityArtifact` - 金色
- `proto.ItemQuality_ItemQualityHeirloom` - 传家宝

## 添加自定义宝石

```go
var GemOverrides = []*proto.UIGem{
    {
        Id: 41398,  // 宝石ID
        Name: "自定义宝石",
        Icon: "inv_jewelcrafting_gem_01",
        Color: proto.GemColor_GemColorRed,
        Stats: stats.Stats{
            stats.Strength: 20,
            stats.Stamina: 30,
        }.ToFloatArray(),
        Quality: proto.ItemQuality_ItemQualityEpic,
    },
}
```

### 宝石颜色 (GemColor)

- `proto.GemColor_GemColorMeta` - 多彩
- `proto.GemColor_GemColorRed` - 红色
- `proto.GemColor_GemColorBlue` - 蓝色
- `proto.GemColor_GemColorYellow` - 黄色
- `proto.GemColor_GemColorOrange` - 橙色
- `proto.GemColor_GemColorGreen` - 绿色
- `proto.GemColor_GemColorPurple` - 紫色
- `proto.GemColor_GemColorPrismatic` - 棱彩

## 添加自定义附魔

```go
var EnchantOverrides = []*proto.UIEnchant{
    {
        EffectId: 3817,  // 附魔效果ID（必需）
        ItemId: 0,       // 附魔物品ID（可选）
        SpellId: 0,      // 附魔法术ID（可选）
        Name: "自定义附魔",
        Type: proto.ItemType_ItemTypeHead,  // 可附魔的部位
        Stats: stats.Stats{
            stats.AttackPower: 50,
            stats.Stamina: 30,
        }.ToFloatArray(),
        Quality: proto.ItemQuality_ItemQualityRare,
    },
}
```

**注意**：附魔需要 `EffectId`，这是附魔的唯一标识符。如果不知道 EffectId，可以：
1. 从游戏客户端查找
2. 或者使用一个临时ID（只要不冲突即可）

## 从插件JSON提取数据

你的插件导出的JSON格式：
```json
{
  "gear": {
    "items": [
      {"id": 257631, "enchant": 3817, "gems": [41398, 40013]},
      {"id": 259904, "enchant": 3808, "gems": [40003]}
    ]
  }
}
```

需要提取的信息：
- `id` → 物品ID
- `enchant` → 附魔ID（需要添加到 EnchantOverrides）
- `gems` → 宝石ID（需要添加到 GemOverrides）

## 工作流程

1. **收集缺失的装备ID**：
   - 使用插件导入功能，查看哪些装备ID缺失
   - 从导入错误信息中获取缺失的ID列表

2. **添加自定义数据**：
   - 在 `tools/database/overrides.go` 中添加 `ItemOverrides`
   - 在 `tools/database/overrides.go` 中添加 `GemOverrides`
   - 在 `tools/database/enchant_overrides.go` 中添加 `EnchantOverrides`

3. **重新生成数据库**：
   ```bash
   make items
   ```
   或
   ```bash
   go run ./tools/database/gen_db -outDir=./assets -gen=db
   # Windows PowerShell: 同上。Linux/macOS 也可用: go run tools/database/gen_db/*.go ...
   ```

4. **测试导入**：
   - 重新加载模拟器
   - 使用插件JSON导入功能测试

## 简化方案：只填必需字段

如果你只需要让装备能被识别和装备（不关心特殊效果），最小配置如下：

```go
&proto.UIItem{
    Id: 257631,
    Type: proto.ItemType_ItemTypeHead,  // 根据实际部位设置
    Stats: stats.Stats{
        // 只填你知道的属性值
        stats.Strength: 100,
        stats.Stamina: 150,
    }.ToFloatArray(),
    Ilvl: 200,  // 物品等级
    Quality: proto.ItemQuality_ItemQualityEpic,
}
```

其他字段（Name、Icon等）可以留空，模拟器会使用默认值。

## 特殊效果处理

如果装备有特殊效果（如触发技能、套装效果等），目前无法直接通过 `ItemOverrides` 添加。你可以：

1. **手动折算为属性**：将特殊效果的影响折算成等效的属性值
   - 例如：触发技能增加10%伤害 → 可以折算为增加相应的攻击强度或法术强度

2. **后续扩展**：如果需要支持特殊效果，需要修改模拟器的核心代码，这需要更深入的工作

## 示例：完整的时光服装备配置

```go
// tools/database/overrides.go

var ItemOverrides = []*proto.UIItem{
    // 从你的插件JSON中提取的装备
    {
        Id: 257631,
        Name: "时光重铸头盔",
        Type: proto.ItemType_ItemTypeHead,
        ArmorType: proto.ArmorType_ArmorTypePlate,
        Stats: stats.Stats{
            stats.Strength: 100,
            stats.Stamina: 150,
            stats.AttackPower: 50,
            stats.MeleeCrit: 30,
        }.ToFloatArray(),
        Ilvl: 200,
        Quality: proto.ItemQuality_ItemQualityEpic,
    },
    {
        Id: 259904,
        Name: "时光重铸护腕",
        Type: proto.ItemType_ItemTypeWrist,
        ArmorType: proto.ArmorType_ArmorTypePlate,
        Stats: stats.Stats{
            stats.Strength: 50,
            stats.Stamina: 75,
            stats.AttackPower: 25,
        }.ToFloatArray(),
        Ilvl: 200,
        Quality: proto.ItemQuality_ItemQualityEpic,
    },
    // ... 添加更多装备
}

var GemOverrides = []*proto.UIGem{
    {
        Id: 41398,
        Color: proto.GemColor_GemColorRed,
        Stats: stats.Stats{
            stats.Strength: 20,
        }.ToFloatArray(),
        Quality: proto.ItemQuality_ItemQualityEpic,
    },
    {
        Id: 40013,
        Color: proto.GemColor_GemColorBlue,
        Stats: stats.Stats{
            stats.Stamina: 30,
        }.ToFloatArray(),
        Quality: proto.ItemQuality_ItemQualityEpic,
    },
    // ... 添加更多宝石
}
```

## 注意事项

1. **ID冲突**：确保自定义ID不与现有数据库中的ID冲突
2. **属性合理性**：尽量根据物品等级设置合理的属性值
3. **类型匹配**：确保 `Type`、`ArmorType`、`WeaponType` 等字段与实际装备匹配
4. **重新生成**：每次修改后都需要重新生成数据库才能生效

## 快速开始

1. 打开 `tools/database/overrides.go`
2. 在 `ItemOverrides` 数组中添加你的装备
3. 运行 `make items` 重新生成数据库
4. 测试导入功能

如果遇到问题，可以查看生成过程中的错误信息，通常是因为缺少必需字段或字段值不正确。
