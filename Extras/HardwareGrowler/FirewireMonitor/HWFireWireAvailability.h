//
//  HWFireWireAvailability.h
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef BOOL (*HWGFireWireServiceLookup)(const char *serviceClassName);

/* FireWire is only useful on Macs or adapters that expose FireWire IORegistry
   services. The lookup callback keeps the hardware check unit-testable. */
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
