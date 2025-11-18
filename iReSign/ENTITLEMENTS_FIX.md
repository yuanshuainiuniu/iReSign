# Extension Entitlements 修复说明

## 修复日期
2025年11月17日

## 问题描述

重签名后的IPA在安装时出现以下错误：
```
Error: 0xe8008018 (The identity used to sign the executable is no longer valid.)
Failed to verify code signature
```

## 根本原因

**Extension缺少正确的Entitlements文件导致签名验证失败**

iOS Extension需要自己独立的entitlements文件，这个文件包含了Extension的权限和能力配置。原代码只为主应用生成了entitlements，Extension在签名时没有使用正确的entitlements，导致：

1. Extension的签名无效
2. 系统无法验证Extension的权限
3. 安装时签名验证失败

## 技术细节

### iOS签名验证流程
```
安装IPA
    ↓
验证主应用签名
    ↓
验证Extension签名 ← 这里失败！
    ↓
- 检查证书有效性
- 检查配置文件匹配
- 检查entitlements正确性 ← Extension entitlements缺失
    ↓
签名验证失败 → 0xe8008018错误
```

### Entitlements的作用

Entitlements定义了应用和Extension的能力和权限：
- App Groups（应用组共享）
- Keychain Access Group（钥匙串访问）
- Associated Domains（关联域名）
- Push Notifications（推送通知）
- Extension capabilities（扩展能力）

**Extension必须有自己的entitlements**，因为：
1. Extension和主应用是独立的代码签名单元
2. Extension可能有不同的权限和能力
3. 签名验证时会单独验证Extension的entitlements

## 解决方案

### 1. 添加Extension Entitlements管理

**新增数据结构：**
```objective-c
NSMutableDictionary *extensionEntitlements; // 存储每个Extension的entitlements路径
```

### 2. 实现Extension Entitlements生成

**新增方法：**
```objective-c
- (void)generateEntitlementsForExtension:(NSString *)extensionName 
                    withProvisioningPath:(NSString *)provisioningPath
```

**功能：**
1. 从Extension的配置文件中提取entitlements
2. 使用`security cms -D`命令解析mobileprovision文件
3. 提取Entitlements字典
4. 保存为独立的plist文件
5. 存储路径供签名时使用

### 3. 修改签名流程

**修改signFile方法：**
- 检测当前签名的是主应用还是Extension
- Extension使用对应的entitlements文件
- 主应用使用主应用的entitlements文件

**签名逻辑：**
```objective-c
BOOL isExtension = [[filePath pathExtension] isEqualToString:@"appex"];

if (isExtension) {
    // 使用Extension专用的entitlements
    entitlementsPath = [extensionEntitlements objectForKey:extensionName];
} else {
    // 使用主应用的entitlements
    entitlementsPath = [entitlementField stringValue];
}
```

### 4. 自动生成Entitlements

**两种情况：**

1. **自定义配置文件** - Extension配置了新的mobileprovision
   - 复制配置文件后立即生成entitlements
   - 从新配置文件中提取权限

2. **保留原配置文件** - Extension未配置新的mobileprovision
   - 从现有的embedded.mobileprovision生成entitlements
   - 确保Extension仍然有正确的entitlements

## 完整的签名流程（修复后）

```
1. 解压IPA
    ↓
2. 扫描Extensions
    ↓
3. 配置Extensions (可选)
    ↓
4. 复制配置文件
    ├─ 主应用: embedded.mobileprovision
    └─ Extensions: 每个Extension的embedded.mobileprovision
    ↓
5. 生成Entitlements
    ├─ 主应用: entitlements.plist
    └─ Extensions: entitlements_ExtensionName.plist (为每个Extension生成)
    ↓
6. 代码签名 (按顺序)
    ├─ Extension Frameworks (使用对应Extension entitlements)
    ├─ Extensions (使用对应Extension entitlements) ✓
    ├─ Main App Frameworks (使用主应用entitlements)
    └─ Main App (使用主应用entitlements)
    ↓
7. 打包IPA
```

## 修改的代码

