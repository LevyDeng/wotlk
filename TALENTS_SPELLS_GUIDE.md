# 天赋和技能自定义指南

## 概述

模拟器中的天赋和技能实现方式与装备不同：

- **装备**: 从数据库（`db.bin`）读取，可以通过 `ItemOverrides` 自定义
- **天赋**: 硬编码在代码中，通过 JSON 配置文件定义
- **技能**: 完全硬编码在 Go 代码中，包含伤害计算、效果等逻辑

## 天赋系统

### 天赋配置位置

天赋配置存储在以下位置：

1. **JSON 配置文件**: `ui/core/talents/trees/`
   - `deathknight.json`
   - `druid.json`
   - `hunter.json`
   - `mage.json`
   - 等等...

2. **TypeScript 配置**: `ui/core/talents/`
   - `deathknight.ts` - 雕文配置
   - `druid.ts`
   - 等等...

3. **Go 代码**: `sim/{class}/`
   - `talents.go` - 天赋效果实现
   - `{class}.go` - 主类实现

### 天赋配置结构

JSON 文件格式示例（`deathknight.json`）：
```json
[
  {
    "name": "Blood",
    "backgroundUrl": "...",
    "talents": [
      {
        "fieldName": "butchery",
        "location": {
          "rowIdx": 0,
          "colIdx": 0
        },
        "spellIds": [48979, 49483],
        "maxPoints": 2
      }
    ]
  }
]
```

### 天赋效果实现

天赋的实际效果在 Go 代码中实现，例如 `sim/deathknight/talents.go`：

```go
func (dk *Deathknight) ApplyTalents() {
    // 根据天赋点数应用效果
    dk.AddStat(stats.MeleeCrit, core.CritRatingPerCritChance*1*float64(dk.Talents.Cruelty))
    // ...
}
```

## 技能系统

### 技能实现位置

技能完全在 Go 代码中实现：

- **技能定义**: `sim/{class}/{spell_name}.go`
- **核心框架**: `sim/core/spell.go`
- **伤害计算**: `sim/core/spell_result.go`

### 技能实现示例

以死亡打击（Death Strike）为例（`sim/deathknight/death_strike.go`）：

```go
func (dk *Deathknight) newDeathStrikeSpell(isMH bool) *core.Spell {
    conf := core.SpellConfig{
        ActionID:    DeathStrikeActionID,
        SpellSchool: core.SpellSchoolPhysical,
        RuneCost: core.RuneCostOptions{
            FrostRuneCost:  1,
            UnholyRuneCost: 1,
            RunicPowerGain: 15 + 2.5*float64(dk.Talents.Dirge),
        },
        DamageMultiplier: .75 * dk.improvedDeathStrikeDamageBonus(),
        ApplyEffects: func(sim *core.Simulation, target *core.Unit, spell *core.Spell) {
            baseDamage := 297 + spell.Unit.MHNormalizedWeaponDamage(sim, spell.MeleeAttackPower())
            // ... 伤害计算逻辑
        },
    }
    return dk.RegisterSpell(conf)
}
```

## 自定义方式

### 1. 修改天赋配置（JSON）

**可以修改**：
- 天赋位置（`rowIdx`, `colIdx`）
- 天赋 SpellIds
- 最大点数（`maxPoints`）
- 字段名（`fieldName`）

**修改步骤**：
1. 编辑 `ui/core/talents/trees/{class}.json`
2. 修改对应的天赋配置
3. 重新编译前端（`make` 或 `npm run build`）

**限制**：
- `fieldName` 必须与 Go 代码中的结构体字段名匹配
- SpellIds 必须对应游戏中的实际法术ID

### 2. 修改天赋效果（Go 代码）

**可以修改**：
- 天赋提供的属性加成
- 天赋的数值效果

**修改步骤**：
1. 编辑 `sim/{class}/talents.go`
2. 修改 `ApplyTalents()` 函数中的逻辑
3. 重新编译 Go 代码

**示例**：
```go
func (dk *Deathknight) ApplyTalents() {
    // 修改某个天赋的效果
    if dk.Talents.SomeTalent > 0 {
        dk.AddStat(stats.AttackPower, 50*float64(dk.Talents.SomeTalent))
    }
}
```

### 3. 修改技能（Go 代码）

**可以修改**：
- 技能伤害
- 技能冷却时间
- 技能消耗
- 技能效果

**修改步骤**：
1. 找到对应的技能文件（如 `sim/deathknight/death_strike.go`）
2. 修改 `SpellConfig` 中的参数
3. 修改 `ApplyEffects` 中的伤害计算
4. 重新编译

**示例**：
```go
// 修改基础伤害
baseDamage := 400 + // 原来是 297
    bonusBaseDamage +
    spell.Unit.MHNormalizedWeaponDamage(sim, spell.MeleeAttackPower())

// 修改伤害倍率
DamageMultiplier: 1.0 * // 原来是 0.75
    dk.improvedDeathStrikeDamageBonus(),
```

### 4. 添加新天赋

**步骤**：
1. 在 JSON 文件中添加天赋配置
2. 在 Go 结构体中添加字段（`proto/{class}.proto`）
3. 重新生成 proto 代码（`make proto`）
4. 在 `talents.go` 中实现效果

### 5. 添加新技能

**步骤**：
1. 创建新的技能文件（如 `sim/deathknight/new_spell.go`）
2. 实现技能配置和效果
3. 在类初始化中注册技能
4. 重新编译

## 与装备自定义的对比

| 特性 | 装备 | 天赋/技能 |
|------|------|-----------|
| 数据来源 | 数据库（db.bin） | 代码硬编码 |
| 自定义方式 | ItemOverrides | 修改代码 |
| 修改难度 | 简单（添加配置） | 复杂（需要编程） |
| 需要重新编译 | 是（生成数据库） | 是（编译代码） |
| 灵活性 | 中等（只能改属性） | 高（可以改任何逻辑） |

## 时光服自定义建议

### 如果只需要调整数值

1. **天赋数值调整**：
   - 修改 `sim/{class}/talents.go` 中的数值
   - 例如：`dk.AddStat(stats.AttackPower, 100*float64(dk.Talents.SomeTalent))` 改为 `200*...`

2. **技能伤害调整**：
   - 修改技能文件中的基础伤害或倍率
   - 例如：`baseDamage := 297` 改为 `baseDamage := 400`

### 如果需要添加新内容

1. **新天赋**：
   - 需要修改 JSON、proto、Go 代码
   - 工作量较大，需要理解代码结构

2. **新技能**：
   - 需要实现完整的技能逻辑
   - 工作量很大，需要深入理解模拟器框架

## 注意事项

1. **Proto 文件**: 修改天赋结构需要更新 `proto/{class}.proto`，然后运行 `make proto`
2. **前端同步**: 修改 JSON 配置后需要重新编译前端
3. **测试**: 修改后需要充分测试，确保不影响其他功能
4. **版本控制**: 建议使用 Git 管理修改，方便回滚

## 总结

- **天赋和技能不是从数据库读取的**，而是硬编码在代码中
- **可以自定义**，但需要修改代码，不像装备那样简单
- **对于时光服**，如果只是数值调整，相对简单；如果要添加新内容，需要更多工作
- **建议**：先尝试修改现有天赋/技能的数值，如果满足需求就不需要添加新内容
