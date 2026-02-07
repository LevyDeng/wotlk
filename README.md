# WoW WOTLK Simulator (Fork)

Fork 自 [wowsims/wotlk](https://github.com/wowsims/wotlk)。

## 使用方法

**前置**：需要代理（梯子），否则国内的可以不用看了。

### 1. 配置代理

在项目根目录的 `.env` 文件中设置代理，例如：

```env
HTTP_PROXY=http://127.0.0.1:7890
HTTPS_PROXY=http://127.0.0.1:7890
```
docker本身应该也需要设置代理
### 2. 启动服务

- **Windows**：`.\quick-test.ps1 start`
- **Linux / macOS**：`./quick-test.sh start`（未在 Linux/mac 下完整测试）

### 3. 添加自定义装备

1. **编辑 `tools/database/overrides.go`**

   - 在 **`ItemOverrides`** 中追加新装备，例如：

   ```go
   // 北境肩甲 (custom, DK plate shoulder)
   {
       Id:             257629,
       Name:           "北境肩甲",
       Type:           proto.ItemType_ItemTypeShoulder,
       ArmorType:      proto.ArmorType_ArmorTypePlate,
       Ilvl:           213,
       Quality:        proto.ItemQuality_ItemQualityEpic,
       SetName:        "北境",
       ClassAllowlist: []proto.Class{proto.Class_ClassDeathknight},
       Stats: stats.Stats{
           stats.Strength:  75,
           stats.Stamina:  85,
           stats.MeleeCrit: 43,
           stats.Expertise: 49,
           stats.Armor:    1723,
       }.ToFloatArray(),
       GemSockets: []proto.GemColor{
           proto.GemColor_GemColorYellow,
       },
       SocketBonus: stats.Stats{stats.Strength: 4}.ToFloatArray(),
   },
   ```

   - 在 **`ItemAllowList`** 中增加该装备的 ID：

   ```go
   257629: {}, // 北境肩甲 (custom override)
   ```

2. **重新生成数据并启动**

   ```powershell
   .\quick-test.ps1 stop    # 停止容器，避免冲突
   .\quick-test.ps1 items  # 重新生成装备数据
   .\quick-test.ps1 start  # 启动容器
   .\quick-test.ps1 ui     # 更新前端
   .\quick-test.ps1 server # 重新编译服务端
   ```

3. 浏览器打开 **http://localhost:3333**，使用字符串导入即可看到新增装备。

**提示**：可截图装备说明文字，交给 AI 生成对应的 `ItemOverrides` 条目。

### 4. 其他

- 自定义技能、天赋等仍在研究中，详见项目内相关文档。
