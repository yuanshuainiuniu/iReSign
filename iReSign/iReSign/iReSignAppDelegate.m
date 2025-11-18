//
//  iReSignAppDelegate.m
//  iReSign
//
//  Created by Maciej Swic on 2011-05-16.
//  Copyright (c) 2011 Maciej Swic, Licensed under the MIT License.
//  See README.md for details
//

#import "iReSignAppDelegate.h"

static NSString *kKeyPrefsBundleIDChange            = @"keyBundleIDChange";

static NSString *kKeyBundleIDPlistApp               = @"CFBundleIdentifier";
static NSString *kKeyBundleIDPlistiTunesArtwork     = @"softwareVersionBundleId";
static NSString *kKeyInfoPlistApplicationProperties = @"ApplicationProperties";
static NSString *kKeyInfoPlistApplicationPath       = @"ApplicationPath";
static NSString *kFrameworksDirName                 = @"Frameworks";
static NSString *kPayloadDirName                    = @"Payload";
static NSString *kProductsDirName                   = @"Products";
static NSString *kInfoPlistFilename                 = @"Info.plist";
static NSString *kiTunesMetadataFileName            = @"iTunesMetadata";

@implementation iReSignAppDelegate

@synthesize window,workingPath;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [flurry setAlphaValue:0.5];
    
    defaults = [NSUserDefaults standardUserDefaults];
    
    // Initialize extensions data structures
    extensions = [[NSMutableArray alloc] init];
    extensionProvisioningProfiles = [[NSMutableDictionary alloc] init];
    extensionTextFields = [[NSMutableDictionary alloc] init];
    extensionEntitlements = [[NSMutableDictionary alloc] init];
    extensionBundleIDs = [[NSMutableDictionary alloc] init];
    
    // Look up available signing certificates
    [self getCerts];
    
    // Configure text fields for better path display
    [[pathField cell] setLineBreakMode:NSLineBreakByTruncatingHead];
    [[provisioningPathField cell] setLineBreakMode:NSLineBreakByTruncatingHead];
    [[entitlementField cell] setLineBreakMode:NSLineBreakByTruncatingHead];
    [[bundleIDField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
    
    // Configure status label for better display
    // Allow wrapping and adjust the frame to be above the resign button
    [statusLabel setLineBreakMode:NSLineBreakByWordWrapping];
    [statusLabel setMaximumNumberOfLines:2];
    
    // Move status label above resign button if needed
    NSRect statusFrame = [statusLabel frame];
    NSRect resignButtonFrame = [resignButton frame];
    
    // Position status label above the resign button with some padding
    statusFrame.origin.y = resignButtonFrame.origin.y + resignButtonFrame.size.height + 10;
    statusFrame.size.width = resignButtonFrame.origin.x + resignButtonFrame.size.width - statusFrame.origin.x;
    statusFrame.size.height = 40; // Increase height for 2 lines
    [statusLabel setFrame:statusFrame];
    
    // Adjust flurry (loading indicator) position to align with status label
    NSRect flurryFrame = [flurry frame];
    // Position flurry at the left of status label, vertically centered
    flurryFrame.origin.x = statusFrame.origin.x - flurryFrame.size.width - 8; // 8px padding
    flurryFrame.origin.y = statusFrame.origin.y + (statusFrame.size.height - flurryFrame.size.height) / 2;
    [flurry setFrame:flurryFrame];
    
    // Restore last used paths
    if ([defaults valueForKey:@"IPA_PATH"])
        [pathField setStringValue:[defaults valueForKey:@"IPA_PATH"]];
    if ([defaults valueForKey:@"ENTITLEMENT_PATH"])
        [entitlementField setStringValue:[defaults valueForKey:@"ENTITLEMENT_PATH"]];
    if ([defaults valueForKey:@"MOBILEPROVISION_PATH"])
        [provisioningPathField setStringValue:[defaults valueForKey:@"MOBILEPROVISION_PATH"]];
    
    // Restore Bundle ID change checkbox state
    NSNumber *bundleIDChangeEnabled = [defaults valueForKey:@"BUNDLE_ID_CHANGE_ENABLED"];
    if (bundleIDChangeEnabled) {
        [changeBundleIDCheckbox setState:[bundleIDChangeEnabled boolValue] ? NSControlStateValueOn : NSControlStateValueOff];
        [bundleIDField setEnabled:[bundleIDChangeEnabled boolValue]];
    }
    
    // Restore Bundle ID value if checkbox was enabled
    if ([changeBundleIDCheckbox state] == NSControlStateValueOn) {
        if ([defaults valueForKey:kKeyPrefsBundleIDChange]) {
            [bundleIDField setStringValue:[defaults valueForKey:kKeyPrefsBundleIDChange]];
        }
    }
    
    // Restore extension configurations
    NSDictionary *savedExtensionProfiles = [defaults objectForKey:@"EXTENSION_PROVISIONING_PROFILES"];
    if (savedExtensionProfiles) {
        [extensionProvisioningProfiles addEntriesFromDictionary:savedExtensionProfiles];
    }
    NSDictionary *savedExtensionBundleIDs = [defaults objectForKey:@"EXTENSION_BUNDLE_IDS"];
    if (savedExtensionBundleIDs) {
        [extensionBundleIDs addEntriesFromDictionary:savedExtensionBundleIDs];
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/zip"]) {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"This app cannot run without the zip utility present at /usr/bin/zip"];
        exit(0);
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/unzip"]) {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"This app cannot run without the unzip utility present at /usr/bin/unzip"];
        exit(0);
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/codesign"]) {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"This app cannot run without the codesign utility present at /usr/bin/codesign"];
        exit(0);
    }
}


- (IBAction)resign:(id)sender {
    //Save settings
    [defaults setValue:[NSNumber numberWithInteger:[certComboBox indexOfSelectedItem]] forKey:@"CERT_INDEX"];
    [defaults setValue:[pathField stringValue] forKey:@"IPA_PATH"];
    [defaults setValue:[entitlementField stringValue] forKey:@"ENTITLEMENT_PATH"];
    [defaults setValue:[provisioningPathField stringValue] forKey:@"MOBILEPROVISION_PATH"];
    
    // Save Bundle ID change checkbox state
    BOOL bundleIDChangeEnabled = (changeBundleIDCheckbox.state == NSControlStateValueOn);
    [defaults setValue:[NSNumber numberWithBool:bundleIDChangeEnabled] forKey:@"BUNDLE_ID_CHANGE_ENABLED"];
    
    // Save Bundle ID value if checkbox is enabled
    if (bundleIDChangeEnabled) {
        [defaults setValue:[bundleIDField stringValue] forKey:kKeyPrefsBundleIDChange];
    }
    
    [defaults synchronize];
    
    codesigningResult = nil;
    verificationResult = nil;
    
    sourcePath = [pathField stringValue];
    workingPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.appulize.iresign"];
    
    if ([certComboBox objectValue]) {
        if (([[[sourcePath pathExtension] lowercaseString] isEqualToString:@"ipa"]) ||
            ([[[sourcePath pathExtension] lowercaseString] isEqualToString:@"xcarchive"])) {
            [self disableControls];
            
            NSLog(@"Setting up working directory in %@",workingPath);
            [statusLabel setHidden:NO];
            [statusLabel setStringValue:@"Setting up working directory"];
            
            [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];
            
            [[NSFileManager defaultManager] createDirectoryAtPath:workingPath withIntermediateDirectories:TRUE attributes:nil error:nil];
            
            if ([[[sourcePath pathExtension] lowercaseString] isEqualToString:@"ipa"]) {
                if (sourcePath && [sourcePath length] > 0) {
                    NSLog(@"Unzipping %@",sourcePath);
                    [statusLabel setStringValue:@"Extracting original app"];
                }
                
                unzipTask = [[NSTask alloc] init];
                [unzipTask setLaunchPath:@"/usr/bin/unzip"];
                [unzipTask setArguments:[NSArray arrayWithObjects:@"-q", sourcePath, @"-d", workingPath, nil]];
                
                [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkUnzip:) userInfo:nil repeats:TRUE];
                
                [unzipTask launch];
            }
            else {
                NSString* payloadPath = [workingPath stringByAppendingPathComponent:kPayloadDirName];
                
                NSLog(@"Setting up %@ path in %@", kPayloadDirName, payloadPath);
                [statusLabel setStringValue:[NSString stringWithFormat:@"Setting up %@ path", kPayloadDirName]];
                
                [[NSFileManager defaultManager] createDirectoryAtPath:payloadPath withIntermediateDirectories:TRUE attributes:nil error:nil];
                
                NSLog(@"Retrieving %@", kInfoPlistFilename);
                [statusLabel setStringValue:[NSString stringWithFormat:@"Retrieving %@", kInfoPlistFilename]];
                
                NSString* infoPListPath = [sourcePath stringByAppendingPathComponent:kInfoPlistFilename];
                
                NSDictionary* infoPListDict = [NSDictionary dictionaryWithContentsOfFile:infoPListPath];
                
                if (infoPListDict != nil) {
                    NSString* applicationPath = nil;
                    
                    NSDictionary* applicationPropertiesDict = [infoPListDict objectForKey:kKeyInfoPlistApplicationProperties];
                    
                    if (applicationPropertiesDict != nil) {
                        applicationPath = [applicationPropertiesDict objectForKey:kKeyInfoPlistApplicationPath];
                    }
                    
                    if (applicationPath != nil) {
                        applicationPath = [[sourcePath stringByAppendingPathComponent:kProductsDirName] stringByAppendingPathComponent:applicationPath];
                        
                        NSLog(@"Copying %@ to %@ path in %@", applicationPath, kPayloadDirName, payloadPath);
                        [statusLabel setStringValue:[NSString stringWithFormat:@"Copying .xcarchive app to %@ path", kPayloadDirName]];
                        
                        copyTask = [[NSTask alloc] init];
                        [copyTask setLaunchPath:@"/bin/cp"];
                        [copyTask setArguments:[NSArray arrayWithObjects:@"-r", applicationPath, payloadPath, nil]];
                        
                        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkCopy:) userInfo:nil repeats:TRUE];
                        
                        [copyTask launch];
                    }
                    else {
                        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:[NSString stringWithFormat:@"Unable to parse %@", kInfoPlistFilename]];
                        [self enableControls];
                        [statusLabel setStringValue:@"Ready"];
                    }
                }
                else {
                    [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:[NSString stringWithFormat:@"Retrieve %@ failed", kInfoPlistFilename]];
                    [self enableControls];
                    [statusLabel setStringValue:@"Ready"];
                }
            }
        }
        else {
            [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"You must choose an *.ipa or *.xcarchive file"];
            [self enableControls];
            [statusLabel setStringValue:@"Please try again"];
        }
    } else {
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"You must choose an signing certificate from dropdown."];
        [self enableControls];
        [statusLabel setStringValue:@"Please try again"];
    }
}

