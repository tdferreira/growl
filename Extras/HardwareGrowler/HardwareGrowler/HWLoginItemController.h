//
//  HWLoginItemController.h
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HWLoginItemController : NSObject

/* Enables or disables the bundled login helper through SMAppService. */
+ (BOOL)setStartAtLogin:(BOOL)enabled error:(NSError **)error;

@end
