//
//  HWLoginItemController.m
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import "HWLoginItemController.h"
#import <ServiceManagement/ServiceManagement.h>

static NSString * const HWLoginItemIdentifier = @"com.growl.HardwareGrowlerLauncher";

@implementation HWLoginItemController

+ (BOOL)setStartAtLogin:(BOOL)enabled error:(NSError **)error
{
	SMAppService *service = [SMAppService loginItemServiceWithIdentifier:HWLoginItemIdentifier];
	return enabled ? [service registerAndReturnError:error] : [service unregisterAndReturnError:error];
}

@end
