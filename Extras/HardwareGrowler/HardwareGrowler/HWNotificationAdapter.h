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

/* Keys carried through UNNotificationContent.userInfo so notification clicks can
   be routed back to the original HardwareGrowler plug-in without keeping Growl. */
#define HWNotificationUserInfoNameKey @"notificationName"
#define HWNotificationUserInfoPluginClassKey @"pluginClass"
#define HWNotificationUserInfoContextKey @"context"
#define HWNotificationUserInfoIdentifierKey @"identifier"

/* Build the UserNotifications payload shared by every monitor notification. */
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

/* Mirrors Growl's old close/click callback shape so existing plug-ins can keep
   using noteClosed:byClick: through the plug-in controller. */
- (void)notificationAdapter:(HWNotificationAdapter *)adapter
didCloseNotificationForPluginClassName:(NSString *)pluginClassName
                   context:(NSString *)context
                   byClick:(BOOL)clicked;

@end

@interface HWNotificationAdapter : NSObject <UNUserNotificationCenterDelegate>

@property (nonatomic, assign) id<HWNotificationAdapterDelegate> delegate;

- (void)requestAuthorization;

/* Test seam for notification response routing; the instance delegate method
   calls this after ensuring it runs on the main thread. */
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
