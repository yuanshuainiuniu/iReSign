#!/bin/bash

# 检查重签名后的 IPA 文件
# 用法: ./check_signed_ipa.sh <path_to_signed.ipa>

if [ $# -eq 0 ]; then
    echo "用法: $0 <path_to_signed.ipa>"
    exit 1
fi

IPA_PATH="$1"

if [ ! -f "$IPA_PATH" ]; then
    echo "错误: 文件不存在: $IPA_PATH"
    exit 1
fi

echo "=========================================="
echo "检查重签名的 IPA: $IPA_PATH"
echo "=========================================="

# 创建临时目录
TEMP_DIR=$(mktemp -d)
echo "临时目录: $TEMP_DIR"

# 解压 IPA
echo ""
echo "1. 解压 IPA..."
unzip -q "$IPA_PATH" -d "$TEMP_DIR"

# 找到 .app 目录
APP_PATH=$(find "$TEMP_DIR/Payload" -name "*.app" -maxdepth 1 | head -1)

if [ -z "$APP_PATH" ]; then
    echo "错误: 未找到 .app 文件"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "应用路径: $APP_PATH"

# 检查主应用
echo ""
echo "=========================================="
echo "2. 检查主应用"
echo "=========================================="

# 检查 embedded.mobileprovision
if [ -f "$APP_PATH/embedded.mobileprovision" ]; then
    echo "✓ 找到 embedded.mobileprovision"
    echo ""
    echo "Provisioning Profile 信息:"
    security cms -D -i "$APP_PATH/embedded.mobileprovision" > "$TEMP_DIR/profile.plist"
    
    # 提取 Bundle ID
    PROFILE_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "$TEMP_DIR/profile.plist" 2>/dev/null | sed 's/^[^.]*\.//')
    echo "  Profile Bundle ID: $PROFILE_BUNDLE_ID"
    
    # 提取过期时间
    EXPIRATION=$(/usr/libexec/PlistBuddy -c "Print :ExpirationDate" "$TEMP_DIR/profile.plist" 2>/dev/null)
    echo "  过期时间: $EXPIRATION"
    
    # 提取团队名称
    TEAM_NAME=$(/usr/libexec/PlistBuddy -c "Print :TeamName" "$TEMP_DIR/profile.plist" 2>/dev/null)
    echo "  团队名称: $TEAM_NAME"
    
    # 检查设备数量
    DEVICE_COUNT=$(/usr/libexec/PlistBuddy -c "Print :ProvisionedDevices" "$TEMP_DIR/profile.plist" 2>/dev/null | grep -c "^    ")
    if [ $DEVICE_COUNT -gt 0 ]; then
        echo "  设备数量: $DEVICE_COUNT"
    else
        echo "  配置类型: Enterprise/App Store (无设备限制)"
    fi
else
    echo "✗ 未找到 embedded.mobileprovision - 这是问题所在！"
fi

# 检查 Info.plist 中的 Bundle ID
if [ -f "$APP_PATH/Info.plist" ]; then
    APP_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null)
    echo ""
    echo "应用 Bundle ID: $APP_BUNDLE_ID"
    
    # 比较 Bundle ID
    if [ "$PROFILE_BUNDLE_ID" == "$APP_BUNDLE_ID" ] || [ "$PROFILE_BUNDLE_ID" == "*" ]; then
        echo "✓ Bundle ID 匹配"
    else
        echo "✗ Bundle ID 不匹配！"
        echo "  Profile: $PROFILE_BUNDLE_ID"
        echo "  App:     $APP_BUNDLE_ID"
    fi
fi

# 检查代码签名
echo ""
echo "代码签名信息:"
codesign -dvvv "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier|Signature"

# 检查扩展
echo ""
echo "=========================================="
echo "3. 检查扩展"
echo "=========================================="

PLUGINS_DIR="$APP_PATH/PlugIns"
if [ -d "$PLUGINS_DIR" ]; then
    EXTENSIONS=$(find "$PLUGINS_DIR" -name "*.appex" -maxdepth 1)
    EXTENSION_COUNT=$(echo "$EXTENSIONS" | grep -c ".appex")
    
    if [ $EXTENSION_COUNT -gt 0 ]; then
        echo "找到 $EXTENSION_COUNT 个扩展:"
        echo ""
        
        for EXT_PATH in $EXTENSIONS; do
            EXT_NAME=$(basename "$EXT_PATH")
            echo "扩展: $EXT_NAME"
            
            # 检查扩展的 embedded.mobileprovision
            if [ -f "$EXT_PATH/embedded.mobileprovision" ]; then
                echo "  ✓ 有 embedded.mobileprovision"
                
                security cms -D -i "$EXT_PATH/embedded.mobileprovision" > "$TEMP_DIR/ext_profile.plist"
                EXT_PROFILE_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" "$TEMP_DIR/ext_profile.plist" 2>/dev/null | sed 's/^[^.]*\.//')
                echo "    Profile Bundle ID: $EXT_PROFILE_BUNDLE_ID"
            else
                echo "  ✗ 缺少 embedded.mobileprovision"
            fi
            
            # 检查扩展的 Bundle ID
            if [ -f "$EXT_PATH/Info.plist" ]; then
                EXT_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$EXT_PATH/Info.plist" 2>/dev/null)
                echo "    扩展 Bundle ID: $EXT_BUNDLE_ID"
                
                # 检查是否以主应用 Bundle ID 为前缀
                if [[ "$EXT_BUNDLE_ID" == "$APP_BUNDLE_ID"* ]]; then
                    echo "    ✓ Bundle ID 前缀正确"
                else
                    echo "    ✗ Bundle ID 前缀不正确（应以主应用 Bundle ID 开头）"
                fi
            fi
            
            # 检查扩展签名
            echo "    代码签名:"
            codesign -dvvv "$EXT_PATH" 2>&1 | grep -E "Authority|Identifier" | sed 's/^/      /'
            echo ""
        done
    else
        echo "未找到扩展"
    fi
else
    echo "未找到 PlugIns 目录"
fi

# 验证整个应用的签名
echo ""
echo "=========================================="
echo "4. 验证签名"
echo "=========================================="
echo "验证主应用签名..."
codesign -vvv "$APP_PATH" 2>&1
MAIN_RESULT=$?

if [ $MAIN_RESULT -eq 0 ]; then
    echo "✓ 主应用签名验证成功"
else
    echo "✗ 主应用签名验证失败"
fi

# 深度验证
echo ""
echo "深度验证（包括扩展）..."
codesign -vvv --deep --strict "$APP_PATH" 2>&1
DEEP_RESULT=$?

if [ $DEEP_RESULT -eq 0 ]; then
    echo "✓ 深度签名验证成功"
else
    echo "✗ 深度签名验证失败"
fi

# 清理
echo ""
echo "=========================================="
echo "清理临时文件..."
rm -rf "$TEMP_DIR"
echo "完成！"
echo "=========================================="

if [ $MAIN_RESULT -ne 0 ] || [ $DEEP_RESULT -ne 0 ]; then
    echo ""
    echo "⚠️  签名验证失败，请检查以上输出的详细信息"
    exit 1
fi

