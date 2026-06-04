#import <XCTest/XCTest.h>

#import "../NetworkMonitor/HWNetworkMonitorUtilities.h"

@interface HWNetworkMonitorUtilitiesTests : XCTestCase
@end

@implementation HWNetworkMonitorUtilitiesTests

- (void)testRecognizesCommonVPNInterfaceNames
{
	XCTAssertTrue(HWGNetworkInterfaceNameIsVPN(@"utun4"));
	XCTAssertTrue(HWGNetworkInterfaceNameIsVPN(@"ppp0"));
	XCTAssertTrue(HWGNetworkInterfaceNameIsVPN(@"ipsec0"));
	XCTAssertTrue(HWGNetworkInterfaceNameIsVPN(@"tun0"));
	XCTAssertTrue(HWGNetworkInterfaceNameIsVPN(@"tap0"));
	XCTAssertTrue(HWGNetworkInterfaceNameIsVPN(@"wg0"));
}

- (void)testDoesNotTreatOrdinaryNetworkInterfacesAsVPN
{
	XCTAssertFalse(HWGNetworkInterfaceNameIsVPN(@"en0"));
	XCTAssertFalse(HWGNetworkInterfaceNameIsVPN(@"bridge100"));
	XCTAssertFalse(HWGNetworkInterfaceNameIsVPN(@"awdl0"));
	XCTAssertFalse(HWGNetworkInterfaceNameIsVPN(nil));
}

- (void)testRoutesVPNInterfacesToVPNSettings
{
	XCTAssertEqualObjects(HWGNetworkSettingsURLStringForInterfaceName(@"utun0"), HWGVPNSettingsURLString);
}

- (void)testRoutesOrdinaryInterfacesToNetworkSettings
{
	XCTAssertEqualObjects(HWGNetworkSettingsURLStringForInterfaceName(@"en0"), HWGNetworkSettingsURLString);
}

@end