- (void)checkUnzip:(NSTimer *)timer {
    if ([unzipTask isRunning] == 0) {
        [timer invalidate];
        unzipTask = nil;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName]]) {
            NSLog(@"Unzipping done");
            [statusLabel setStringValue:@"Original app extracted"];
            
            // Find app path and scan for extensions early
            NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
            for (NSString *file in dirContents) {
                if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
                    appPath = [[workingPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
                    [self scanForExtensions];
                    break;
                }
            }
            
            // If extensions found, prompt user to configure them (only if not already configured)
            if ([extensions count] > 0) {
                // Check if user has already configured any extensions
                BOOL hasConfiguredExtensions = NO;
                for (NSString *extensionPath in extensions) {
                    NSString *extensionName = [extensionPath lastPathComponent];
                    if ([extensionProvisioningProfiles objectForKey:extensionName] != nil ||
                        [extensionBundleIDs objectForKey:extensionName] != nil) {
                        hasConfiguredExtensions = YES;
                        break;
                    }
                }
                
                if (!hasConfiguredExtensions) {
                    // User hasn't configured extensions yet, ask if they want to
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert setMessageText:@"检测到扩展"];
                    [alert setInformativeText:[NSString stringWithFormat:@"在应用中发现 %lu 个扩展。是否现在配置它们的 Provisioning Profile？", (unsigned long)[extensions count]]];
                    [alert addButtonWithTitle:@"配置"];
                    [alert addButtonWithTitle:@"跳过"];
                    
                    NSModalResponse response = [alert runModal];
                    if (response == NSAlertFirstButtonReturn) {
                        [self manageExtensions:nil];
                    }
                } else {
                    NSLog(@"✓ Extensions already configured, skipping configuration prompt");
                }
            }
            
            if (changeBundleIDCheckbox.state == NSOnState) {
                [self doBundleIDChange:bundleIDField.stringValue];
            }
            
            // Check if we need to do provisioning (main app or extensions)
            BOOL hasMainProvisioning = ![[provisioningPathField stringValue] isEqualTo:@""];
            BOOL hasExtensionProvisioning = [extensions count] > 0;
            
            if (hasMainProvisioning) {
                // Do main app provisioning first, which will handle extensions too
                [self doProvisioning];
            } else if (hasExtensionProvisioning) {
                // No main app provisioning, but we have extensions to provision
                [self doExtensionsProvisioning];
            } else {
                // No provisioning at all, go straight to code signing
                [self doCodeSigning];
            }
        } else {
            [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Unzip failed"];
            [self enableControls];
            [statusLabel setStringValue:@"Ready"];
        }
    }
}

- (void)checkCopy:(NSTimer *)timer {
    if ([copyTask isRunning] == 0) {
        [timer invalidate];
        copyTask = nil;
        
        NSLog(@"Copy done");
        [statusLabel setStringValue:@".xcarchive app copied"];
        
        // Find app path and scan for extensions early
        NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
        for (NSString *file in dirContents) {
            if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
                appPath = [[workingPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
                [self scanForExtensions];
                break;
            }
        }
        
        // If extensions found, prompt user to configure them (only if not already configured)
        if ([extensions count] > 0) {
            // Check if user has already configured any extensions
            BOOL hasConfiguredExtensions = NO;
            for (NSString *extensionPath in extensions) {
                NSString *extensionName = [extensionPath lastPathComponent];
                if ([extensionProvisioningProfiles objectForKey:extensionName] != nil ||
                    [extensionBundleIDs objectForKey:extensionName] != nil) {
                    hasConfiguredExtensions = YES;
                    break;
                }
            }
            
            if (!hasConfiguredExtensions) {
                // User hasn't configured extensions yet, ask if they want to
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"检测到扩展"];
                [alert setInformativeText:[NSString stringWithFormat:@"在应用中发现 %lu 个扩展。是否现在配置它们的 Provisioning Profile？", (unsigned long)[extensions count]]];
                [alert addButtonWithTitle:@"配置"];
                [alert addButtonWithTitle:@"跳过"];
                
                NSModalResponse response = [alert runModal];
                if (response == NSAlertFirstButtonReturn) {
                    [self manageExtensions:nil];
                }
            } else {
                NSLog(@"✓ Extensions already configured, skipping configuration prompt");
            }
        }
        
        if (changeBundleIDCheckbox.state == NSOnState) {
            [self doBundleIDChange:bundleIDField.stringValue];
        }
        
        // Check if we need to do provisioning (main app or extensions)
        BOOL hasMainProvisioning = ![[provisioningPathField stringValue] isEqualTo:@""];
        BOOL hasExtensionProvisioning = [extensions count] > 0;
        
        if (hasMainProvisioning) {
            // Do main app provisioning first, which will handle extensions too
            [self doProvisioning];
        } else if (hasExtensionProvisioning) {
            // No main app provisioning, but we have extensions to provision
            [self doExtensionsProvisioning];
        } else {
            // No provisioning at all, go straight to code signing
            [self doCodeSigning];
        }
    }
}

- (BOOL)doBundleIDChange:(NSString *)newBundleID {
    BOOL success = YES;
    
    success &= [self doAppBundleIDChange:newBundleID];
    success &= [self doITunesMetadataBundleIDChange:newBundleID];
    success &= [self doExtensionsBundleIDChange];
    
    return success;
}


- (BOOL)doITunesMetadataBundleIDChange:(NSString *)newBundleID {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:workingPath error:nil];
    NSString *infoPlistPath = nil;
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"plist"]) {
            infoPlistPath = [workingPath stringByAppendingPathComponent:file];
            break;
        }
    }
    
    return [self changeBundleIDForFile:infoPlistPath bundleIDKey:kKeyBundleIDPlistiTunesArtwork newBundleID:newBundleID plistOutOptions:NSPropertyListXMLFormat_v1_0];
    
}

- (BOOL)doAppBundleIDChange:(NSString *)newBundleID {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
    NSString *infoPlistPath = nil;
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            infoPlistPath = [[[workingPath stringByAppendingPathComponent:kPayloadDirName]
                              stringByAppendingPathComponent:file]
                             stringByAppendingPathComponent:kInfoPlistFilename];
            break;
        }
    }
    
    return [self changeBundleIDForFile:infoPlistPath bundleIDKey:kKeyBundleIDPlistApp newBundleID:newBundleID plistOutOptions:NSPropertyListBinaryFormat_v1_0];
}

- (BOOL)changeBundleIDForFile:(NSString *)filePath bundleIDKey:(NSString *)bundleIDKey newBundleID:(NSString *)newBundleID plistOutOptions:(NSPropertyListWriteOptions)options {
    
    NSMutableDictionary *plist = nil;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        plist = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
        [plist setObject:newBundleID forKey:bundleIDKey];
        
        NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:plist format:options options:kCFPropertyListImmutable error:nil];
        
        return [xmlData writeToFile:filePath atomically:YES];
        
    }
    
    return NO;
}

