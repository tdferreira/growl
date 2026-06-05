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

#define HWNotificationUserInfoNameKey @"notificationName"
#define HWNotificationUserInfoPluginClassKey @"pluginClass"
#define HWNotificationUserInfoContextKey @"context"
#define HWNotificationUserInfoIdentifierKey @"identifier"

static inline NSMutableDictionary *HWNotificationUserInfo(NSString *name, id plugin, NSString *context, NSString *identifier)
{
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	if (name)
		[userInfo setObject:name forKey:HWNotificationUserInfoNameKey];
	if (plugin)
		[userInfo setObject:NSStringFromClass([plugin class]) forKey:HWNotificationUserInfoPluginClassKey];
	if (context)
		[userInfo setObject:context forKey:HWNotificationUserInfoContextKey];
	if (identifier)
		[userInfo setObject:identifier forKey:HWNotificationUserInfoIdentifierKey];
	return userInfo;
}

@protocol HWNotificationAdapterDelegate <NSObject>

- (void)notificationAdapter:(HWNotificationAdapter *)adapter
didCloseNotificationForPluginClassName:(NSString *)pluginClassName
                   context:(NSString *)context
                   byClick:(BOOL)clicked;

@end

@interface HWNotificationAdapter : NSObject <UNUserNotificationCenterDelegate>

@property (nonatomic, assign) id<HWNotificationAdapterDelegate> delegate;

- (void)requestAuthorization;

+ (void)handleNotificationResponseActionIdentifier:(NSString *)actionIdentifier
                                          userInfo:(NSDictionary *)userInfo
                                          delegate:(id<HWNotificationAdapterDelegate>)responseDelegate
                                           adapter:(HWNotificationAdapter *)adapter
                                 completionHandler:(void (^)(void))completionHandler;

- (void)notifyWithName:(NSString *)name
                 title:(NSString *)title
           description:(NSString *)description
                  icon:(NSData *)iconData
      identifierString:(NSString *)identifier
         contextString:(NSString *)context
                plugin:(id)plugin;

@end
