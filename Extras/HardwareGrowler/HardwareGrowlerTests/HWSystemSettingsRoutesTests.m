#import <XCTest/XCTest.h>

#import "../HardwareGrowler/HWSystemSettingsRoutes.h"
#import "../NetworkMonitor/HWNetworkMonitorUtilities.h"

@interface HWSystemSettingsRoutesTests : XCTestCase
@end

@implementation HWSystemSettingsRoutesTests

- (void)testSettingsRoutesUseSystemSettingsURLScheme
{
	XCTAssertTrue(HWGSystemSettingsURLStringIsRecognized(HWGBluetoothSettingsURLString));
	XCTAssertTrue(HWGSystemSettingsURLStringIsRecognized(HWGBatterySettingsURLString));
	XCTAssertTrue(HWGSystemSettingsURLStringIsRecognized(HWGBatteryFallbackSettingsURLString));
	XCTAssertTrue(HWGSystemSettingsURLStringIsRecognized(HWGNetworkSettingsURLString));
	XCTAssertTrue(HWGSystemSettingsURLStringIsRecognized(HWGWiFiSettingsURLString));
	XCTAssertTrue(HWGSystemSettingsURLStringIsRecognized(HWGVPNSettingsURLString));
}

- (void)testSettingsRouteRejectsNonSettingsURL
{
	XCTAssertFalse(HWGSystemSettingsURLStringIsRecognized(@"file:///Applications"));
	XCTAssertFalse(HWGSystemSettingsURLStringIsRecognized(nil));
}

@end