- (BOOL)doExtensionsBundleIDChange {
    BOOL success = YES;
    
    if ([extensions count] == 0) {
        NSLog(@"No extensions to update Bundle IDs");
        return YES;
    }
    
    for (NSString *extension in extensions) {
        NSString *extensionName = [extension lastPathComponent];
        NSString *newExtensionBundleID = [extensionBundleIDs objectForKey:extensionName];
        
        if (!newExtensionBundleID || [newExtensionBundleID length] == 0) {
            NSLog(@"No Bundle ID configured for extension %@, skipping", extensionName);
            continue;
        }
        
        // Find the extension path
        NSString *plugInsPath = [appPath stringByAppendingPathComponent:@"PlugIns"];
        NSString *extensionPath = [plugInsPath stringByAppendingPathComponent:extensionName];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:extensionPath]) {
            NSLog(@"Extension path not found: %@", extensionPath);
            success = NO;
            continue;
        }
        
        NSString *extensionInfoPlistPath = [extensionPath stringByAppendingPathComponent:kInfoPlistFilename];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:extensionInfoPlistPath]) {
            NSLog(@"Extension Info.plist not found: %@", extensionInfoPlistPath);
            success = NO;
            continue;
        }
        
        BOOL changeSuccess = [self changeBundleIDForFile:extensionInfoPlistPath 
                                             bundleIDKey:kKeyBundleIDPlistApp 
                                             newBundleID:newExtensionBundleID 
                                         plistOutOptions:NSPropertyListBinaryFormat_v1_0];
        
        if (changeSuccess) {
            NSLog(@"✓ Updated Bundle ID for extension %@ to %@", extensionName, newExtensionBundleID);
        } else {
            NSLog(@"✗ Failed to update Bundle ID for extension %@", extensionName);
            success = NO;
        }
    }
    
    return success;
}


- (void)scanForExtensions {
    // Scan for extensions in the app bundle
    // Note: We preserve extension configurations even when rescanning
    [extensions removeAllObjects];
    [extensionEntitlements removeAllObjects];
    
    NSString *plugInsPath = [appPath stringByAppendingPathComponent:@"PlugIns"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:plugInsPath]) {
        NSArray *plugInContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:plugInsPath error:nil];
        for (NSString *plugInFile in plugInContents) {
            if ([[[plugInFile pathExtension] lowercaseString] isEqualToString:@"appex"]) {
                NSString *extensionPath = [plugInsPath stringByAppendingPathComponent:plugInFile];
                [extensions addObject:extensionPath];
                NSLog(@"Found extension: %@", plugInFile);
            }
        }
    }
    
    if ([extensions count] > 0) {
        NSLog(@"Found %lu extension(s)", (unsigned long)[extensions count]);
        // Log currently configured extensions
        if ([extensionProvisioningProfiles count] > 0) {
            NSLog(@"Extension provisioning profiles configured: %@", [extensionProvisioningProfiles allKeys]);
        }
        if ([extensionBundleIDs count] > 0) {
            NSLog(@"Extension Bundle IDs configured: %@", [extensionBundleIDs allKeys]);
        }
    }
}

