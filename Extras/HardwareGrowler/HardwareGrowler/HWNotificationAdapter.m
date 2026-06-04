//
//  HWNotificationAdapter.m
//  HardwareGrowler
//
//  Copyright (c) 2026 The Growl Project, LLC. All rights reserved.
//

#import "HWNotificationAdapter.h"

static NSString * const HWNotificationCategoryIdentifier = @"HardwareGrowlerNotification";
static NSString * const HWNotificationUserInfoNameKey = @"notificationName";
static NSString * const HWNotificationUserInfoPluginClassKey = @"pluginClass";
static NSString * const HWNotificationUserInfoContextKey = @"context";
static NSString * const HWNotificationUserInfoIdentifierKey = @"identifier";
static NSString * const HWNotificationAttachmentDirectoryName = @"NotificationAttachments";

NSString * const HWNotificationAdapterWillHandleNotificationResponseNotification = @"HWNotificationAdapterWillHandleNotificationResponseNotification";

@implementation HWNotificationAdapter

@synthesize delegate;

- (id)init
{
	if ((self = [super init])) {
		UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
		center.delegate = self;
		
		UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:HWNotificationCategoryIdentifier
																				  actions:[NSArray array]
																		intentIdentifiers:[NSArray array]
																				  options:UNNotificationCategoryOptionCustomDismissAction];
		[center setNotificationCategories:[NSSet setWithObject:category]];
	}
	return self;
}

- (void)requestAuthorization
{
	UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound;
	[[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:options
																		completionHandler:^(BOOL granted, NSError *error) {
		if (error)
			NSLog(@"Notification authorization error: %@", error);
	}];
}

- (void)notifyWithName:(NSString *)name
                 title:(NSString *)title
           description:(NSString *)description
                  icon:(NSData *)iconData
      identifierString:(NSString *)identifier
         contextString:(NSString *)context
                plugin:(id)plugin
{
	UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
	content.title = title ? title : @"HardwareGrowler";
	content.body = description ? description : @"";
	content.sound = [UNNotificationSound defaultSound];
	content.categoryIdentifier = HWNotificationCategoryIdentifier;
	
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	if (name)
		[userInfo setObject:name forKey:HWNotificationUserInfoNameKey];
	if (plugin)
		[userInfo setObject:NSStringFromClass([plugin class]) forKey:HWNotificationUserInfoPluginClassKey];
	if (context)
		[userInfo setObject:context forKey:HWNotificationUserInfoContextKey];
	if (identifier)
		[userInfo setObject:identifier forKey:HWNotificationUserInfoIdentifierKey];
	content.userInfo = userInfo;
	
	NSString *requestIdentifier = identifier ? identifier : [[NSUUID UUID] UUIDString];
	UNNotificationAttachment *attachment = [self notificationAttachmentForIconData:iconData
																		identifier:requestIdentifier];
	if (attachment)
		content.attachments = [NSArray arrayWithObject:attachment];
	
	UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:requestIdentifier
																		  content:content
																		  trigger:nil];
	
		[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
															   withCompletionHandler:^(NSError *error) {
			if (error && [[content attachments] count]) {
				UNMutableNotificationContent *fallbackContent = [content mutableCopy];
				fallbackContent.attachments = [NSArray array];
				UNNotificationRequest *fallbackRequest = [UNNotificationRequest requestWithIdentifier:requestIdentifier
																							   content:fallbackContent
																							   trigger:nil];
				[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:fallbackRequest
																	   withCompletionHandler:^(NSError *fallbackError) {
					if (fallbackError)
						NSLog(@"Notification post error: %@", fallbackError);
				}];
				[fallbackContent release];
			} else if (error) {
				NSLog(@"Notification post error: %@", error);
			}
		}];
	
	[content release];
}

