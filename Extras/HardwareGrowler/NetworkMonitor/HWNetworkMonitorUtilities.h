//
//  HWNetworkMonitorUtilities.h
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#define HWGNetworkSettingsURLString @"x-apple.systempreferences:com.apple.Network-Settings.extension"
#define HWGWiFiSettingsURLString @"x-apple.systempreferences:com.apple.wifi-settings-extension"
#define HWGVPNSettingsURLString @"x-apple.systempreferences:com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension"

static inline BOOL HWGNetworkInterfaceNameIsVPN(NSString *interfaceName)
{
	NSString *lowercaseInterface = [interfaceName lowercaseString];
	if (![lowercaseInterface length])
		return NO;
	
	NSArray *vpnPrefixes = [NSArray arrayWithObjects:@"utun", @"ppp", @"ipsec", @"tun", @"tap", @"wg", nil];
	for (NSString *prefix in vpnPrefixes) {
		if ([lowercaseInterface hasPrefix:prefix])
			return YES;
	}
	
	if ([lowercaseInterface rangeOfString:@"vpn"].location != NSNotFound)
		return YES;
	
	return NO;
}

static inline NSString *HWGNetworkSettingsURLStringForInterfaceName(NSString *interfaceName)
{
	return HWGNetworkInterfaceNameIsVPN(interfaceName) ? HWGVPNSettingsURLString : HWGNetworkSettingsURLString;
}
