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

- (void)testTrimsSSIDStringsAndRejectsEmptySSIDValues
{
	XCTAssertEqualObjects(HWGNetworkStringFromSSIDValue(@"  Studio Wi-Fi\n"), @"Studio Wi-Fi");
	XCTAssertNil(HWGNetworkStringFromSSIDValue(@" \n\t"));
	XCTAssertNil(HWGNetworkStringFromSSIDValue(nil));
}

- (void)testDecodesSSIDData
{
	NSData *utf8Data = [@"Cafe Network" dataUsingEncoding:NSUTF8StringEncoding];
	
	XCTAssertEqualObjects(HWGNetworkStringFromSSIDValue(utf8Data), @"Cafe Network");
}

- (void)testFormatsBSSIDData
{
	const unsigned char bytes[] = {0x00, 0x11, 0x22, 0xAA, 0xBB, 0xCC};
	NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
	
	XCTAssertEqualObjects(HWGNetworkStringFromBSSIDValue(data), @"00:11:22:AA:BB:CC");
}

- (void)testRejectsInvalidBSSIDValues
{
	XCTAssertNil(HWGNetworkStringFromBSSIDValue(@""));
	XCTAssertNil(HWGNetworkStringFromBSSIDValue([NSData dataWithBytes:"123" length:3]));
}

@end
