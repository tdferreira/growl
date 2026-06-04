//
//  HWLoginItemController.h
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HWLoginItemController : NSObject

+ (BOOL)setStartAtLogin:(BOOL)enabled error:(NSError **)error;

@end
