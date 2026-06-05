//
//  HWVolumeMonitorUtilities.h
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

static inline BOOL HWGVolumePathCanOpenInFinder(NSString *path)
{
	if (![path hasPrefix:@"/Volumes/"])
		return NO;
	
	return [path length] > [@"/Volumes/" length];
}

static inline BOOL HWGVolumeResourcePolicyShouldOpenInFinder(BOOL hidden,
															 BOOL browsable,
															 BOOL local,
															 BOOL internal,
															 BOOL ejectable,
															 BOOL removable,
															 BOOL automounted)
{
	if (hidden || !browsable || !local || automounted)
		return NO;
	
	return ejectable || removable || !internal;
}
