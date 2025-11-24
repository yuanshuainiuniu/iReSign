# 签名安装失败排查指南

## 错误信息
```
Failed to verify code signature: 0xe8008015
(A valid provisioning profile for this executable was not found.)
```

## 可能的原因和解决方案

### 1. 主应用 Provisioning Profile 问题

#### 检查步骤：
```bash
# 使用提供的脚本检查签名后的 IPA
cd /Users/marshal/Documents/git/iReSign/iReSign
./check_signed_ipa.sh "/Users/marshal/Downloads/IOS_COMMON_BUNDLE_INTEGRATION_VM_18941714/Zhixing_Release-Inhouse_18941714_05-30_15-16-resigned.ipa"
```

#### 常见问题：

**A. Bundle ID 不匹配**
- **症状**：Profile 中的 Bundle ID 与应用的 Bundle ID 不一致
- **解决**：
  1. 确认 Provisioning Profile 支持的 Bundle ID
  2. 如果修改了 Bundle ID，确保 Provisioning Profile 支持新的 Bundle ID
  3. 可以使用通配符 Profile（如 `com.company.*`）

**B. Provisioning Profile 类型不正确**
- **开发证书** 需要 **Development Profile**
- **发布证书** 需要 **Distribution Profile**（Ad-Hoc、Enterprise 或 App Store）

**C. 设备 UDID 不在 Profile 中**
- **症状**：使用 Development 或 Ad-Hoc Profile 时，目标设备不在允许列表中
- **解决**：
  1. 检查 Profile 是否包含目标设备的 UDID
  2. 如果没有，重新生成包含该设备的 Profile
  3. 或使用 Enterprise Profile（无设备限制）

**D. Provisioning Profile 过期**
- **解决**：重新生成或更新 Provisioning Profile

### 2. 证书与 Profile 不匹配

#### 检查方法：
```bash
# 查看 Profile 的证书信息
security cms -D -i /path/to/your.mobileprovision | plutil -p - | grep -A 20 DeveloperCertificates

# 查看系统中的签名证书
security find-identity -v -p codesigning
```

#### 解决方案：
- 确保选择的证书在 Provisioning Profile 的证书列表中

### 3. 扩展配置问题

即使主应用签名正确，扩展的签名问题也会导致安装失败。

#### 检查扩展：
- 每个扩展都需要有自己的 `embedded.mobileprovision`
- 扩展的 Bundle ID 必须以主应用 Bundle ID 为前缀
- 扩展的 Provisioning Profile 必须支持扩展的 Bundle ID

### 4. iReSign 日志检查

在 iReSign 运行时，查看控制台日志（Console.app），搜索 "iReSign" 进程的日志。

#### 关键日志点：

1. **Provisioning Profile 标识符**：
```
Mobileprovision identifier: com.company.app
```

2. **标识符匹配检查**：
```
Identifiers match  // 应该看到这个
```
或
```
Product identifiers don't match  // 如果看到这个，说明有问题
```

3. **扩展配置日志**：
```
========== Starting Extensions Provisioning ==========
Total extensions found: 3
Extension paths: (...)
Configured provisioning profiles: {...}
```

### 5. 快速诊断检查清单

使用以下命令快速检查签名后的应用：

```bash
# 1. 解压 IPA
unzip -q resigned.ipa -d temp_check

# 2. 检查主应用的 embedded.mobileprovision
ls -la "temp_check/Payload/*.app/embedded.mobileprovision"

# 3. 查看 Profile 信息
security cms -D -i "temp_check/Payload/*.app/embedded.mobileprovision" | grep -E "application-identifier|TeamName|ExpirationDate"

# 4. 检查应用 Bundle ID
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "temp_check/Payload/*.app/Info.plist"

# 5. 验证签名
codesign -vvv "temp_check/Payload/*.app"

# 6. 深度验证（包括扩展）
codesign -vvv --deep --strict "temp_check/Payload/*.app"

# 7. 清理
rm -rf temp_check
```

## 推荐的排查步骤

### 步骤 1：运行诊断脚本
```bash
cd /Users/marshal/Documents/git/iReSign/iReSign
./check_signed_ipa.sh "<path_to_resigned.ipa>"
```

### 步骤 2：检查 iReSign 日志
1. 打开 Console.app
2. 搜索 "iReSign"
3. 查看最近一次签名操作的日志
4. 特别注意：
   - `Identifiers match` 或 `Product identifiers don't match`
   - 扩展配置相关的日志
   - 任何错误或警告信息

### 步骤 3：验证 Provisioning Profile

```bash
# 查看 Profile 详细信息
security cms -D -i /path/to/your.mobileprovision > profile.plist
open profile.plist

# 检查以下内容：
# - application-identifier (Bundle ID)
# - ExpirationDate (过期时间)
# - ProvisionedDevices (设备列表，如果是 Development 或 Ad-Hoc)
# - TeamName (团队名称)
# - DeveloperCertificates (证书列表)
```

### 步骤 4：重新签名尝试

如果发现问题，尝试以下操作：

1. **如果 Bundle ID 不匹配**：
   - 取消勾选"修改 Bundle ID"选项
   - 或确保新的 Bundle ID 与 Profile 匹配

2. **如果证书不匹配**：
   - 重新选择正确的证书
   - 确保证书对应的 Provisioning Profile

3. **如果扩展配置有问题**：
   - 点击"管理扩展配置"
   - 为每个扩展配置正确的 Provisioning Profile
   - 确保扩展的 Bundle ID 以主应用 Bundle ID 为前缀

4. **如果 Profile 过期**：
   - 在 Apple Developer 网站重新生成 Provisioning Profile
   - 下载并使用新的 Profile

## 常见错误代码

- `0xe8008015`: 找不到有效的 Provisioning Profile
- `0xe8008016`: 设备不在 Profile 的允许列表中
- `0xe8008017`: Provisioning Profile 已过期
- `0xe8008018`: 证书不匹配

## 需要更多帮助？

如果问题仍未解决，请提供以下信息：

1. 诊断脚本的完整输出
2. iReSign 控制台日志（包含 "Mobileprovision identifier" 和 "Identifiers match" 的部分）
3. 您使用的证书类型（Development/Distribution）
4. Provisioning Profile 类型（Development/Ad-Hoc/Enterprise/App Store）
5. 是否修改了 Bundle ID
6. 应用是否包含扩展，以及扩展配置情况