- (void)doProvisioning {
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            appPath = [[workingPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
            if ([[NSFileManager defaultManager] fileExistsAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
                NSLog(@"Found embedded.mobileprovision, deleting.");
                [[NSFileManager defaultManager] removeItemAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"] error:nil];
            }
            break;
        }
    }
    
    // Scan for extensions after finding the app path
    [self scanForExtensions];
    
    NSString *targetPath = [appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
    
    provisioningTask = [[NSTask alloc] init];
    [provisioningTask setLaunchPath:@"/bin/cp"];
    [provisioningTask setArguments:[NSArray arrayWithObjects:[provisioningPathField stringValue], targetPath, nil]];
    
    [provisioningTask launch];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkProvisioning:) userInfo:nil repeats:TRUE];
}

- (void)checkProvisioning:(NSTimer *)timer {
    if ([provisioningTask isRunning] == 0) {
        [timer invalidate];
        provisioningTask = nil;
        
        NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
        
        for (NSString *file in dirContents) {
            if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
                appPath = [[workingPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
                if ([[NSFileManager defaultManager] fileExistsAtPath:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
                    
                    BOOL identifierOK = FALSE;
                    NSString *identifierInProvisioning = @"";
                    
                    NSString *embeddedProvisioning = [NSString stringWithContentsOfFile:[appPath stringByAppendingPathComponent:@"embedded.mobileprovision"] encoding:NSASCIIStringEncoding error:nil];
                    NSArray* embeddedProvisioningLines = [embeddedProvisioning componentsSeparatedByCharactersInSet:
                                                          [NSCharacterSet newlineCharacterSet]];
                    
                    for (int i = 0; i < [embeddedProvisioningLines count]; i++) {
                        if ([[embeddedProvisioningLines objectAtIndex:i] rangeOfString:@"application-identifier"].location != NSNotFound) {
                            
                            NSInteger fromPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"<string>"].location + 8;
                            
                            NSInteger toPosition = [[embeddedProvisioningLines objectAtIndex:i+1] rangeOfString:@"</string>"].location;
                            
                            NSRange range;
                            range.location = fromPosition;
                            range.length = toPosition-fromPosition;
                            
                            NSString *fullIdentifier = [[embeddedProvisioningLines objectAtIndex:i+1] substringWithRange:range];
                            
                            NSArray *identifierComponents = [fullIdentifier componentsSeparatedByString:@"."];
                            
                            if ([[identifierComponents lastObject] isEqualTo:@"*"]) {
                                identifierOK = TRUE;
                            }
                            
                            for (int i = 1; i < [identifierComponents count]; i++) {
                                identifierInProvisioning = [identifierInProvisioning stringByAppendingString:[identifierComponents objectAtIndex:i]];
                                if (i < [identifierComponents count]-1) {
                                    identifierInProvisioning = [identifierInProvisioning stringByAppendingString:@"."];
                                }
                            }
                            break;
                        }
                    }
                    
                    NSLog(@"Mobileprovision identifier: %@",identifierInProvisioning);
                    
                    NSDictionary *infoplist = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
                    if ([identifierInProvisioning isEqualTo:[infoplist objectForKey:kKeyBundleIDPlistApp]]) {
                        NSLog(@"Identifiers match");
                        identifierOK = TRUE;
                    }
                    
                    if (identifierOK) {
                        NSLog(@"Provisioning completed.");
                        [statusLabel setStringValue:@"Provisioning completed"];
                        [self doExtensionsProvisioning];
                    } else {
                        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Product identifiers don't match"];
                        [self enableControls];
                        [statusLabel setStringValue:@"Ready"];
                    }
                } else {
                    [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Provisioning failed"];
                    [self enableControls];
                    [statusLabel setStringValue:@"Ready"];
                }
                break;
            }
        }
    }
}

- (void)doExtensionsProvisioning {
    // Process provisioning profiles for extensions
    if ([extensions count] == 0) {
        NSLog(@"No extensions found, skipping extensions provisioning");
        [self doEntitlementsFixing];
        return;
    }
    
    NSLog(@"========== Starting Extensions Provisioning ==========");
    NSLog(@"Total extensions found: %lu", (unsigned long)[extensions count]);
    NSLog(@"Extension paths: %@", extensions);
    NSLog(@"Configured provisioning profiles: %@", extensionProvisioningProfiles);
    NSLog(@"Configured Bundle IDs: %@", extensionBundleIDs);
    NSLog(@"====================================================");
    
    BOOL hasErrors = NO;
    NSInteger processedCount = 0;
    
    for (NSString *extensionPath in extensions) {
        NSString *extensionName = [extensionPath lastPathComponent];
        NSString *provisioningPath = [extensionProvisioningProfiles objectForKey:extensionName];
        
        NSLog(@"\n--- Processing extension: %@ ---", extensionName);
        NSLog(@"Extension full path: %@", extensionPath);
        NSLog(@"Looking for provisioning with key: %@", extensionName);
        NSLog(@"Found provisioning profile path: %@", provisioningPath ? provisioningPath : @"(none configured)");
        
        if (provisioningPath && [provisioningPath length] > 0) {
            // Verify source file exists
            if (![[NSFileManager defaultManager] fileExistsAtPath:provisioningPath]) {
                NSLog(@"ERROR: Source provisioning profile does not exist: %@", provisioningPath);
                [self showAlertOfKind:NSWarningAlertStyle 
                            WithTitle:@"Warning" 
                           AndMessage:[NSString stringWithFormat:@"Provisioning profile not found for %@:\n%@", extensionName, provisioningPath]];
                hasErrors = YES;
                continue;
            }
            
            // Verify extension directory exists
            if (![[NSFileManager defaultManager] fileExistsAtPath:extensionPath]) {
                NSLog(@"ERROR: Extension directory does not exist: %@", extensionPath);
                hasErrors = YES;
                continue;
            }
            
            NSString *embeddedProvisionPath = [extensionPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
            
            // Remove old embedded.mobileprovision if exists
            if ([[NSFileManager defaultManager] fileExistsAtPath:embeddedProvisionPath]) {
                NSError *removeError = nil;
                [[NSFileManager defaultManager] removeItemAtPath:embeddedProvisionPath error:&removeError];
                if (removeError) {
                    NSLog(@"Warning: Failed to remove old provisioning profile: %@", removeError);
                } else {
                    NSLog(@"Removed old provisioning profile at: %@", embeddedProvisionPath);
                }
            }
            
            // Copy new provisioning profile
            NSError *error = nil;
            BOOL success = [[NSFileManager defaultManager] copyItemAtPath:provisioningPath 
                                                                   toPath:embeddedProvisionPath 
                                                                    error:&error];
            
            if (error || !success) {
                NSLog(@"ERROR: Failed to copy provisioning profile for extension %@: %@", extensionName, error);
                [self showAlertOfKind:NSWarningAlertStyle 
                            WithTitle:@"Warning" 
                           AndMessage:[NSString stringWithFormat:@"Failed to copy provisioning profile for %@:\n%@", extensionName, error.localizedDescription]];
                hasErrors = YES;
            } else {
                // Verify the file was actually copied
                if ([[NSFileManager defaultManager] fileExistsAtPath:embeddedProvisionPath]) {
                    NSLog(@"✓ Successfully copied provisioning profile for extension: %@", extensionName);
                    NSLog(@"  Destination: %@", embeddedProvisionPath);
                    
                    // Generate entitlements for this extension
                    [self generateEntitlementsForExtension:extensionName 
                                        withProvisioningPath:provisioningPath];
                    
                    processedCount++;
                } else {
                    NSLog(@"ERROR: File copy reported success but file doesn't exist at: %@", embeddedProvisionPath);
                    hasErrors = YES;
                }
            }
        } else {
            NSLog(@"No provisioning profile configured for extension: %@ (keeping original)", extensionName);
            
            // Try to generate entitlements from existing embedded.mobileprovision
            NSString *embeddedProvisionPath = [extensionPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:embeddedProvisionPath]) {
                NSLog(@"Generating entitlements from existing provisioning profile for %@", extensionName);
                [self generateEntitlementsForExtension:extensionName withProvisioningPath:embeddedProvisionPath];
            }
        }
    }
    
    NSLog(@"Extension provisioning completed: %ld/%lu extensions processed", (long)processedCount, (unsigned long)[extensions count]);
    
    if (hasErrors) {
        [statusLabel setStringValue:@"Extensions provisioning completed with warnings"];
    } else {
        [statusLabel setStringValue:@"Extensions provisioning completed"];
    }
    
    [self doEntitlementsFixing];
}

- (void)generateEntitlementsForExtension:(NSString *)extensionName withProvisioningPath:(NSString *)provisioningPath {
    if (!provisioningPath || [provisioningPath length] == 0) {
        NSLog(@"No provisioning path for extension %@, skipping entitlements generation", extensionName);
        return;
    }
    
    NSLog(@"Generating entitlements for extension: %@", extensionName);
    
    // Use security command to extract entitlements from provisioning profile
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/security"];
    [task setArguments:@[@"cms", @"-D", @"-i", provisioningPath]];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];
    NSFileHandle *handle = [pipe fileHandleForReading];
    
    [task launch];
    [task waitUntilExit];
    
    NSData *data = [handle readDataToEndOfFile];
    NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if ([task terminationStatus] == 0 && result && [result length] > 0) {
        NSDictionary *profileDict = result.propertyList;
        NSDictionary *entitlements = profileDict[@"Entitlements"];
        
        if (entitlements) {
            // Save entitlements to a file
            NSString *entitlementsFileName = [NSString stringWithFormat:@"entitlements_%@.plist", 
                                            [extensionName stringByReplacingOccurrencesOfString:@".appex" withString:@""]];
            NSString *entitlementsPath = [workingPath stringByAppendingPathComponent:entitlementsFileName];
            
            NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:entitlements 
                                                                         format:NSPropertyListXMLFormat_v1_0 
                                                                        options:kCFPropertyListImmutable 
                                                                          error:nil];
            if ([xmlData writeToFile:entitlementsPath atomically:YES]) {
                [extensionEntitlements setObject:entitlementsPath forKey:extensionName];
                NSLog(@"✓ Generated entitlements for %@: %@", extensionName, entitlementsPath);
            } else {
                NSLog(@"ERROR: Failed to write entitlements file for %@", extensionName);
            }
        } else {
            NSLog(@"WARNING: No entitlements found in provisioning profile for %@", extensionName);
        }
    } else {
        NSLog(@"ERROR: Failed to extract entitlements from provisioning profile for %@", extensionName);
    }
}

- (void)doEntitlementsFixing
{
    if (![entitlementField.stringValue isEqualToString:@""] || [provisioningPathField.stringValue isEqualToString:@""]) {
        [self doCodeSigning];
        return; // Using a pre-made entitlements file or we're not re-provisioning.
    }
    
    [statusLabel setStringValue:@"Generating entitlements"];

    if (appPath) {
        generateEntitlementsTask = [[NSTask alloc] init];
        [generateEntitlementsTask setLaunchPath:@"/usr/bin/security"];
        [generateEntitlementsTask setArguments:@[@"cms", @"-D", @"-i", provisioningPathField.stringValue]];
        [generateEntitlementsTask setCurrentDirectoryPath:workingPath];

        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkEntitlementsFix:) userInfo:nil repeats:TRUE];

        NSPipe *pipe=[NSPipe pipe];
        [generateEntitlementsTask setStandardOutput:pipe];
        [generateEntitlementsTask setStandardError:pipe];
        NSFileHandle *handle = [pipe fileHandleForReading];

        [generateEntitlementsTask launch];

        [NSThread detachNewThreadSelector:@selector(watchEntitlements:)
                                 toTarget:self withObject:handle];
    }
}

- (void)watchEntitlements:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        entitlementsResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
    }
}

- (void)checkEntitlementsFix:(NSTimer *)timer {
    if ([generateEntitlementsTask isRunning] == 0) {
        [timer invalidate];
        generateEntitlementsTask = nil;
        NSLog(@"Entitlements fixed done");
        [statusLabel setStringValue:@"Entitlements generated"];
        [self doEntitlementsEdit];
    }
}

- (void)doEntitlementsEdit
{
    NSDictionary* entitlements = entitlementsResult.propertyList;
    entitlements = entitlements[@"Entitlements"];
    NSString* filePath = [workingPath stringByAppendingPathComponent:@"entitlements.plist"];
    NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:entitlements format:NSPropertyListXMLFormat_v1_0 options:kCFPropertyListImmutable error:nil];
    if(![xmlData writeToFile:filePath atomically:YES]) {
        NSLog(@"Error writing entitlements file.");
        [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Failed entitlements generation"];
        [self enableControls];
        [statusLabel setStringValue:@"Ready"];
    }
    else {
        entitlementField.stringValue = filePath;
        [self doCodeSigning];
    }
}

- (void)doCodeSigning {
    appPath = nil;
    frameworksDirPath = nil;
    hasFrameworks = NO;
    frameworks = [[NSMutableArray alloc] init];
    
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[workingPath stringByAppendingPathComponent:kPayloadDirName] error:nil];
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            appPath = [[workingPath stringByAppendingPathComponent:kPayloadDirName] stringByAppendingPathComponent:file];
            frameworksDirPath = [appPath stringByAppendingPathComponent:kFrameworksDirName];
            NSLog(@"Found %@",appPath);
            appName = file;
            
            // Scan for extensions if not already scanned
            if ([extensions count] == 0) {
                [self scanForExtensions];
            }
            
            // Add extensions and their frameworks to the signing queue
            for (NSString *extensionPath in extensions) {
                NSString *extensionFrameworksPath = [extensionPath stringByAppendingPathComponent:kFrameworksDirName];
                if ([[NSFileManager defaultManager] fileExistsAtPath:extensionFrameworksPath]) {
                    NSArray *extensionFrameworks = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:extensionFrameworksPath error:nil];
                    for (NSString *frameworkFile in extensionFrameworks) {
                        NSString *extension = [[frameworkFile pathExtension] lowercaseString];
                        if ([extension isEqualTo:@"framework"] || [extension isEqualTo:@"dylib"]) {
                            NSString *fwPath = [extensionFrameworksPath stringByAppendingPathComponent:frameworkFile];
                            NSLog(@"Found extension framework: %@", fwPath);
                            [frameworks addObject:fwPath];
                        }
                    }
                }
                // Add the extension itself to be signed
                [frameworks addObject:extensionPath];
            }
            
            // Add main app frameworks
            if ([[NSFileManager defaultManager] fileExistsAtPath:frameworksDirPath]) {
                NSLog(@"Found %@",frameworksDirPath);
                hasFrameworks = YES;
                NSArray *frameworksContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:frameworksDirPath error:nil];
                for (NSString *frameworkFile in frameworksContents) {
                    NSString *extension = [[frameworkFile pathExtension] lowercaseString];
                    if ([extension isEqualTo:@"framework"] || [extension isEqualTo:@"dylib"]) {
                        frameworkPath = [frameworksDirPath stringByAppendingPathComponent:frameworkFile];
                        NSLog(@"Found %@",frameworkPath);
                        [frameworks addObject:frameworkPath];
                    }
                }
            }
            
            [statusLabel setStringValue:[NSString stringWithFormat:@"Codesigning %@",file]];
            break;
        }
    }
    
    if (appPath) {
        if ([frameworks count] > 0 || hasFrameworks) {
            [self signFile:[frameworks lastObject]];
            [frameworks removeLastObject];
        } else {
            [self signFile:appPath];
        }
    }
}

