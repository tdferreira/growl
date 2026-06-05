#import <XCTest/XCTest.h>

#import "../HardwareGrowler/HWNotificationAdapter.h"
#import "../HardwareGrowler/HardwareGrowlPlugin.h"
#import "../BluetoothMonitor/HWBluetoothMonitorUtilities.h"

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

- (void)testBluetoothDisplayNamePrefersLiveNameThenKnownNameThenAddress
{
	XCTAssertEqualObjects(HWGBluetoothDisplayNameFromValues(@"Alex's AirPods 4 (ANC)", @"AirPods 4 (ANC)", @"AA-BB", @"AA-BB"), @"Alex's AirPods 4 (ANC)");
	XCTAssertEqualObjects(HWGBluetoothDisplayNameFromValues(nil, @"Alex's AirPods 4 (ANC)", @"AA-BB", @"AA-BB"), @"Alex's AirPods 4 (ANC)");
	XCTAssertEqualObjects(HWGBluetoothDisplayNameFromValues(@"Headphones", nil, @"AA-BB", @"AA-BB"), @"Headphones");
	XCTAssertEqualObjects(HWGBluetoothDisplayNameFromValues(nil, nil, @"AA-BB", @"CC-DD"), @"AA-BB");
	XCTAssertEqualObjects(HWGBluetoothDisplayNameFromValues(nil, nil, nil, @"CC-DD"), @"CC-DD");
}

- (void)testBluetoothDisplayNameFallsBackToUnknownWhenNoIdentityIsAvailable
{
	NSString *displayName = HWGBluetoothDisplayNameFromValues(@"  ", nil, @"", nil);
	
	XCTAssertEqualObjects(displayName, HWGBluetoothUnknownDeviceDisplayName());
	XCTAssertFalse(HWGBluetoothDisplayNameIsKnown(displayName));
	XCTAssertTrue(HWGBluetoothDisplayNameIsKnown(@"Mouse"));
}

- (void)testBluetoothAddressNormalizationIgnoresSeparatorsAndCase
{
	XCTAssertEqualObjects(HWGBluetoothNormalizedAddressString(@"AA-BB-CC-DD-EE-FF"), @"aabbccddeeff");
	XCTAssertEqualObjects(HWGBluetoothNormalizedAddressString(@"aa:bb:cc:dd:ee:ff"), @"aabbccddeeff");
	XCTAssertTrue(HWGBluetoothAddressStringsMatch(@"AA-BB-CC-DD-EE-FF", @"aa:bb:cc:dd:ee:ff"));
}

- (void)testBluetoothAddressNormalizationRejectsMissingAddresses
{
	XCTAssertNil(HWGBluetoothNormalizedAddressString(nil));
	XCTAssertNil(HWGBluetoothNormalizedAddressString(@" - : "));
	XCTAssertNil(HWGBluetoothNormalizedAddressString(@"AirPods"));
	XCTAssertFalse(HWGBluetoothAddressStringsMatch(nil, @"aa:bb:cc:dd:ee:ff"));
}

- (void)testBluetoothDisplayNameKeepsLiveNameWhenKnownNameDiffers
{
	XCTAssertEqualObjects(HWGBluetoothDisplayNameFromValues(@"Mouse", @"Keyboard", nil, nil), @"Mouse");
}

- (void)testBluetoothNameDiagnosticsIncludesPublicAPISources
{
	NSString *diagnostics = HWGBluetoothNameDiagnosticsDescription(@"live-connect",
																   @"AirPods 4 (ANC)",
																   @"Alex's AirPods 4 (ANC)",
																   @"AA-BB",
																   @"AA-BB",
																   @"Alex's AirPods 4 (ANC)");
	
	XCTAssertTrue([diagnostics rangeOfString:@"live-connect"].location != NSNotFound);
	XCTAssertTrue([diagnostics rangeOfString:@"Alex's AirPods 4 (ANC)"].location != NSNotFound);
}

@end
