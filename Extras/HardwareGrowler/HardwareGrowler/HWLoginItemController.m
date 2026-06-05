//
//  HWLoginItemController.m
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import "HWLoginItemController.h"
#import "HWLoginItemUtilities.h"
#import <ServiceManagement/ServiceManagement.h>

static NSString * const HWLoginItemIdentifier = @"com.growl.HardwareGrowlerLauncher";

@implementation HWLoginItemController

+ (BOOL)setStartAtLogin:(BOOL)enabled error:(NSError **)error
{
	SMAppService *service = [SMAppService loginItemServiceWithIdentifier:HWLoginItemIdentifier];
	return HWLoginItemSetEnabledWithOperations(enabled,
											   ^BOOL(NSError **operationError) {
		return [service registerAndReturnError:operationError];
	}, ^BOOL(NSError **operationError) {
		return [service unregisterAndReturnError:operationError];
	}, error);
}

@end