- (UNNotificationAttachment *)notificationAttachmentForIconData:(NSData *)iconData
                                                     identifier:(NSString *)identifier
{
	if (![iconData length])
		return nil;
	
	NSString *extension = [self fileExtensionForIconData:iconData];
	if (!extension)
		return nil;
	
	NSString *directoryPath = [self notificationAttachmentDirectoryPath];
	if (!directoryPath)
		return nil;
	
	NSString *fileName = [[self sanitizedAttachmentIdentifier:identifier] stringByAppendingPathExtension:extension];
	NSString *filePath = [directoryPath stringByAppendingPathComponent:fileName];
	NSError *writeError = nil;
		if (![iconData writeToFile:filePath options:NSDataWritingAtomic error:&writeError]) {
			NSLog(@"Notification icon write error: %@", writeError);
			return nil;
		}
		[[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithShort:0444]
																				  forKey:NSFilePosixPermissions]
										 ofItemAtPath:filePath
												error:nil];
		
		NSError *attachmentError = nil;
	UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:fileName
																						URL:[NSURL fileURLWithPath:filePath]
																					options:nil
																					  error:&attachmentError];
	if (!attachment)
		NSLog(@"Notification attachment error: %@", attachmentError);
	return attachment;
}

- (NSString *)notificationAttachmentDirectoryPath
{
	NSArray *cacheDirectories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *basePath = [cacheDirectories count] ? [cacheDirectories objectAtIndex:0] : NSTemporaryDirectory();
	NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier] ?: @"com.growl.hardwaregrowler";
	NSString *directoryPath = [[basePath stringByAppendingPathComponent:bundleIdentifier] stringByAppendingPathComponent:HWNotificationAttachmentDirectoryName];
	
	NSError *error = nil;
	if (![[NSFileManager defaultManager] createDirectoryAtPath:directoryPath
								   withIntermediateDirectories:YES
													attributes:nil
														 error:&error]) {
		NSLog(@"Notification attachment directory error: %@", error);
		return nil;
	}
	return directoryPath;
}

- (NSString *)fileExtensionForIconData:(NSData *)iconData
{
	const unsigned char *bytes = [iconData bytes];
	NSUInteger length = [iconData length];
	
	if (length >= 8 &&
		bytes[0] == 0x89 &&
		bytes[1] == 'P' &&
		bytes[2] == 'N' &&
		bytes[3] == 'G')
		return @"png";
	
	if (length >= 3 &&
		bytes[0] == 0xFF &&
		bytes[1] == 0xD8 &&
		bytes[2] == 0xFF)
		return @"jpg";
	
	if (length >= 4 &&
		((bytes[0] == 'I' && bytes[1] == 'I' && bytes[2] == 42 && bytes[3] == 0) ||
		 (bytes[0] == 'M' && bytes[1] == 'M' && bytes[2] == 0 && bytes[3] == 42)))
		return @"tiff";
	
	if (length >= 6 &&
		bytes[0] == 'G' &&
		bytes[1] == 'I' &&
		bytes[2] == 'F')
		return @"gif";
	
	return nil;
}

- (NSString *)sanitizedAttachmentIdentifier:(NSString *)identifier
{
	NSString *source = [identifier length] ? identifier : [[NSUUID UUID] UUIDString];
	NSMutableString *result = [NSMutableString stringWithCapacity:[source length]];
	NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_."];
	
	NSUInteger length = [source length];
	for (NSUInteger idx = 0; idx < length; idx++) {
		unichar character = [source characterAtIndex:idx];
		if ([allowed characterIsMember:character])
			[result appendFormat:@"%C", character];
		else
			[result appendString:@"_"];
	}
	return result;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
	completionHandler(UNNotificationPresentationOptionBanner |
					  UNNotificationPresentationOptionList |
					  UNNotificationPresentationOptionSound);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
	NSString *actionIdentifier = response.actionIdentifier;
	BOOL clicked = [actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier];
	BOOL dismissed = [actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier];
	
	void (^handleResponse)(void) = ^{
		if (clicked || dismissed) {
			if (clicked) {
				[[NSNotificationCenter defaultCenter] postNotificationName:HWNotificationAdapterWillHandleNotificationResponseNotification
																	object:self];
			}
			
			NSDictionary *userInfo = response.notification.request.content.userInfo;
			NSString *pluginClassName = [userInfo objectForKey:HWNotificationUserInfoPluginClassKey];
			NSString *context = [userInfo objectForKey:HWNotificationUserInfoContextKey];
			
			if ([delegate respondsToSelector:@selector(notificationAdapter:didCloseNotificationForPluginClassName:context:byClick:)]) {
				[delegate notificationAdapter:self
 didCloseNotificationForPluginClassName:pluginClassName
									  context:context
									  byClick:clicked];
			}
		}
		
		completionHandler();
	};
	
	if ([NSThread isMainThread])
		handleResponse();
	else
		dispatch_async(dispatch_get_main_queue(), handleResponse);
}

@end