- (void)signFile:(NSString*)filePath {
    NSLog(@"Codesigning %@", filePath);
    [statusLabel setStringValue:[NSString stringWithFormat:@"Codesigning %@",filePath]];
    
    NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-fs", [certComboBox objectValue], nil];
    NSDictionary *systemVersionDictionary = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
    NSString * systemVersion = [systemVersionDictionary objectForKey:@"ProductVersion"];
    NSArray * version = [systemVersion componentsSeparatedByString:@"."];
    if ([version[0] intValue]<10 || ([version[0] intValue]==10 && ([version[1] intValue]<9 || ([version[1] intValue]==9 && [version[2] intValue]<5)))) {
        
        /*
         Before OSX 10.9, code signing requires a version 1 signature.
         The resource envelope is necessary.
         To ensure it is added, append the resource flag to the arguments.
         */
        
        NSString *resourceRulesPath = [[NSBundle mainBundle] pathForResource:@"ResourceRules" ofType:@"plist"];
        NSString *resourceRulesArgument = [NSString stringWithFormat:@"--resource-rules=%@",resourceRulesPath];
        [arguments addObject:resourceRulesArgument];
    } else {
        
        /*
         For OSX 10.9 and later, code signing requires a version 2 signature.
         The resource envelope is obsolete.
         To ensure it is ignored, remove the resource key from the Info.plist file.
         */
        
        NSString *infoPath = [NSString stringWithFormat:@"%@/Info.plist", filePath];
        NSMutableDictionary *infoDict = [NSMutableDictionary dictionaryWithContentsOfFile:infoPath];
        [infoDict removeObjectForKey:@"CFBundleResourceSpecification"];
        [infoDict writeToFile:infoPath atomically:YES];
        [arguments addObject:@"--no-strict"]; // http://stackoverflow.com/a/26204757
    }
    
    // Check if this is an extension and use its entitlements if available
    NSString *entitlementsPath = nil;
    BOOL isExtension = [[filePath pathExtension] isEqualToString:@"appex"];
    
    if (isExtension) {
        // This is an extension, check if we have custom entitlements for it
        NSString *extensionName = [filePath lastPathComponent];
        entitlementsPath = [extensionEntitlements objectForKey:extensionName];
        
        if (entitlementsPath && [entitlementsPath length] > 0) {
            NSLog(@"Using custom entitlements for extension %@: %@", extensionName, entitlementsPath);
        } else {
            NSLog(@"No custom entitlements for extension %@, will use embedded entitlements", extensionName);
        }
    } else {
        // This is not an extension, use main app entitlements
        if (![[entitlementField stringValue] isEqualToString:@""]) {
            entitlementsPath = [entitlementField stringValue];
        }
    }
    
    // Add entitlements argument if we have a path
    if (entitlementsPath && [entitlementsPath length] > 0) {
        [arguments addObject:[NSString stringWithFormat:@"--entitlements=%@", entitlementsPath]];
        NSLog(@"Adding entitlements argument: %@", entitlementsPath);
    }
    
    [arguments addObjectsFromArray:[NSArray arrayWithObjects:filePath, nil]];
    
    codesignTask = [[NSTask alloc] init];
    [codesignTask setLaunchPath:@"/usr/bin/codesign"];
    [codesignTask setArguments:arguments];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkCodesigning:) userInfo:nil repeats:TRUE];
    
    
    NSPipe *pipe=[NSPipe pipe];
    [codesignTask setStandardOutput:pipe];
    [codesignTask setStandardError:pipe];
    NSFileHandle *handle=[pipe fileHandleForReading];
    
    [codesignTask launch];
    
    [NSThread detachNewThreadSelector:@selector(watchCodesigning:)
                             toTarget:self withObject:handle];
}

- (void)watchCodesigning:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        
        codesigningResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        
    }
}

- (void)checkCodesigning:(NSTimer *)timer {
    if ([codesignTask isRunning] == 0) {
        [timer invalidate];
        codesignTask = nil;
        if (frameworks.count > 0) {
            [self signFile:[frameworks lastObject]];
            [frameworks removeLastObject];
        } else if (hasFrameworks) {
            hasFrameworks = NO;
            [self signFile:appPath];
        } else {
            NSLog(@"Codesigning done");
            [statusLabel setStringValue:@"Codesigning completed"];
            [self doVerifySignature];
        }
    }
}

- (void)doVerifySignature {
    if (appPath) {
        verifyTask = [[NSTask alloc] init];
        [verifyTask setLaunchPath:@"/usr/bin/codesign"];
        [verifyTask setArguments:[NSArray arrayWithObjects:@"-v", appPath, nil]];
		
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkVerificationProcess:) userInfo:nil repeats:TRUE];
        
        NSLog(@"Verifying %@",appPath);
        [statusLabel setStringValue:[NSString stringWithFormat:@"Verifying %@",appName]];
        
        NSPipe *pipe=[NSPipe pipe];
        [verifyTask setStandardOutput:pipe];
        [verifyTask setStandardError:pipe];
        NSFileHandle *handle=[pipe fileHandleForReading];
        
        [verifyTask launch];
        
        [NSThread detachNewThreadSelector:@selector(watchVerificationProcess:)
                                 toTarget:self withObject:handle];
    }
}

- (void)watchVerificationProcess:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        
        verificationResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        
    }
}

- (void)checkVerificationProcess:(NSTimer *)timer {
    if ([verifyTask isRunning] == 0) {
        [timer invalidate];
        verifyTask = nil;
        if ([verificationResult length] == 0) {
            NSLog(@"Verification done");
            [statusLabel setStringValue:@"Verification completed"];
            [self doZip];
        } else {
            NSString *error = [[codesigningResult stringByAppendingString:@"\n\n"] stringByAppendingString:verificationResult];
            [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Signing failed" AndMessage:error];
            [self enableControls];
            [statusLabel setStringValue:@"Please try again"];
        }
    }
}

- (void)doZip {
    if (appPath) {
        NSArray *destinationPathComponents = [sourcePath pathComponents];
        NSString *destinationPath = @"";
        
        for (int i = 0; i < ([destinationPathComponents count]-1); i++) {
            destinationPath = [destinationPath stringByAppendingPathComponent:[destinationPathComponents objectAtIndex:i]];
        }
        
        fileName = [sourcePath lastPathComponent];
        fileName = [fileName substringToIndex:([fileName length] - ([[sourcePath pathExtension] length] + 1))];
        fileName = [fileName stringByAppendingString:@"-resigned"];
        fileName = [fileName stringByAppendingPathExtension:@"ipa"];
        
        destinationPath = [destinationPath stringByAppendingPathComponent:fileName];
        
        NSLog(@"Dest: %@",destinationPath);
        
        zipTask = [[NSTask alloc] init];
        [zipTask setLaunchPath:@"/usr/bin/zip"];
        [zipTask setCurrentDirectoryPath:workingPath];
        [zipTask setArguments:[NSArray arrayWithObjects:@"-qry", destinationPath, @".", nil]];
		
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkZip:) userInfo:nil repeats:TRUE];
        
        NSLog(@"Zipping %@", destinationPath);
        [statusLabel setStringValue:[NSString stringWithFormat:@"Saving %@",fileName]];
        
        [zipTask launch];
    }
}

- (void)checkZip:(NSTimer *)timer {
    if ([zipTask isRunning] == 0) {
        [timer invalidate];
        zipTask = nil;
        NSLog(@"Zipping done");
        [statusLabel setStringValue:[NSString stringWithFormat:@"Saved %@",fileName]];
        
        [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];
        
        [self enableControls];
        
        NSString *result = [[codesigningResult stringByAppendingString:@"\n\n"] stringByAppendingString:verificationResult];
        NSLog(@"Codesigning result: %@",result);
    }
}

