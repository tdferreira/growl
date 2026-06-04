//
//  HWGrowlPluginController.h
//  HardwareGrowler
//
//  Created by Daniel Siemer on 5/2/12.
//  Copyright (c) 2012 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HardwareGrowlPlugin.h"
#import "HWNotificationAdapter.h"

@interface HWGrowlPluginController : NSObject <HWGrowlPluginControllerProtocol, HWNotificationAdapterDelegate> {
	NSMutableArray *plugins;
	NSMutableArray *notifiers;
	NSMutableArray *monitors;
	HWNotificationAdapter *notificationAdapter;
}

@property (nonatomic, retain) NSMutableArray *plugins;

-(void)loadPlugins;

@end
