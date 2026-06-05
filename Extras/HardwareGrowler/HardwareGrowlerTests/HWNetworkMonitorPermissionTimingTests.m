#import <XCTest/XCTest.h>

#import "../NetworkMonitor/HWGrowlNetworkMonitor.h"

@interface HWGrowlNetworkMonitor (PermissionTimingTests)
- (void)notifyCurrentWiFiNetworkForInterface:(NSString *)interfaceName retryCount:(NSUInteger)retryCount;
- (void)notifyAirportConnectedForInterface:(NSString *)interfaceName status:(NSDictionary *)status bssid:(id)bssidValue retryCount:(NSUInteger)retryCount;
- (void)updateVPNInterface:(NSString *)interfaceName active:(BOOL)active;
@end

@interface HWNetworkMonitorPermissionTimingTests : XCTestCase
@end

@implementation HWNetworkMonitorPermissionTimingTests

- (HWGrowlNetworkMonitor *)monitorCountingLocationRequests:(NSUInteger *)requestCount
{
	HWGrowlNetworkMonitor *monitor = [[[HWGrowlNetworkMonitor alloc] init] autorelease];
	monitor.locationAuthorizationRequester = ^{
		(*requestCount)++;
	};
	return monitor;
}

- (void)testStartObservingDoesNotRequestLocation
{
	__block NSUInteger requestCount = 0;
	HWGrowlNetworkMonitor *monitor = [self monitorCountingLocationRequests:&requestCount];
	
	[monitor startObserving];
	[monitor stopObserving];
	
	XCTAssertEqual(requestCount, (NSUInteger)0);
}

- (void)testGenericVPNEventDoesNotRequestLocation
{
	__block NSUInteger requestCount = 0;
	HWGrowlNetworkMonitor *monitor = [self monitorCountingLocationRequests:&requestCount];
	
	[monitor updateVPNInterface:@"utun0" active:YES];
	
	XCTAssertEqual(requestCount, (NSUInteger)0);
}

- (void)testAirPortEventWithSSIDPayloadDoesNotRequestLocation
{
	__block NSUInteger requestCount = 0;
	HWGrowlNetworkMonitor *monitor = [self monitorCountingLocationRequests:&requestCount];
	NSDictionary *status = [NSDictionary dictionaryWithObject:@"Test Wi-Fi" forKey:@"SSID_STR"];
	
	[monitor notifyAirportConnectedForInterface:@"en0" status:status bssid:@"00:11:22:33:44:55" retryCount:0];
	
	XCTAssertEqual(requestCount, (NSUInteger)0);
}

- (void)testAirPortEventWithoutSSIDPayloadRequestsLocation
{
	__block NSUInteger requestCount = 0;
	HWGrowlNetworkMonitor *monitor = [self monitorCountingLocationRequests:&requestCount];
	
	[monitor notifyAirportConnectedForInterface:@"en0" status:[NSDictionary dictionary] bssid:nil retryCount:0];
	
	XCTAssertEqual(requestCount, (NSUInteger)1);
}

- (void)testCoreWLANWiFiEventRequestsLocation
{
	__block NSUInteger requestCount = 0;
	HWGrowlNetworkMonitor *monitor = [self monitorCountingLocationRequests:&requestCount];
	
	[monitor notifyCurrentWiFiNetworkForInterface:@"en0" retryCount:0];
	
	XCTAssertEqual(requestCount, (NSUInteger)1);
}

@end
