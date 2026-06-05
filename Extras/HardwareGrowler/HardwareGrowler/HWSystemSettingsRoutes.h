//
//  HWSystemSettingsRoutes.h
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#define HWGBluetoothSettingsURLString @"x-apple.systempreferences:com.apple.BluetoothSettings"
#define HWGBatterySettingsURLString @"x-apple.systempreferences:com.apple.Battery-Settings.extension"
#define HWGBatteryFallbackSettingsURLString @"x-apple.systempreferences:com.apple.preference.battery"

static inline BOOL HWGSystemSettingsURLStringIsRecognized(NSString *urlString)
{
	if (![urlString length])
		return NO;
	
	return [urlString hasPrefix:@"x-apple.systempreferences:"];
}
