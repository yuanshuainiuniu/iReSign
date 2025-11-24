# iReSign 功能改进总结

## 概览
本次更新为 iReSign 添加了多项实用功能，极大提升了用户体验，特别是在处理包含扩展（App Extensions）的应用时。

---

## 主要功能改进

### 1. 扩展预览和管理功能 ✨

#### 问题背景
之前版本中，点击"管理扩展配置"按钮时会提示：
> "Extensions will be detected after you click ReSign. You can then manage their provisioning profiles during the signing process."

这意味着用户必须先点击 ReSign 开始签名流程后才能配置扩展。

#### 改进方案
- ✅ **提前检测扩展**：选择 IPA 文件后，点击"管理扩展配置"会自动临时解压 IPA 文件并扫描扩展
- ✅ **即时配置**：无需启动签名流程就能预先配置所有扩展的 Provisioning Profile 和 Bundle ID
- ✅ **支持多种格式**：同时支持 `.ipa` 和 `.xcarchive` 格式

#### 实现细节
新增 `previewIPAForExtensions` 方法：
- 在临时目录解压 IPA 文件
- 扫描 `Payload/*.app/PlugIns/` 目录查找 `.appex` 扩展
- 扫描完成后自动清理临时文件
- 将扩展名存储在内存中供后续配置使用

---

### 2. 扩展 Bundle ID 配置功能 📱

#### 新增功能
为每个扩展添加了 Bundle ID 配置选项，符合 iOS 应用的实际需求。

#### 特性说明
- **独立配置**：每个扩展都可以配置独立的 Bundle ID
- **自动应用**：在签名过程中自动修改每个扩展的 `Info.plist` 文件
- **日志记录**：详细记录每个扩展的 Bundle ID 修改情况

#### 对话框改进
扩展管理对话框现在包含：

```
扩展名称.appex
├─ Provisioning:  [路径输入框]  [浏览]
└─ Bundle ID:     [Bundle ID 输入框]
```

每个扩展占用 80 像素高度，布局更加清晰合理。

---

### 3. 路径记忆功能 💾

#### 新增的记忆项
应用现在会自动保存并在下次启动时恢复以下路径：

1. **IPA 文件路径** (`IPA_PATH`)
2. **Provisioning Profile 路径** (`MOBILEPROVISION_PATH`)  
3. **Entitlements 文件路径** (`ENTITLEMENT_PATH`)
4. **扩展的 Provisioning Profile 路径** (`EXTENSION_PROVISIONING_PROFILES`)
5. **扩展的 Bundle ID** (`EXTENSION_BUNDLE_IDS`)

#### 保存时机
路径会在以下时机自动保存：
- ✅ 通过"浏览"按钮选择文件后立即保存
- ✅ 点击"ReSign"按钮时保存所有配置
- ✅ 在"管理扩展配置"对话框点击"确定"后保存扩展配置

#### 用户体验提升
- 无需每次都重新输入常用路径
- 扩展配置会自动匹配相同名称的扩展
- 减少重复操作，提高工作效率

---

## 技术实现细节

### 数据结构
```objective-c
// 新增的数据结构
NSMutableDictionary *extensionBundleIDs;  // 存储扩展的 Bundle ID
```

### 关键方法

#### 1. `previewIPAForExtensions`
```objective-c
- (void)previewIPAForExtensions;
```
- 临时解压 IPA/xcarchive 文件
- 扫描并记录所有扩展
- 清理临时文件

#### 2. `doExtensionsBundleIDChange`
```objective-c
- (BOOL)doExtensionsBundleIDChange;
```
- 遍历所有扩展
- 修改每个扩展的 Info.plist 中的 Bundle ID
- 返回操作成功状态

#### 3. 配置持久化
使用 `NSUserDefaults` 存储配置：
```objective-c
[defaults setObject:extensionProvisioningProfiles forKey:@"EXTENSION_PROVISIONING_PROFILES"];
[defaults setObject:extensionBundleIDs forKey:@"EXTENSION_BUNDLE_IDS"];
[defaults setValue:fileNameOpened forKey:@"IPA_PATH"];
[defaults synchronize];
```

---

## 使用流程

### 标准工作流程
1. **启动应用** - 自动恢复上次使用的路径
2. **选择 IPA 文件** - 通过浏览按钮或直接输入，路径自动保存
3. **管理扩展** - 点击"管理扩展配置"按钮
   - 应用自动检测 IPA 中的扩展
   - 为每个扩展配置：
     - Provisioning Profile 路径
     - Bundle ID
   - 配置自动保存供下次使用
4. **配置主应用** - 选择证书、Provisioning Profile、Bundle ID 等
5. **开始签名** - 点击 ReSign，自动处理主应用和所有扩展

### 扩展检测逻辑
```
选择 IPA 文件
    ↓
点击"管理扩展配置"
    ↓
临时解压到预览目录
    ↓
扫描 PlugIns/*.appex
    ↓
显示配置对话框（包含之前保存的配置）
    ↓
用户配置并保存
    ↓
清理临时文件
```

---

## 界面改进

### 扩展管理对话框
- **标题**：管理扩展配置
- **信息**：检测到 N 个扩展。请为每个扩展配置 Provisioning Profile 和 Bundle ID
- **按钮**：确定 / 取消（中文界面）

### 布局参数
- 对话框宽度：450 像素
- 每个扩展高度：80 像素
- Provisioning Profile 输入框：230 像素宽
- Bundle ID 输入框：315 像素宽
- 浏览按钮：80 像素宽

---

## 错误处理和日志

### 友好的错误提示
- **未选择文件**：提示用户"请先选择一个 IPA 文件以检测扩展"
- **无扩展**：提示"在此应用中未检测到任何扩展 (App Extensions)"
- **文件不存在**：提示"选定的文件不存在"
- **无效格式**：提示"请选择有效的 .ipa 或 .xcarchive 文件"

### 详细的日志记录
```
Found extension during preview: XXX.appex
Saved provisioning profile for XXX.appex: /path/to/profile
Saved Bundle ID for XXX.appex: com.company.app.extension
Extension configurations saved to preferences
✓ Updated Bundle ID for extension XXX.appex to com.company.app.extension
```

---

## 兼容性

### 系统要求
- macOS 10.9 或更高版本
- 支持 Apple Silicon (arm64) 和 Intel (x86_64)

### 文件格式
- ✅ IPA 文件 (`.ipa`)
- ✅ Xcode Archive (`.xcarchive`)
- ✅ Provisioning Profile (`.mobileprovision`)
- ✅ Property List (`.plist`)

---

## 升级建议

### 对于现有用户
1. 更新到新版本后，首次使用时需要重新配置路径
2. 配置一次后，后续使用将自动恢复所有设置
3. 如果之前保存了 Provisioning Profile 和 Entitlements 路径，这些设置会保留

### 最佳实践
1. **统一命名**：扩展名称保持一致，便于配置自动匹配
2. **定期检查**：确认保存的路径仍然有效
3. **批量处理**：如果要处理多个相似的应用，配置一次即可重复使用

---

## 未来改进方向

### 可能的功能增强
- [ ] 支持从已签名的 IPA 文件中提取配置
- [ ] 支持配置文件的导入/导出
- [ ] 为不同项目创建配置方案
- [ ] 批量处理多个 IPA 文件
- [ ] 扩展配置的模板功能

---

## 问题反馈

如果遇到问题或有功能建议，请通过以下方式反馈：
1. GitHub Issues
2. 项目邮箱
3. 查看日志文件定位问题

---

**版本**：本文档对应的代码改进已在当前构建中实现  
**最后更新**：2025-11-18

