# 签名验证报告

**IPA 文件**: Zhixing_Release-Inhouse_18941714_05-30_15-16-resigned.ipa  
**验证时间**: 2025-11-18  
**验证结果**: ✅ **完全符合预期**

---

## 1. 主应用验证结果

| 项目 | 预期值 | 实际值 | 状态 |
|------|--------|--------|------|
| Bundle ID | `cn.suanya.zhixingHC` | `cn.suanya.zhixingHC` | ✅ 匹配 |
| 证书 | Apple Development: chaohong hou | Apple Development: chaohong hou (CKX4U5B8B5) | ✅ 正确 |
| Team ID | UNS8RSTG96 | UNS8RSTG96 | ✅ 正确 |
| Provisioning Profile | ✓ | embedded.mobileprovision 存在 | ✅ 正确 |
| Profile 过期时间 | - | 2026-08-26 | ✅ 未过期 |
| 设备数量 | - | 71 台设备 | ✅ Development Profile |
| 签名验证 | - | valid on disk | ✅ 通过 |

---

## 2. 扩展验证结果

### 扩展 1: zxNotificationService.appex

| 项目 | 预期值 | 实际值 | 状态 |
|------|--------|--------|------|
| Bundle ID | `cn.suanya.zhixingHC.zxNotificationService` | `cn.suanya.zhixingHC.zxNotificationService` | ✅ 匹配 |
| Profile UUID | `17e42b82-aa61-4044-8baa-047c4879afa2` | ✓ | ✅ 已配置 |
| embedded.mobileprovision | ✓ | 存在 | ✅ 正确 |
| 证书 | Apple Development: chaohong hou | Apple Development: chaohong hou (CKX4U5B8B5) | ✅ 正确 |
| Bundle ID 前缀 | 以主应用 Bundle ID 开头 | ✓ | ✅ 正确 |

### 扩展 2: zxWidgetExtension.appex (zxWidget)

| 项目 | 预期值 | 实际值 | 状态 |
|------|--------|--------|------|
| Bundle ID | `cn.suanya.zhixingHC.zxWidget` | `cn.suanya.zhixingHC.zxWidget` | ✅ 匹配 |
| Profile UUID | `10aaff01-4495-40f4-a311-9ea980762ddd` | ✓ | ✅ 已配置 |
| embedded.mobileprovision | ✓ | 存在 | ✅ 正确 |
| 证书 | Apple Development: chaohong hou | Apple Development: chaohong hou (CKX4U5B8B5) | ✅ 正确 |
| Bundle ID 前缀 | 以主应用 Bundle ID 开头 | ✓ | ✅ 正确 |

### 扩展 3: TodayExtension.appex

| 项目 | 预期值 | 实际值 | 状态 |
|------|--------|--------|------|
| Bundle ID | `cn.suanya.zhixingHC.TodayExtension` | `cn.suanya.zhixingHC.TodayExtension` | ✅ 匹配 |
| Profile UUID | `18fde6bd-6517-4fc3-a525-3d6b13da7340` | ✓ | ✅ 已配置 |
| embedded.mobileprovision | ✓ | 存在 | ✅ 正确 |
| 证书 | Apple Development: chaohong hou | Apple Development: chaohong hou (CKX4U5B8B5) | ✅ 正确 |
| Bundle ID 前缀 | 以主应用 Bundle ID 开头 | ✓ | ✅ 正确 |

---

## 3. 代码签名完整性验证

| 验证项目 | 结果 | 详情 |
|---------|------|------|
| 主应用签名 | ✅ 通过 | valid on disk |
| 主应用 Designated Requirement | ✅ 通过 | satisfies its Designated Requirement |
| 深度签名验证（包含所有扩展） | ✅ 通过 | valid on disk |
| 所有扩展签名 | ✅ 通过 | 3 个扩展全部签名正确 |

---

## 4. 证书链验证

所有组件（主应用和 3 个扩展）都使用相同的证书链：

