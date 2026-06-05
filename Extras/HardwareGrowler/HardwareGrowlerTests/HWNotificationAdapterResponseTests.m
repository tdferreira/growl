#import <XCTest/XCTest.h>

#import "../HardwareGrowler/HWNotificationAdapter.h"

@interface HWNotificationAdapterResponseDelegate : NSObject <HWNotificationAdapterDelegate>
@property (nonatomic, copy) NSString *pluginClassName;
@property (nonatomic, copy) NSString *context;
@property (nonatomic, assign) BOOL clicked;
@property (nonatomic, assign) NSUInteger callbackCount;
@end

@implementation HWNotificationAdapterResponseDelegate

- (void)dealloc
{
	[pluginClassName release];
	[context release];
	[super dealloc];
}

@synthesize pluginClassName;
@synthesize context;
@synthesize clicked;
@synthesize callbackCount;

- (void)notificationAdapter:(HWNotificationAdapter *)adapter
didCloseNotificationForPluginClassName:(NSString *)aPluginClassName
                   context:(NSString *)aContext
                   byClick:(BOOL)wasClicked
{
	self.pluginClassName = aPluginClassName;
	self.context = aContext;
	self.clicked = wasClicked;
	self.callbackCount++;
}

@end

@interface HWNotificationAdapterResponseTests : XCTestCase
@end

@implementation HWNotificationAdapterResponseTests

- (NSDictionary *)routingUserInfo
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"HWGrowlVolumeMonitor", HWNotificationUserInfoPluginClassKey,
			@"/Volumes/Samsung USB", HWNotificationUserInfoContextKey,
			nil];
}

- (void)testClickRoutesToDelegateAndPostsWillHandleNotification
{
	HWNotificationAdapterResponseDelegate *delegate = [[[HWNotificationAdapterResponseDelegate alloc] init] autorelease];
	__block NSUInteger willHandleCount = 0;
	id observer = [[NSNotificationCenter defaultCenter] addObserverForName:HWNotificationAdapterWillHandleNotificationResponseNotification
																	object:nil
																	 queue:nil
																usingBlock:^(NSNotification *note) {
		willHandleCount++;
	}];
	__block BOOL completed = NO;
	
	[HWNotificationAdapter handleNotificationResponseActionIdentifier:UNNotificationDefaultActionIdentifier
															 userInfo:[self routingUserInfo]
															 delegate:delegate
															  adapter:nil
													completionHandler:^{
		completed = YES;
	}];
	
	[[NSNotificationCenter defaultCenter] removeObserver:observer];
	XCTAssertTrue(completed);
	XCTAssertEqual(willHandleCount, (NSUInteger)1);
	XCTAssertEqual(delegate.callbackCount, (NSUInteger)1);
	XCTAssertTrue(delegate.clicked);
	XCTAssertEqualObjects(delegate.pluginClassName, @"HWGrowlVolumeMonitor");
	XCTAssertEqualObjects(delegate.context, @"/Volumes/Samsung USB");
}

- (void)testDismissRoutesToDelegateWithoutPostingWillHandleNotification
{
	HWNotificationAdapterResponseDelegate *delegate = [[[HWNotificationAdapterResponseDelegate alloc] init] autorelease];
	__block NSUInteger willHandleCount = 0;
	id observer = [[NSNotificationCenter defaultCenter] addObserverForName:HWNotificationAdapterWillHandleNotificationResponseNotification
																	object:nil
																	 queue:nil
																usingBlock:^(NSNotification *note) {
		willHandleCount++;
	}];
	
	[HWNotificationAdapter handleNotificationResponseActionIdentifier:UNNotificationDismissActionIdentifier
															 userInfo:[self routingUserInfo]
															 delegate:delegate
															  adapter:nil
													completionHandler:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:observer];
	XCTAssertEqual(willHandleCount, (NSUInteger)0);
	XCTAssertEqual(delegate.callbackCount, (NSUInteger)1);
	XCTAssertFalse(delegate.clicked);
	XCTAssertEqualObjects(delegate.context, @"/Volumes/Samsung USB");
}

- (void)testUnknownActionOnlyCompletes
{
	HWNotificationAdapterResponseDelegate *delegate = [[[HWNotificationAdapterResponseDelegate alloc] init] autorelease];
	__block BOOL completed = NO;
	
	[HWNotificationAdapter handleNotificationResponseActionIdentifier:@"com.example.unhandled"
															 userInfo:[self routingUserInfo]
															 delegate:delegate
															  adapter:nil
													completionHandler:^{
		completed = YES;
	}];
	
	XCTAssertTrue(completed);
	XCTAssertEqual(delegate.callbackCount, (NSUInteger)0);
}

@end