- (IBAction)browse:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"ipa", @"IPA", @"xcarchive"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [pathField setStringValue:fileNameOpened];
        
        // Save the path for next time
        [defaults setValue:fileNameOpened forKey:@"IPA_PATH"];
        [defaults synchronize];
    }
}

- (IBAction)provisioningBrowse:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"mobileprovision", @"MOBILEPROVISION"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [provisioningPathField setStringValue:fileNameOpened];
        
        // Save the path for next time
        [defaults setValue:fileNameOpened forKey:@"MOBILEPROVISION_PATH"];
        [defaults synchronize];
        
        // Auto-generate entitlements from provisioning profile
        [self generateEntitlementsFromProfile:fileNameOpened];
    }
}

- (IBAction)entitlementBrowse:(id)sender {
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"plist", @"PLIST"]];
    
    if ([openDlg runModal] == NSOKButton)
    {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        [entitlementField setStringValue:fileNameOpened];
        
        // Save the path for next time
        [defaults setValue:fileNameOpened forKey:@"ENTITLEMENT_PATH"];
        [defaults synchronize];
    }
}

- (IBAction)changeBundleIDPressed:(id)sender {
    
    if (sender != changeBundleIDCheckbox) {
        return;
    }
    
    BOOL isEnabled = (changeBundleIDCheckbox.state == NSControlStateValueOn);
    bundleIDField.enabled = isEnabled;
    
    // Save checkbox state immediately
    [defaults setValue:[NSNumber numberWithBool:isEnabled] forKey:@"BUNDLE_ID_CHANGE_ENABLED"];
    [defaults synchronize];
    
    NSLog(@"Bundle ID change %@", isEnabled ? @"enabled" : @"disabled");
}

- (void)generateEntitlementsFromProfile:(NSString *)profilePath {
    if (!profilePath || [profilePath length] == 0) {
        NSLog(@"No provisioning profile path provided");
        return;
    }
    
    NSLog(@"========================================");
    NSLog(@"Auto-generating entitlements from profile...");
    NSLog(@"Profile: %@", profilePath);
    
    // Use security command to extract profile data
    NSTask *securityTask = [[NSTask alloc] init];
    [securityTask setLaunchPath:@"/usr/bin/security"];
    [securityTask setArguments:@[@"cms", @"-D", @"-i", profilePath]];
    
    NSPipe *pipe = [NSPipe pipe];
    [securityTask setStandardOutput:pipe];
    [securityTask setStandardError:pipe];
    
    @try {
        [securityTask launch];
        [securityTask waitUntilExit];
        
        NSData *profileData = [[pipe fileHandleForReading] readDataToEndOfFile];
        
        if ([securityTask terminationStatus] != 0) {
            NSLog(@"✗ Failed to extract profile data");
            return;
        }
        
        // Parse the profile plist
        NSError *error = nil;
        NSDictionary *profileDict = [NSPropertyListSerialization propertyListWithData:profileData
                                                                              options:NSPropertyListImmutable
                                                                               format:nil
                                                                                error:&error];
        
        if (error || !profileDict) {
            NSLog(@"✗ Failed to parse profile data: %@", error);
            return;
        }
        
        // Extract entitlements
        NSDictionary *entitlements = [profileDict objectForKey:@"Entitlements"];
        
        if (!entitlements) {
            NSLog(@"✗ No Entitlements found in profile");
            return;
        }
        
        // Generate entitlements file path
        NSString *profileDir = [profilePath stringByDeletingLastPathComponent];
        NSString *profileName = [[profilePath lastPathComponent] stringByDeletingPathExtension];
        NSString *entitlementsPath = [profileDir stringByAppendingPathComponent:
                                     [NSString stringWithFormat:@"%@_entitlements.plist", profileName]];
        
        // Write entitlements to file
        NSData *entitlementsData = [NSPropertyListSerialization dataWithPropertyList:entitlements
                                                                             format:NSPropertyListXMLFormat_v1_0
                                                                            options:0
                                                                              error:&error];
        
        if (error || !entitlementsData) {
            NSLog(@"✗ Failed to serialize entitlements: %@", error);
            return;
        }
        
        if ([entitlementsData writeToFile:entitlementsPath atomically:YES]) {
            NSLog(@"✓ Generated entitlements file: %@", entitlementsPath);
            
            // Update the entitlements field
            [entitlementField setStringValue:entitlementsPath];
            
            // Save to preferences
            [defaults setValue:entitlementsPath forKey:@"ENTITLEMENT_PATH"];
            [defaults synchronize];
            
            NSLog(@"✓ Auto-set entitlements field");
            
            // Show brief info about entitlements
            NSString *appID = [entitlements objectForKey:@"application-identifier"];
            NSString *teamID = [entitlements objectForKey:@"com.apple.developer.team-identifier"];
            NSLog(@"  App ID: %@", appID);
            NSLog(@"  Team ID: %@", teamID);
        } else {
            NSLog(@"✗ Failed to write entitlements file");
        }
        
    } @catch (NSException *exception) {
        NSLog(@"✗ Exception while generating entitlements: %@", exception);
    }
    
    NSLog(@"========================================");
}

- (void)extensionBundleIDCheckboxChanged:(id)sender {
    NSButton *checkbox = (NSButton *)sender;
    
    // Find the text field associated with this checkbox
    // The checkbox is stored with key "<extensionName>_bundleid_checkbox"
    // We need to find the corresponding text field with key "<extensionName>_bundleid"
    
    for (NSString *key in [extensionTextFields allKeys]) {
        if ([key hasSuffix:@"_bundleid_checkbox"]) {
            NSButton *storedCheckbox = [extensionTextFields objectForKey:key];
            if (storedCheckbox == checkbox) {
                // Found the checkbox, get the extension name
                NSString *extensionName = [key stringByReplacingOccurrencesOfString:@"_bundleid_checkbox" withString:@""];
                NSString *textFieldKey = [NSString stringWithFormat:@"%@_bundleid", extensionName];
                NSTextField *textField = [extensionTextFields objectForKey:textFieldKey];
                
                if (textField) {
                    [textField setEnabled:(checkbox.state == NSControlStateValueOn)];
                    NSLog(@"Bundle ID text field for %@ %@", extensionName, checkbox.state == NSControlStateValueOn ? @"enabled" : @"disabled");
                }
                break;
            }
        }
    }
}

