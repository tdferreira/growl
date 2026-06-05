//
//  HWBluetoothMonitorUtilities.h
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

static inline NSString *HWGBluetoothTrimmedString(NSString *string)
{
	if (![string isKindOfClass:[NSString class]])
		return nil;
	
	NSString *trimmedString = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return [trimmedString length] ? trimmedString : nil;
}

static inline NSString *HWGBluetoothUnknownDeviceDisplayName(void)
{
	return NSLocalizedString(@"Unknown Bluetooth Device", @"Unknown Bluetooth device notification fallback");
}

static inline BOOL HWGBluetoothDisplayNameIsKnown(NSString *displayName)
{
	return [displayName length] && ![displayName isEqualToString:HWGBluetoothUnknownDeviceDisplayName()];
}

static inline NSString *HWGBluetoothNormalizedAddressString(NSString *address)
{
	NSString *trimmedAddress = HWGBluetoothTrimmedString(address);
	if (![trimmedAddress length])
		return nil;
	
	NSMutableString *normalizedAddress = [NSMutableString string];
	NSCharacterSet *hexadecimalCharacters = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
	for (NSUInteger index = 0; index < [trimmedAddress length]; index++) {
		unichar character = [trimmedAddress characterAtIndex:index];
		if ([hexadecimalCharacters characterIsMember:character])
			[normalizedAddress appendFormat:@"%C", character];
	}
	
	return [normalizedAddress length] == 12 ? [normalizedAddress lowercaseString] : nil;
}

static inline BOOL HWGBluetoothAddressStringsMatch(NSString *firstAddress, NSString *secondAddress)
{
	NSString *normalizedFirstAddress = HWGBluetoothNormalizedAddressString(firstAddress);
	NSString *normalizedSecondAddress = HWGBluetoothNormalizedAddressString(secondAddress);
	
	return [normalizedFirstAddress length] && [normalizedFirstAddress isEqualToString:normalizedSecondAddress];
}

/* Match the original Bluetooth monitor display-name priority: prefer the live
   callback name, then paired/favorite/recent public IOBluetooth names, then
   address-style fallbacks. */
static inline NSString *HWGBluetoothDisplayNameFromValues(NSString *name,
														  NSString *knownName,
														  NSString *nameOrAddress,
														  NSString *address)
{
	NSString *displayName = HWGBluetoothTrimmedString(name);
	if (!displayName)
		displayName = HWGBluetoothTrimmedString(knownName);
	if (!displayName)
		displayName = HWGBluetoothTrimmedString(nameOrAddress);
	if (!displayName)
		displayName = HWGBluetoothTrimmedString(address);
	return displayName ? displayName : HWGBluetoothUnknownDeviceDisplayName();
}

static inline NSString *HWGBluetoothNameDiagnosticsDescription(NSString *eventName,
															   NSString *name,
															   NSString *knownName,
															   NSString *nameOrAddress,
															   NSString *address,
															   NSString *displayName)
{
	if (![eventName length])
		return nil;
	
	return [NSString stringWithFormat:@"Bluetooth name diagnostics (%@): name=%@ knownName=%@ nameOrAddress=%@ address=%@ displayName=%@",
			eventName,
			HWGBluetoothTrimmedString(name) ? HWGBluetoothTrimmedString(name) : @"<nil>",
			HWGBluetoothTrimmedString(knownName) ? HWGBluetoothTrimmedString(knownName) : @"<nil>",
			HWGBluetoothTrimmedString(nameOrAddress) ? HWGBluetoothTrimmedString(nameOrAddress) : @"<nil>",
			HWGBluetoothTrimmedString(address) ? HWGBluetoothTrimmedString(address) : @"<nil>",
			HWGBluetoothTrimmedString(displayName) ? HWGBluetoothTrimmedString(displayName) : @"<nil>"];
}
