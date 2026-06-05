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

/* Best-effort VPN interface detection for notification click routing. macOS
   does not expose every third-party VPN as a single public interface type. */
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

static inline NSCharacterSet *HWGNetworkSSIDTrimCharacterSet(void)
{
	NSMutableCharacterSet *trimCharacters = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy] autorelease];
	[trimCharacters formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
	return trimCharacters;
}

/* SSID values arrive from different APIs as either NSString or NSData. Decode
   both forms and reject empty/control-only names before building notifications. */
static inline NSString *HWGNetworkStringFromSSIDValue(id ssidValue)
{
	NSCharacterSet *trimCharacters = HWGNetworkSSIDTrimCharacterSet();
	
	if ([ssidValue isKindOfClass:[NSString class]]) {
		NSString *trimmedSSID = [ssidValue stringByTrimmingCharactersInSet:trimCharacters];
		return [trimmedSSID length] ? trimmedSSID : nil;
	}
	
	if ([ssidValue isKindOfClass:[NSData class]]) {
		NSString *ssidString = [[[NSString alloc] initWithData:ssidValue encoding:NSUTF8StringEncoding] autorelease];
		if (!ssidString)
			ssidString = [[[NSString alloc] initWithData:ssidValue encoding:NSISOLatin1StringEncoding] autorelease];
		ssidString = [ssidString stringByTrimmingCharactersInSet:trimCharacters];
		return [ssidString length] ? ssidString : nil;
	}
	
	return nil;
}

/* BSSID values can also arrive as NSData from dynamic-store payloads. */
static inline NSString *HWGNetworkStringFromBSSIDValue(id bssidValue)
{
	if ([bssidValue isKindOfClass:[NSString class]])
		return [bssidValue length] ? bssidValue : nil;
	
	if ([bssidValue isKindOfClass:[NSData class]] && [bssidValue length] >= 6) {
		const unsigned char *bssidBytes = [bssidValue bytes];
		return [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
				bssidBytes[0],
				bssidBytes[1],
				bssidBytes[2],
				bssidBytes[3],
				bssidBytes[4],
				bssidBytes[5]];
	}
	
	return nil;
}
