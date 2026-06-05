//
//  HWFireWireAvailability.h
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef BOOL (*HWGFireWireServiceLookup)(const char *serviceClassName);

static inline BOOL HWGFireWireHardwareAvailableWithServiceLookup(HWGFireWireServiceLookup serviceLookup)
{
	if (!serviceLookup)
		return NO;
	
	const char *serviceClassNames[] = {
		"IOFireWireController",
		"IOFireWireLocalNode",
		"AppleFWOHCI",
		NULL
	};
	
	for (NSUInteger index = 0; serviceClassNames[index] != NULL; index++) {
		if (serviceLookup(serviceClassNames[index]))
			return YES;
	}
	
	return NO;
}