```
Authority=Apple Development: chaohong hou (CKX4U5B8B5)
Authority=Apple Worldwide Developer Relations Certification Authority
Authority=Apple Root CA
TeamIdentifier=UNS8RSTG96
```

✅ **证书链完整且一致**

---

## 5. 配置文件验证

根据 `dev.plist` 的配置：

| Bundle ID | 配置的 Profile UUID | 状态 |
|-----------|---------------------|------|
| cn.suanya.zhixingHC | 846be4f9-d124-4e1a-a665-34a64b20fa52 | ✅ 已应用 |
| cn.suanya.zhixingHC.TodayExtension | 18fde6bd-6517-4fc3-a525-3d6b13da7340 | ✅ 已应用 |
| cn.suanya.zhixingHC.zxWidget | 10aaff01-4495-40f4-a311-9ea980762ddd | ✅ 已应用 |
| cn.suanya.zhixingHC.zxNotificationService | 17e42b82-aa61-4044-8baa-047c4879afa2 | ✅ 已应用 |

所有配置文件的过期时间：**2026年8月26日** ✅ 未过期

---

## 6. 总体评估

### ✅ 签名质量：优秀

- 主应用签名完整有效
- 所有 3 个扩展都正确配置并签名
- Bundle ID 全部匹配预期
- Provisioning Profile 全部正确嵌入
- 证书链完整且一致
- 代码签名验证通过（包括深度验证）

### 📋 配置总结

- **应用类型**: Development（开发版）
- **证书**: Apple Development: chaohong hou (CKX4U5B8B5)
- **Team**: Shanghai Suanya Information Technology Co., Ltd. (UNS8RSTG96)
- **设备限制**: 71 台已注册设备
- **Profile 有效期**: 至 2026-08-26

---

## 7. 关于安装失败的分析

虽然签名本身**完全正确**，但安装失败（错误 0xe8008015）的可能原因：

### ❗ 最可能的原因

**目标设备的 UDID 不在 Provisioning Profile 的设备列表中**

这是 Development Profile 的特性：
- ✅ 签名本身是正确的
- ✅ Profile 包含 71 台设备
- ❌ 但安装的目标设备可能不在这 71 台设备中

### 🔍 验证方法

1. **检查设备 UDID**：
```bash
# 通过 Finder 查看连接设备的 UDID
# 或使用命令：
system_profiler SPUSBDataType | grep -A 11 "iPad\|iPhone" | grep "Serial Number"
```

2. **检查 Profile 中的设备列表**：
```bash
security cms -D -i /Users/marshal/Documents/git/iReSign/iReSign/Release-Developer/dev_zhixing_0826.mobileprovision | grep -A 100 "ProvisionedDevices"
```

3. **验证设备是否在列表中**：
   比较设备 UDID 与 Profile 中的 ProvisionedDevices 列表

### 💡 解决方案

**方案 1（推荐）：添加设备到 Provisioning Profile**
1. 在 Apple Developer 网站添加目标设备的 UDID
2. 重新生成 Provisioning Profile（包含新设备）
3. 使用新的 Profile 重新签名

**方案 2：使用 Ad-Hoc 或 Enterprise Profile**
- Ad-Hoc Profile: 最多 100 台设备
- Enterprise Profile: 无设备限制（需要企业账号）

**方案 3：仅用于测试**
- 在已注册的 71 台设备中的任意一台上安装

---

## 8. 建议操作

### ✅ 立即可做的

1. **验证目标设备是否在 Profile 中**（见上方验证方法）
2. **尝试在其他设备上安装**（如果有已注册的设备）

### 📝 长期建议

1. **使用 Enterprise Profile**：如果有企业账号，使用 Enterprise Profile 可以避免设备限制
2. **定期更新设备列表**：及时将测试设备添加到 Developer Portal
3. **使用自动化签名**：考虑使用 Xcode 的自动签名管理功能

---

## 结论

✅ **签名本身完全正确，符合所有预期配置**

❗ **安装失败不是签名问题，而是设备授权问题**

建议先验证目标设备的 UDID 是否在 Provisioning Profile 的设备列表中。

