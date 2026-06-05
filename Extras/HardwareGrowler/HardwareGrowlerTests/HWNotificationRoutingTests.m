#import <XCTest/XCTest.h>

#import "../HardwareGrowler/HWNotificationAdapter.h"
#import "../HardwareGrowler/HardwareGrowlPlugin.h"

@interface HWNotificationRoutingAvailablePlugin : NSObject
@end

@implementation HWNotificationRoutingAvailablePlugin
@end

@interface HWNotificationRoutingUnavailablePlugin : NSObject
- (BOOL)isAvailable;
@end

@implementation HWNotificationRoutingUnavailablePlugin
- (BOOL)isAvailable { return NO; }
@end

@interface HWNotificationRoutingDisabledByDefaultPlugin : NSObject
- (BOOL)enabledByDefault;
@end

@implementation HWNotificationRoutingDisabledByDefaultPlugin
- (BOOL)enabledByDefault { return NO; }
@end

@interface HWNotificationRoutingTests : XCTestCase
@end

@implementation HWNotificationRoutingTests

- (void)testNotificationUserInfoContainsRoutingFields
{
	HWNotificationRoutingAvailablePlugin *plugin = [[[HWNotificationRoutingAvailablePlugin alloc] init] autorelease];
	NSDictionary *userInfo = HWNotificationUserInfo(@"USBConnected", plugin, @"/Volumes/Test", @"request-id");
	
	XCTAssertEqualObjects([userInfo objectForKey:HWNotificationUserInfoNameKey], @"USBConnected");
	XCTAssertEqualObjects([userInfo objectForKey:HWNotificationUserInfoPluginClassKey], @"HWNotificationRoutingAvailablePlugin");
	XCTAssertEqualObjects([userInfo objectForKey:HWNotificationUserInfoContextKey], @"/Volumes/Test");
	XCTAssertEqualObjects([userInfo objectForKey:HWNotificationUserInfoIdentifierKey], @"request-id");
}

- (void)testNotificationUserInfoOmitsNilFields
{
	NSDictionary *userInfo = HWNotificationUserInfo(nil, nil, nil, nil);
	
	XCTAssertEqual([userInfo count], (NSUInteger)0);
}

- (void)testPluginClassNameMatching
{
	HWNotificationRoutingAvailablePlugin *plugin = [[[HWNotificationRoutingAvailablePlugin alloc] init] autorelease];
	
	XCTAssertTrue(HWGPluginMatchesClassName(plugin, @"HWNotificationRoutingAvailablePlugin"));
	XCTAssertFalse(HWGPluginMatchesClassName(plugin, @"OtherPlugin"));
	XCTAssertFalse(HWGPluginMatchesClassName(plugin, nil));
}

- (void)testPluginAvailabilityDefaultsToAvailableUnlessPluginOptsOut
{
	HWNotificationRoutingAvailablePlugin *available = [[[HWNotificationRoutingAvailablePlugin alloc] init] autorelease];
	HWNotificationRoutingUnavailablePlugin *unavailable = [[[HWNotificationRoutingUnavailablePlugin alloc] init] autorelease];
	
	XCTAssertTrue(HWGPluginIsAvailable(available));
	XCTAssertFalse(HWGPluginIsAvailable(unavailable));
}

- (void)testPluginDictionaryDisabledFlag
{
	XCTAssertTrue(HWGPluginDictionaryIsDisabled([NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"disabled"]));
	XCTAssertFalse(HWGPluginDictionaryIsDisabled([NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"disabled"]));
	XCTAssertFalse(HWGPluginDictionaryIsDisabled([NSDictionary dictionary]));
}

- (void)testPluginDefaultsToEnabledWhenNoDefaultOverrideExists
{
	HWNotificationRoutingAvailablePlugin *plugin = [[[HWNotificationRoutingAvailablePlugin alloc] init] autorelease];
	
	XCTAssertFalse(HWGPluginShouldBeDisabled(plugin, @"test.plugin", nil));
}

- (void)testPluginCanOptOutOfDefaultEnablement
{
	HWNotificationRoutingDisabledByDefaultPlugin *plugin = [[[HWNotificationRoutingDisabledByDefaultPlugin alloc] init] autorelease];
	
	XCTAssertTrue(HWGPluginShouldBeDisabled(plugin, @"test.plugin", nil));
}

- (void)testStoredDisabledPreferenceOverridesPluginDefault
{
	HWNotificationRoutingDisabledByDefaultPlugin *plugin = [[[HWNotificationRoutingDisabledByDefaultPlugin alloc] init] autorelease];
	NSDictionary *storedEnabled = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"test.plugin"];
	NSDictionary *storedDisabled = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"test.plugin"];
	
	XCTAssertFalse(HWGPluginShouldBeDisabled(plugin, @"test.plugin", storedEnabled));
	XCTAssertTrue(HWGPluginShouldBeDisabled(plugin, @"test.plugin", storedDisabled));
}

@end