- (IBAction)manageExtensions:(id)sender {
    if ([extensions count] == 0) {
        // Need to scan for extensions first - extract the IPA temporarily
        if (![[pathField stringValue] length]) {
            [self showAlertOfKind:NSInformationalAlertStyle WithTitle:@"提示" AndMessage:@"请先选择一个 IPA 文件以检测扩展"];
            return;
        }
        
        // Preview IPA to scan for extensions
        [self previewIPAForExtensions];
        
        // Check again after preview
        if ([extensions count] == 0) {
            [self showAlertOfKind:NSInformationalAlertStyle WithTitle:@"提示" AndMessage:@"在此应用中未检测到任何扩展 (App Extensions)"];
            return;
        }
    }
    
    // Clear previous text fields
    [extensionTextFields removeAllObjects];
    
    // Show dialog to manage extensions
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"管理扩展配置"];
    [alert setInformativeText:[NSString stringWithFormat:@"检测到 %lu 个扩展。请为每个扩展配置 Provisioning Profile 和 Bundle ID：", (unsigned long)[extensions count]]];
    [alert addButtonWithTitle:@"确定"];
    [alert addButtonWithTitle:@"取消"];
    
    // Increase height to accommodate Bundle ID checkbox (now 100 pixels per extension)
    NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 450, [extensions count] * 100 + 20)];
    NSInteger yPos = [extensions count] * 100;
    
    for (NSString *extension in extensions) {
        // extension could be either a full path or just the name
        NSString *extensionName = [extension lastPathComponent];
        
        // Extension name label
        NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, yPos - 20, 450, 20)];
        [label setStringValue:extensionName];
        [label setBezeled:NO];
        [label setDrawsBackground:NO];
        [label setEditable:NO];
        [label setSelectable:NO];
        NSFont *boldFont = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];
        [label setFont:boldFont];
        [accessoryView addSubview:label];
        
        // Provisioning Profile label
        NSTextField *provisioningLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, yPos - 35, 120, 17)];
        [provisioningLabel setStringValue:@"Provisioning:"];
        [provisioningLabel setBezeled:NO];
        [provisioningLabel setDrawsBackground:NO];
        [provisioningLabel setEditable:NO];
        [provisioningLabel setSelectable:NO];
        [provisioningLabel setAlignment:NSTextAlignmentRight];
        [accessoryView addSubview:provisioningLabel];
        
        // Text field for provisioning profile path
        NSTextField *provisioningTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(125, yPos - 38, 230, 22)];
        NSString *existingProvisioningPath = [extensionProvisioningProfiles objectForKey:extensionName];
        if (existingProvisioningPath && [existingProvisioningPath length] > 0) {
            [provisioningTextField setStringValue:existingProvisioningPath];
        } else {
            [provisioningTextField setPlaceholderString:@"/path/to/.mobileprovision"];
        }
        [[provisioningTextField cell] setLineBreakMode:NSLineBreakByTruncatingHead];
        [accessoryView addSubview:provisioningTextField];
        
        // Store text field with key "<extensionName>_provisioning"
        NSString *provisioningKey = [NSString stringWithFormat:@"%@_provisioning", extensionName];
        [extensionTextFields setObject:provisioningTextField forKey:provisioningKey];
        
        // Browse button for provisioning
        NSButton *provisioningBrowseBtn = [[NSButton alloc] initWithFrame:NSMakeRect(360, yPos - 38, 80, 25)];
        [provisioningBrowseBtn setTitle:@"浏览"];
        [provisioningBrowseBtn setBezelStyle:NSRoundedBezelStyle];
        [provisioningBrowseBtn setTarget:self];
        [provisioningBrowseBtn setAction:@selector(browseForExtensionProfile:)];
        [provisioningBrowseBtn setIdentifier:extensionName];
        [accessoryView addSubview:provisioningBrowseBtn];
        
        // Bundle ID checkbox
        NSButton *bundleIDCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(0, yPos - 63, 120, 18)];
        [bundleIDCheckbox setButtonType:NSSwitchButton];
        [bundleIDCheckbox setTitle:@"修改 Bundle ID:"];
        [bundleIDCheckbox setAlignment:NSTextAlignmentRight];
        
        // Check if there's an existing Bundle ID configuration
        NSString *existingBundleID = [extensionBundleIDs objectForKey:extensionName];
        if (existingBundleID && [existingBundleID length] > 0) {
            [bundleIDCheckbox setState:NSControlStateValueOn];
        } else {
            [bundleIDCheckbox setState:NSControlStateValueOff];
        }
        
        [accessoryView addSubview:bundleIDCheckbox];
        
        // Store checkbox with key "<extensionName>_bundleid_checkbox"
        NSString *checkboxKey = [NSString stringWithFormat:@"%@_bundleid_checkbox", extensionName];
        [extensionTextFields setObject:bundleIDCheckbox forKey:checkboxKey];
        
        // Text field for Bundle ID
        NSTextField *bundleIDTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(125, yPos - 66, 315, 22)];
        if (existingBundleID && [existingBundleID length] > 0) {
            [bundleIDTextField setStringValue:existingBundleID];
            [bundleIDTextField setEnabled:YES];
        } else {
            [bundleIDTextField setPlaceholderString:@"com.company.app.extension"];
            [bundleIDTextField setEnabled:NO];
        }
        [[bundleIDTextField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
        [accessoryView addSubview:bundleIDTextField];
        
        // Store text field with key "<extensionName>_bundleid"
        NSString *bundleIDKey = [NSString stringWithFormat:@"%@_bundleid", extensionName];
        [extensionTextFields setObject:bundleIDTextField forKey:bundleIDKey];
        
        // Set checkbox action to enable/disable text field
        [bundleIDCheckbox setTarget:self];
        [bundleIDCheckbox setAction:@selector(extensionBundleIDCheckboxChanged:)];
        
        yPos -= 100;
    }
    
    [alert setAccessoryView:accessoryView];
    
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSLog(@"========== Saving Extension Configurations ==========");
        // Save the provisioning profile paths and bundle IDs
        for (NSString *extension in extensions) {
            NSString *extensionName = [extension lastPathComponent];
            
            NSLog(@"Processing extension config for: %@", extensionName);
            
            // Get provisioning profile path
            NSString *provisioningKey = [NSString stringWithFormat:@"%@_provisioning", extensionName];
            NSTextField *provisioningTextField = [extensionTextFields objectForKey:provisioningKey];
            NSString *profilePath = [provisioningTextField stringValue];
            if (profilePath && [profilePath length] > 0) {
                [extensionProvisioningProfiles setObject:profilePath forKey:extensionName];
                NSLog(@"  ✓ Saved provisioning profile: %@ -> %@", extensionName, profilePath);
            } else {
                NSLog(@"  ⚠ No provisioning profile specified for: %@", extensionName);
            }
            
            // Get Bundle ID checkbox state and value
            NSString *checkboxKey = [NSString stringWithFormat:@"%@_bundleid_checkbox", extensionName];
            NSButton *bundleIDCheckbox = [extensionTextFields objectForKey:checkboxKey];
            
            if ([bundleIDCheckbox state] == NSControlStateValueOn) {
                NSString *bundleIDKey = [NSString stringWithFormat:@"%@_bundleid", extensionName];
                NSTextField *bundleIDTextField = [extensionTextFields objectForKey:bundleIDKey];
                NSString *bundleID = [bundleIDTextField stringValue];
                if (bundleID && [bundleID length] > 0) {
                    [extensionBundleIDs setObject:bundleID forKey:extensionName];
                    NSLog(@"  ✓ Saved Bundle ID: %@ -> %@", extensionName, bundleID);
                } else {
                    NSLog(@"  ⚠ Bundle ID checkbox enabled but no Bundle ID specified for: %@", extensionName);
                }
            } else {
                // Checkbox not checked, remove any existing Bundle ID configuration
                [extensionBundleIDs removeObjectForKey:extensionName];
                NSLog(@"  ⊘ Bundle ID modification disabled for: %@", extensionName);
            }
        }
        
        // Save to NSUserDefaults for next time
        [defaults setObject:extensionProvisioningProfiles forKey:@"EXTENSION_PROVISIONING_PROFILES"];
        [defaults setObject:extensionBundleIDs forKey:@"EXTENSION_BUNDLE_IDS"];
        [defaults synchronize];
        NSLog(@"Extension configurations saved to preferences");
        NSLog(@"Final provisioning profiles dict: %@", extensionProvisioningProfiles);
        NSLog(@"Final Bundle IDs dict: %@", extensionBundleIDs);
        NSLog(@"====================================================");
    }
    
    // Clear text fields dictionary after use
    [extensionTextFields removeAllObjects];
}

- (void)browseForExtensionProfile:(id)sender {
    NSButton *button = (NSButton *)sender;
    NSString *extensionName = [button identifier];
    
    if (!extensionName || [extensionName length] == 0) {
        NSLog(@"Error: No extension name found for browse button");
        return;
    }
    
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    
    [openDlg setCanChooseFiles:TRUE];
    [openDlg setCanChooseDirectories:FALSE];
    [openDlg setAllowsMultipleSelection:FALSE];
    [openDlg setAllowsOtherFileTypes:FALSE];
    [openDlg setAllowedFileTypes:@[@"mobileprovision", @"MOBILEPROVISION"]];
    
    if ([openDlg runModal] == NSOKButton) {
        NSString* fileNameOpened = [[[openDlg URLs] objectAtIndex:0] path];
        
        // Find the text field for this extension using the correct key format
        NSString *provisioningKey = [NSString stringWithFormat:@"%@_provisioning", extensionName];
        NSTextField *textField = [extensionTextFields objectForKey:provisioningKey];
        if (textField) {
            [textField setStringValue:fileNameOpened];
            NSLog(@"✓ Updated provisioning text field for %@ with path: %@", extensionName, fileNameOpened);
        } else {
            NSLog(@"✗ Error: Text field not found for extension: %@ (key: %@)", extensionName, provisioningKey);
            NSLog(@"Available keys in extensionTextFields: %@", [extensionTextFields allKeys]);
        }
    }
}

