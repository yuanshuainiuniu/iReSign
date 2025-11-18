# iReSign Extension 支持更新说明

## 概述
此更新为 iReSign 添加了对多个 iOS App Extension 的配置文件签名支持。现在您可以为主应用和每个扩展分别选择不同的配置文件进行重签名。

## 新增功能

### 1. 自动检测扩展
- 在解压 IPA 或处理 xcarchive 文件后，自动扫描应用包中的所有扩展（.appex）
- 扫描位置：`Payload/YourApp.app/PlugIns/*.appex`
- 自动检测扩展中的 Frameworks 并正确签名

### 2. Extension 配置管理
- 新增"管理扩展配置"（Manage Extensions）按钮
- 当检测到扩展时，会自动弹出提示询问是否配置
- 可以为每个扩展单独选择配置文件（.mobileprovision）

### 3. 独立的配置文件支持
- 主应用使用原有的配置文件选择框
- 每个扩展可以配置自己的 mobileprovision 文件
- 支持跳过扩展配置（使用原有配置文件）

## 使用方法

### 方式一：自动配置（推荐）
1. 选择 IPA 文件
2. 点击"重新签名!"（ReSign!）按钮
3. 应用解压后，如果检测到扩展，会弹出提示框
4. 点击"Configure"按钮进入扩展配置界面
5. 为每个扩展选择对应的配置文件
6. 点击"OK"保存配置，签名流程将自动继续

### 方式二：手动配置
1. 选择 IPA 文件
2. 点击"管理扩展配置"（Manage Extensions）按钮
3. 如果还未解压，会提示先点击 ReSign
4. 在配置界面中为每个扩展选择配置文件
5. 配置完成后，点击"重新签名!"开始签名

## 技术实现

### 核心修改
1. **头文件 (iReSignAppDelegate.h)**
   - 添加 `extensions` 数组存储扫描到的扩展路径
   - 添加 `extensionProvisioningProfiles` 字典存储扩展与配置文件的映射
   - 添加 `manageExtensions:` 方法和相关 UI 控件

2. **实现文件 (iReSignAppDelegate.m)**
   - `scanForExtensions`: 扫描应用包中的所有扩展
   - `doExtensionsProvisioning`: 为扩展安装配置文件
   - `manageExtensions:`: 显示扩展配置管理界面
   - 修改 `doCodeSigning`: 确保扩展及其 frameworks 被正确签名
   - 修改 `checkUnzip` 和 `checkCopy`: 在解压完成后自动检测扩展

3. **UI 界面 (MainMenu.xib)**
   - 添加"管理扩展配置"按钮（英文和中文版本）
   - 按钮位于左下角，ReSign 按钮左侧

### 签名顺序
1. Extension Frameworks
2. Extensions (.appex)
3. Main App Frameworks
4. Main App

## 注意事项

1. **配置文件匹配**
   - 确保为每个扩展选择的配置文件与扩展的 Bundle ID 匹配
   - 如果不配置扩展的配置文件，将保留原有的配置文件

2. **证书要求**
   - 所有扩展和主应用可以使用同一个证书
   - 配置文件需要包含正确的 App ID（支持通配符）

3. **兼容性**
   - 完全向后兼容，不影响不包含扩展的应用的签名流程
   - 如果应用没有扩展，使用方式与之前完全相同

## 示例场景

### 包含通知扩展的应用
```
MyApp.ipa
└── Payload/
    └── MyApp.app/
        ├── embedded.mobileprovision (主应用配置)
        └── PlugIns/
            └── NotificationExtension.appex/
                └── embedded.mobileprovision (扩展配置)
```

使用此更新后，您可以：
- 为 MyApp.app 选择主应用的配置文件
- 为 NotificationExtension.appex 选择扩展的配置文件
- 两者可以使用不同的 App ID 和 provisioning profile

## 日志输出

在控制台中可以看到以下相关日志：
```
Found extension: NotificationExtension.appex
Found 1 extension(s)
Provisioning profile set for extension: NotificationExtension.appex
Found extension framework: /path/to/framework
Extensions provisioning completed
```

## 故障排除

### 扩展未被检测
- 确保扩展位于 `PlugIns` 目录下
- 确保扩展的扩展名为 `.appex`

### 签名失败
- 检查配置文件是否与 Bundle ID 匹配
- 确认证书有效且包含在配置文件中
- 查看控制台日志获取详细错误信息

### 配置文件不生效
- 确保在点击 ReSign 前完成扩展配置
- 或者在解压后的提示框中选择配置

## 开发者信息

此更新保持了原项目的架构和代码风格，所有修改都经过测试并确保不会破坏现有功能。

主要新增方法：
- `scanForExtensions`
- `doExtensionsProvisioning`
- `manageExtensions:`
- `browseForExtensionProfile:`

修改的方法：
- `applicationDidFinishLaunching:`
- `checkUnzip:`
- `checkCopy:`
- `doProvisioning`
- `doCodeSigning`

