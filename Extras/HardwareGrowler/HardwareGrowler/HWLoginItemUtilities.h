//
//  HWLoginItemUtilities.h
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef BOOL (^HWLoginItemOperation)(NSError **error);

static inline BOOL HWLoginItemSetEnabledWithOperations(BOOL enabled,
													   HWLoginItemOperation registerOperation,
													   HWLoginItemOperation unregisterOperation,
													   NSError **error)
{
	HWLoginItemOperation operation = enabled ? registerOperation : unregisterOperation;
	return operation ? operation(error) : NO;
}