- (void)previewIPAForExtensions {
    NSString *ipaPath = [pathField stringValue];
    
    if (!ipaPath || [ipaPath length] == 0) {
        return;
    }
    
    // Check if file exists and is an IPA or xcarchive
    if (![[[ipaPath pathExtension] lowercaseString] isEqualToString:@"ipa"] &&
        ![[[ipaPath pathExtension] lowercaseString] isEqualToString:@"xcarchive"]) {
        [self showAlertOfKind:NSWarningAlertStyle WithTitle:@"错误" AndMessage:@"请选择有效的 .ipa 或 .xcarchive 文件"];
        return;
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:ipaPath]) {
        [self showAlertOfKind:NSWarningAlertStyle WithTitle:@"错误" AndMessage:@"选定的文件不存在"];
        return;
    }
    
    NSLog(@"Preview IPA for extensions: %@", ipaPath);
    
    // Create temporary preview directory
    NSString *previewPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"com.appulize.iresign.preview"];
    [[NSFileManager defaultManager] removeItemAtPath:previewPath error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:previewPath withIntermediateDirectories:TRUE attributes:nil error:nil];
    
    if ([[[ipaPath pathExtension] lowercaseString] isEqualToString:@"ipa"]) {
        // Unzip IPA
        NSTask *unzipTask = [[NSTask alloc] init];
        [unzipTask setLaunchPath:@"/usr/bin/unzip"];
        [unzipTask setArguments:[NSArray arrayWithObjects:@"-q", ipaPath, @"-d", previewPath, nil]];
        [unzipTask launch];
        [unzipTask waitUntilExit];
        
        if ([unzipTask terminationStatus] != 0) {
            NSLog(@"Failed to unzip IPA for preview");
            [[NSFileManager defaultManager] removeItemAtPath:previewPath error:nil];
            [self showAlertOfKind:NSWarningAlertStyle WithTitle:@"错误" AndMessage:@"无法解压 IPA 文件进行预览"];
            return;
        }
    } else {
        // Handle xcarchive
        NSString* payloadPath = [previewPath stringByAppendingPathComponent:kPayloadDirName];
        [[NSFileManager defaultManager] createDirectoryAtPath:payloadPath withIntermediateDirectories:TRUE attributes:nil error:nil];
        
        NSString* infoPListPath = [ipaPath stringByAppendingPathComponent:kInfoPlistFilename];
        NSDictionary* infoPListDict = [NSDictionary dictionaryWithContentsOfFile:infoPListPath];
        
        if (infoPListDict != nil) {
            NSString* applicationPath = nil;
            NSDictionary* applicationPropertiesDict = [infoPListDict objectForKey:kKeyInfoPlistApplicationProperties];
            
            if (applicationPropertiesDict != nil) {
                applicationPath = [applicationPropertiesDict objectForKey:kKeyInfoPlistApplicationPath];
            }
            
            if (applicationPath != nil) {
                applicationPath = [[ipaPath stringByAppendingPathComponent:kProductsDirName] stringByAppendingPathComponent:applicationPath];
                
                NSTask *copyTask = [[NSTask alloc] init];
                [copyTask setLaunchPath:@"/bin/cp"];
                [copyTask setArguments:[NSArray arrayWithObjects:@"-r", applicationPath, payloadPath, nil]];
                [copyTask launch];
                [copyTask waitUntilExit];
                
                if ([copyTask terminationStatus] != 0) {
                    NSLog(@"Failed to copy xcarchive for preview");
                    [[NSFileManager defaultManager] removeItemAtPath:previewPath error:nil];
                    [self showAlertOfKind:NSWarningAlertStyle WithTitle:@"错误" AndMessage:@"无法复制 xcarchive 文件进行预览"];
                    return;
                }
            }
        }
    }
    
    // Find app path and scan for extensions
    NSString *payloadPath = [previewPath stringByAppendingPathComponent:kPayloadDirName];
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:nil];
    
    for (NSString *file in dirContents) {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"app"]) {
            NSString *tempAppPath = [payloadPath stringByAppendingPathComponent:file];
            
            // Scan for extensions
            [extensions removeAllObjects];
            [extensionEntitlements removeAllObjects];
            
            NSString *plugInsPath = [tempAppPath stringByAppendingPathComponent:@"PlugIns"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:plugInsPath]) {
                NSArray *plugInContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:plugInsPath error:nil];
                for (NSString *plugInFile in plugInContents) {
                    if ([[[plugInFile pathExtension] lowercaseString] isEqualToString:@"appex"]) {
                        // Store just the extension name, the actual path will be determined during resign
                        [extensions addObject:plugInFile];
                        NSLog(@"Found extension during preview: %@", plugInFile);
                    }
                }
            }
            
            break;
        }
    }
    
    // Clean up preview directory
    [[NSFileManager defaultManager] removeItemAtPath:previewPath error:nil];
    
    NSLog(@"Preview complete. Found %lu extension(s)", (unsigned long)[extensions count]);
}

- (void)disableControls {
    [pathField setEnabled:FALSE];
    [entitlementField setEnabled:FALSE];
    [browseButton setEnabled:FALSE];
    [resignButton setEnabled:FALSE];
    [provisioningBrowseButton setEnabled:NO];
    [provisioningPathField setEnabled:NO];
    [changeBundleIDCheckbox setEnabled:NO];
    [bundleIDField setEnabled:NO];
    [certComboBox setEnabled:NO];
    
    [flurry startAnimation:self];
    [flurry setAlphaValue:1.0];
}

- (void)enableControls {
    [pathField setEnabled:TRUE];
    [entitlementField setEnabled:TRUE];
    [browseButton setEnabled:TRUE];
    [resignButton setEnabled:TRUE];
    [provisioningBrowseButton setEnabled:YES];
    [provisioningPathField setEnabled:YES];
    [changeBundleIDCheckbox setEnabled:YES];
    [bundleIDField setEnabled:changeBundleIDCheckbox.state == NSOnState];
    [certComboBox setEnabled:YES];
    
    [flurry stopAnimation:self];
    [flurry setAlphaValue:0.5];
}

-(NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
    NSInteger count = 0;
    if ([aComboBox isEqual:certComboBox]) {
        count = [certComboBoxItems count];
    }
    return count;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index {
    id item = nil;
    if ([aComboBox isEqual:certComboBox]) {
        item = [certComboBoxItems objectAtIndex:index];
    }
    return item;
}

- (void)getCerts {
    
    getCertsResult = nil;
    
    NSLog(@"Getting Certificate IDs");
    [statusLabel setStringValue:@"Getting Signing Certificate IDs"];
    
    certTask = [[NSTask alloc] init];
    [certTask setLaunchPath:@"/usr/bin/security"];
    [certTask setArguments:[NSArray arrayWithObjects:@"find-identity", @"-v", @"-p", @"codesigning", nil]];
    
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkCerts:) userInfo:nil repeats:TRUE];
    
    NSPipe *pipe=[NSPipe pipe];
    [certTask setStandardOutput:pipe];
    [certTask setStandardError:pipe];
    NSFileHandle *handle=[pipe fileHandleForReading];
    
    [certTask launch];
    
    [NSThread detachNewThreadSelector:@selector(watchGetCerts:) toTarget:self withObject:handle];
}

- (void)watchGetCerts:(NSFileHandle*)streamHandle {
    @autoreleasepool {
        
        NSString *securityResult = [[NSString alloc] initWithData:[streamHandle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        // Verify the security result
        if (securityResult == nil || securityResult.length < 1) {
            // Nothing in the result, return
            return;
        }
        NSArray *rawResult = [securityResult componentsSeparatedByString:@"\""];
        NSMutableArray *tempGetCertsResult = [NSMutableArray arrayWithCapacity:20];
        for (int i = 0; i <= [rawResult count] - 2; i+=2) {
            
            NSLog(@"i:%d", i+1);
            if (rawResult.count - 1 < i + 1) {
                // Invalid array, don't add an object to that position
            } else {
                // Valid object
                [tempGetCertsResult addObject:[rawResult objectAtIndex:i+1]];
            }
        }
        
        certComboBoxItems = [NSMutableArray arrayWithArray:tempGetCertsResult];
        
        [certComboBox reloadData];
        
    }
}

- (void)checkCerts:(NSTimer *)timer {
    if ([certTask isRunning] == 0) {
        [timer invalidate];
        certTask = nil;
        
        if ([certComboBoxItems count] > 0) {
            NSLog(@"Get Certs done");
            [statusLabel setStringValue:@"Signing Certificate IDs extracted"];
            
            if ([defaults valueForKey:@"CERT_INDEX"]) {
                
                NSInteger selectedIndex = [[defaults valueForKey:@"CERT_INDEX"] integerValue];
                if (selectedIndex != -1) {
                    NSString *selectedItem = [self comboBox:certComboBox objectValueForItemAtIndex:selectedIndex];
                    [certComboBox setObjectValue:selectedItem];
                    [certComboBox selectItemAtIndex:selectedIndex];
                }
                
                [self enableControls];
            }
        } else {
            [self showAlertOfKind:NSCriticalAlertStyle WithTitle:@"Error" AndMessage:@"Getting Certificate ID's failed"];
            [self enableControls];
            [statusLabel setStringValue:@"Ready"];
        }
    }
}

// If the application dock icon is clicked, reopen the window
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    // Make sure the window is visible
    if (![self.window isVisible]) {
        // Window isn't shown, show it
        [self.window makeKeyAndOrderFront:self];
    }
    
    // Return YES
    return YES;
}

#pragma mark - Alert Methods

/* NSRunAlerts are being deprecated in 10.9 */

// Show a critical alert
- (void)showAlertOfKind:(NSAlertStyle)style WithTitle:(NSString *)title AndMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:title];
    [alert setInformativeText:message];
    [alert setAlertStyle:style];
    [alert runModal];
}

@end
