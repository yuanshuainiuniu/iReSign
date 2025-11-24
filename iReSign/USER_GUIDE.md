# iReSign 使用指南

## 🎯 快速开始

### 1. 基本操作
1. **选择 IPA 文件**：点击"Browse"按钮或直接拖拽 IPA 文件到输入框
2. **选择证书**：从下拉列表中选择签名证书
3. **选择 Provisioning Profile**：为主应用选择对应的 .mobileprovision 文件
4. **（可选）修改 Bundle ID**：勾选复选框并输入新的 Bundle ID
5. **点击 ReSign**：开始重签名流程

### 2. 管理扩展（App Extensions）

#### 步骤：
1. 选择包含扩展的 IPA 文件
2. 点击"管理扩展配置"按钮
3. 应用会自动检测 IPA 中的所有扩展
4. 为每个扩展配置：
   - **Provisioning Profile**：扩展专用的配置文件
   - **Bundle ID**：扩展的唯一标识符（通常格式：主应用ID.扩展名）
5. 点击"确定"保存配置

#### 示例：
```
主应用 Bundle ID:   com.company.myapp
扩展 1 Bundle ID:   com.company.myapp.shareextension
扩展 2 Bundle ID:   com.company.myapp.todaywidget
```

---

## 💡 新功能亮点

### ✨ 路径自动记忆
所有路径会自动保存，下次打开应用时自动填充：
- IPA 文件路径
- Provisioning Profile 路径  
- Entitlements 文件路径
- 所有扩展的配置

**效果**：无需每次都重新输入，大大提高工作效率！

### 🔍 提前检测扩展
无需启动签名流程就能预览和配置扩展：
- 点击"管理扩展配置"自动检测
- 即时配置所有扩展
- 配置自动保存供下次使用

### 📱 扩展 Bundle ID 管理
为每个扩展独立配置 Bundle ID：
- 自动修改每个扩展的 Info.plist
- 支持复杂的扩展层次结构
- 详细的修改日志

---

## 📋 完整工作流程

```
1. 打开应用（自动恢复上次配置）
   ↓
2. 选择 IPA 文件（路径自动保存）
   ↓
3. 点击"管理扩展配置"
   - 自动检测扩展
   - 显示之前保存的配置
   - 修改或确认配置
   ↓
4. 配置主应用参数
   - 选择证书
   - 选择 Provisioning Profile
   - （可选）修改 Bundle ID
   ↓
5. 点击 ReSign 开始签名
   - 主应用签名
   - 所有扩展自动签名
   - 打包生成新的 IPA
```

---

## ⚙️ 配置说明

### 主应用配置
| 项目 | 说明 | 必填 |
|------|------|------|
| Input File | IPA 或 xcarchive 文件 | ✅ |
| Signing Certificate | 代码签名证书 | ✅ |
| Provisioning Profile | 主应用的配置文件 | ❌* |
| Entitlements | 权限配置文件 | ❌ |
| Bundle ID | 应用包标识符 | ❌ |

*注：如果提供了 Provisioning Profile，会自动从中提取 Entitlements

### 扩展配置
| 项目 | 说明 | 必填 |
|------|------|------|
| Provisioning Profile | 扩展专用配置文件 | 推荐 |
| Bundle ID | 扩展包标识符 | 推荐 |

**提示**：如果不配置扩展的 Provisioning Profile，将使用原有的配置文件。

---

## 🔧 高级技巧

### 1. 批量处理相似应用
配置一次后，处理相同类型的应用时：
- IPA 路径会记住上次的目录
- Provisioning Profile 会自动填充
- 扩展配置会自动匹配同名扩展

### 2. Bundle ID 规则
扩展的 Bundle ID 必须以主应用的 Bundle ID 为前缀：
```
✅ 正确：
   主应用: com.company.app
   扩展:   com.company.app.extension

❌ 错误：
   主应用: com.company.app
   扩展:   com.other.extension
```

### 3. Provisioning Profile 要求
- 主应用和扩展必须使用匹配的证书
- 扩展的 Provisioning Profile 必须包含扩展的 Bundle ID
- 建议使用通配符配置文件（*.extension）来匹配多个扩展

---

## 🐛 常见问题

### Q: 为什么检测不到扩展？
A: 请确保：
1. IPA 文件格式正确
2. IPA 包含 `Payload/*.app/PlugIns/*.appex` 目录
3. 文件路径有效且可访问

### Q: 签名失败怎么办？
A: 检查以下项：
1. 证书是否有效且未过期
2. Provisioning Profile 与证书是否匹配
3. Bundle ID 是否与 Provisioning Profile 一致
4. 扩展的 Bundle ID 是否以主应用 Bundle ID 为前缀

### Q: 如何清除保存的配置？
A: 可以通过以下方式：
1. 手动清空输入框
2. 选择新的文件会覆盖旧配置
3. 删除应用的偏好设置文件（高级用户）

### Q: 支持哪些扩展类型？
A: 支持所有标准的 iOS 扩展类型，包括：
- Today Widget
- Share Extension
- Action Extension
- Photo Editing Extension
- Watch App Extension
- 等等...

---

## 📝 日志和调试

### 查看日志
应用运行时会在控制台输出详细日志，包括：
- 扩展检测结果
- 文件操作状态
- 签名过程信息
- 错误详情

### 日志位置
在 Xcode 或 Console.app 中查看日志输出。

### 关键日志标记
- `✓` - 操作成功
- `✗` - 操作失败
- `WARNING` - 警告信息
- `ERROR` - 错误信息

---

## 🎨 界面说明

### 主窗口
```
┌─────────────────────────────────────┐
│ Input File:      [IPA路径]  [Browse] │
│ Signing Cert:    [证书下拉列表]       │
│ Provisioning:    [Profile路径] [...]  │
│ Entitlements:    [权限路径]   [...]   │
│ Bundle ID:       □ [新Bundle ID]     │
│                                       │
│ [管理扩展配置]              [ReSign]  │
└─────────────────────────────────────┘
```

### 扩展配置对话框
```
┌─────────────────────────────────────┐
│ 管理扩展配置                          │
│ 检测到 2 个扩展...                    │
│                                       │
│ ShareExtension.appex                 │
│ Provisioning: [路径............] [...] │
│ Bundle ID:    [com.app.share......]  │
│                                       │
│ TodayWidget.appex                    │
│ Provisioning: [路径............] [...] │
│ Bundle ID:    [com.app.widget.....]  │
│                                       │
│              [确定]      [取消]       │
└─────────────────────────────────────┘
```

---

## 📚 补充说明

### 关于 Provisioning Profile
- **开发证书**：用于开发和测试
- **发布证书**：用于 Ad-Hoc、Enterprise 或 App Store 分发
- 确保 Profile 未过期
- Profile 必须包含应用的 Bundle ID

### 关于 Entitlements
- 可以从 Provisioning Profile 自动提取
- 也可以手动提供 .plist 文件
- 包含应用权限声明（如推送通知、iCloud 等）

### 关于证书
- 证书从系统钥匙串中读取
- 必须有对应的私钥
- 证书类型必须是"iPhone Distribution"或"iPhone Developer"

---

**需要帮助？** 查看项目的 README.md 或提交 Issue

**版本**：当前版本  
**更新时间**：2025-11-18