### iReSignAppDelegate.h
```objective-c
// 新增
NSMutableDictionary *extensionEntitlements;
```

### iReSignAppDelegate.m

**新增方法：**
```objective-c
- (void)generateEntitlementsForExtension:(NSString *)extensionName 
                    withProvisioningPath:(NSString *)provisioningPath;
```

**修改方法：**
- `scanForExtensions` - 清理entitlements字典
- `doExtensionsProvisioning` - 为每个Extension生成entitlements
- `signFile:` - 使用Extension对应的entitlements

## 日志输出

修复后的详细日志：
```
Generating entitlements for extension: NotificationExtension.appex
✓ Generated entitlements for NotificationExtension.appex: /tmp/.../entitlements_NotificationExtension.plist

Codesigning .../NotificationExtension.appex
Using custom entitlements for extension NotificationExtension.appex: /tmp/.../entitlements_NotificationExtension.plist
Adding entitlements argument: /tmp/.../entitlements_NotificationExtension.plist
```

## 关键改进点

### 1. 自动化
- 自动为所有Extension生成entitlements
- 无需手动准备Extension的entitlements文件
- 自动从配置文件中提取正确的权限

### 2. 灵活性
- 支持自定义配置文件的Extension
- 支持保留原配置文件的Extension
- 两种情况都能正确生成entitlements

### 3. 正确性
- Extension使用专用的entitlements
- 不会混淆主应用和Extension的权限
- 符合iOS签名验证要求

### 4. 可靠性
- 详细的日志输出便于调试
- 错误处理机制完善
- 验证文件生成成功

## 测试建议

### 测试场景1：带通知Extension的应用
1. 准备包含Notification Extension的IPA
2. 配置主应用和Extension的配置文件
3. 重签名并安装
4. 验证：
   - 主应用能正常启动
   - 通知功能正常
   - 无签名错误

### 测试场景2：App Groups共享
1. 准备使用App Groups的应用和Extension
2. 确保配置文件包含正确的App Groups
3. 重签名并安装
4. 验证：
   - 主应用和Extension能共享数据
   - App Groups entitlement正确

### 测试场景3：多个Extension
1. 准备包含多个Extension的应用
2. 为每个Extension配置不同的配置文件
3. 重签名并安装
4. 验证：
   - 每个Extension都有独立的entitlements
   - 所有Extension都能正常工作

## 错误排查

### 如果仍然出现签名错误

1. **检查日志输出**
```bash
# 查看entitlements是否生成
✓ Generated entitlements for ExtensionName.appex

# 查看是否使用了正确的entitlements
Using custom entitlements for extension ExtensionName.appex
```

2. **验证entitlements文件**
```bash
# 查看生成的entitlements
cat /tmp/.../entitlements_ExtensionName.plist
```

3. **检查配置文件**
```bash
# 验证配置文件包含entitlements
security cms -D -i extension.mobileprovision | grep -A 20 Entitlements
```

4. **验证签名**
```bash
# 检查Extension签名
codesign -d --entitlements - Extension.appex
```

## 向后兼容性

✓ 完全向后兼容
✓ 不影响不包含Extension的应用
✓ 不影响现有的签名流程
✓ 自动处理Extension的entitlements

## 相关错误代码

- **0xe8008018**: The identity used to sign the executable is no longer valid
  - 原因：签名验证失败
  - 解决：确保Extension有正确的entitlements

- **0xe8008015**: A valid provisioning profile for this executable was not found
  - 原因：配置文件不匹配
  - 解决：确保配置文件的Bundle ID匹配

- **0xe8008016**: The executable was signed with invalid entitlements
  - 原因：entitlements不正确
  - 解决：从配置文件正确提取entitlements

## 总结

此修复解决了Extension签名验证失败的核心问题，通过：
1. ✅ 为每个Extension生成独立的entitlements
2. ✅ 在签名时正确使用Extension的entitlements
3. ✅ 自动化处理流程，减少手动配置
4. ✅ 完善的错误处理和日志输出

修复后，Extension能够通过iOS的签名验证，应用可以正常安装和运行。

