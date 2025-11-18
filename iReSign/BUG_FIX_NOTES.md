# Bug 修复说明

## 修复日期
2025年11月17日

## 修复的Bug

### Bug 1: Extension配置文件选择后无法正确显示
**问题描述：**
- 在"管理扩展配置"弹窗中点击Browse按钮选择配置文件后，文件路径没有显示在文本框中

**根本原因：**
- `browseForExtensionProfile:` 方法使用tag来匹配文本框，但匹配逻辑不可靠
- 文本框的引用在方法间传递时丢失

**解决方案：**
1. 添加实例变量 `extensionTextFields` 来保存文本框引用
2. 使用按钮的 `identifier` 属性存储扩展名称
3. 在 `browseForExtensionProfile:` 中通过identifier直接从字典获取对应的文本框
4. 选择文件后直接更新文本框内容

**修改的代码：**
- `iReSignAppDelegate.h`: 添加 `extensionTextFields` 字典
- `iReSignAppDelegate.m`: 
  - 初始化 `extensionTextFields`
  - 修改 `manageExtensions:` 使用identifier关联按钮和文本框
  - 完全重写 `browseForExtensionProfile:` 方法

### Bug 2: 重签名后Extension的配置文件没有被正确替换
**问题描述：**
- 为Extension选择了配置文件后，重签名完成的IPA中Extension的embedded.mobileprovision没有被替换

**根本原因：**
- 当主应用没有配置文件时（`provisioningPathField`为空），代码直接跳到 `doCodeSigning`
- 这导致 `doProvisioning` 和 `doExtensionsProvisioning` 被完全跳过
- Extension的配置文件替换逻辑永远不会执行

**解决方案：**
1. 修改 `checkUnzip` 和 `checkCopy` 方法的逻辑
2. 添加条件判断：
   - 如果有主应用配置文件 → 执行 `doProvisioning`（会自动调用`doExtensionsProvisioning`）
   - 如果没有主应用配置文件但有Extension → 直接执行 `doExtensionsProvisioning`
   - 如果都没有 → 直接执行 `doCodeSigning`
3. 增强 `doExtensionsProvisioning` 方法的错误处理和日志输出
4. 添加文件存在验证和复制成功验证

**修改的代码：**
- `checkUnzip:` - 添加智能provisioning判断逻辑
- `checkCopy:` - 添加智能provisioning判断逻辑  
- `doExtensionsProvisioning` - 增强错误处理、验证和日志

## 技术细节

### 配置文件选择流程（修复后）
```
用户点击Browse按钮
    ↓
按钮的identifier包含扩展名称
    ↓
browseForExtensionProfile: 获取identifier
    ↓
从extensionTextFields字典获取对应文本框
    ↓
更新文本框显示选择的文件路径
    ↓
点击OK后保存到extensionProvisioningProfiles字典
```

### 配置文件替换流程（修复后）
```
解压IPA完成
    ↓
扫描Extensions
    ↓
判断是否需要provisioning：
    ├─ 有主应用配置 → doProvisioning → doExtensionsProvisioning
    ├─ 无主应用配置但有Extension → doExtensionsProvisioning
    └─ 都没有 → doCodeSigning
    ↓
doExtensionsProvisioning:
    ├─ 验证源文件存在
    ├─ 验证目标目录存在
    ├─ 删除旧的embedded.mobileprovision
    ├─ 复制新的配置文件
    └─ 验证复制成功
    ↓
继续执行签名流程
```

## 增强的日志输出

修复后，控制台会输出详细的Extension处理日志：

```
Processing provisioning for 1 extension(s)
Extension provisioning profiles dictionary: {
    "NotificationExtension.appex" = "/path/to/profile.mobileprovision";
}
Processing extension: NotificationExtension.appex
Extension path: /path/to/app/PlugIns/NotificationExtension.appex
Provisioning profile path: /path/to/profile.mobileprovision
Removed old provisioning profile at: .../embedded.mobileprovision
✓ Successfully copied provisioning profile for extension: NotificationExtension.appex
  Destination: .../NotificationExtension.appex/embedded.mobileprovision
Extension provisioning completed: 1/1 extensions processed
```

## 错误处理

增强的错误处理包括：

1. **源文件不存在**
   - 检查配置文件是否存在
   - 显示警告对话框告知用户

2. **目标目录不存在**
   - 检查Extension目录是否存在
   - 记录错误日志

3. **文件复制失败**
   - 捕获并显示具体的错误信息
   - 显示警告对话框

4. **复制验证失败**
   - 复制后验证文件是否真的存在
   - 如果不存在记录错误

## 测试建议

### 测试场景1：有主应用配置和Extension配置
1. 选择包含Extension的IPA
2. 设置主应用配置文件
3. 为Extension配置不同的配置文件
4. 重签名后检查两个配置文件是否都被正确替换

### 测试场景2：只有Extension配置
1. 选择包含Extension的IPA
2. 不设置主应用配置文件
3. 只为Extension配置配置文件
4. 重签名后检查Extension的配置文件是否被替换

### 测试场景3：多个Extension
1. 选择包含多个Extension的IPA
2. 为每个Extension配置不同的配置文件
3. 重签名后检查所有Extension的配置文件

### 测试场景4：跳过Extension配置
1. 选择包含Extension的IPA
2. 在弹窗中点击"Skip"
3. 重签名后检查Extension的原配置文件是否保留

## 向后兼容性

所有修改都保持向后兼容：
- 不包含Extension的应用签名流程不受影响
- 原有的主应用配置流程完全保留
- 不选择Extension配置时保留原有配置文件

## 相关文件

修改的文件：
- `iReSign/iReSignAppDelegate.h`
- `iReSign/iReSignAppDelegate.m`

新增的文档：
- `EXTENSIONS_SUPPORT.md` - Extension支持功能说明
- `BUG_FIX_NOTES.md` - 本文档

