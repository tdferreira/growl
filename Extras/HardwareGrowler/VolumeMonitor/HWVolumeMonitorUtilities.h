//
//  HWVolumeMonitorUtilities.h
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

/* Notification clicks should only open user-visible mounted volumes, never
   arbitrary filesystem paths carried in a notification context. */
static inline BOOL HWGVolumePathCanOpenInFinder(NSString *path)
{
	if (![path hasPrefix:@"/Volumes/"])
		return NO;
	
	return [path length] > [@"/Volumes/" length];
}

/* Finder-open policy for volume notifications. This keeps external/removable
   media useful while avoiding internal, hidden, automounted, or system volumes. */
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
