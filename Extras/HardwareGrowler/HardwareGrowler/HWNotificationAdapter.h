//
//  HWNotificationAdapter.h
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

@class HWNotificationAdapter;

extern NSString * const HWNotificationAdapterWillHandleNotificationResponseNotification;

@protocol HWNotificationAdapterDelegate <NSObject>

- (void)notificationAdapter:(HWNotificationAdapter *)adapter
didCloseNotificationForPluginClassName:(NSString *)pluginClassName
                   context:(NSString *)context
                   byClick:(BOOL)clicked;

@end

@interface HWNotificationAdapter : NSObject <UNUserNotificationCenterDelegate>

@property (nonatomic, assign) id<HWNotificationAdapterDelegate> delegate;

- (void)requestAuthorization;

- (void)notifyWithName:(NSString *)name
                 title:(NSString *)title
           description:(NSString *)description
                  icon:(NSData *)iconData
      identifierString:(NSString *)identifier
         contextString:(NSString *)context
                plugin:(id)plugin;

@end
