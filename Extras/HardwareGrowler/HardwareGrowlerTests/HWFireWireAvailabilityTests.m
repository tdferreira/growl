#import <XCTest/XCTest.h>

#import "../FirewireMonitor/HWFireWireAvailability.h"

static BOOL HWFireWireAvailabilityTestControllerExists(const char *serviceClassName)
{
	return strcmp(serviceClassName, "IOFireWireController") == 0;
}

static BOOL HWFireWireAvailabilityTestLocalNodeExists(const char *serviceClassName)
{
	return strcmp(serviceClassName, "IOFireWireLocalNode") == 0;
}

static BOOL HWFireWireAvailabilityTestAppleOHCIExists(const char *serviceClassName)
{
	return strcmp(serviceClassName, "AppleFWOHCI") == 0;
}

static BOOL HWFireWireAvailabilityTestNoServiceExists(const char *serviceClassName)
{
	return NO;
}

@interface HWFireWireAvailabilityTests : XCTestCase
@end

@implementation HWFireWireAvailabilityTests

- (void)testAnyKnownFireWireServiceMeansAvailable
{
	XCTAssertTrue(HWGFireWireHardwareAvailableWithServiceLookup(HWFireWireAvailabilityTestControllerExists));
	XCTAssertTrue(HWGFireWireHardwareAvailableWithServiceLookup(HWFireWireAvailabilityTestLocalNodeExists));
	XCTAssertTrue(HWGFireWireHardwareAvailableWithServiceLookup(HWFireWireAvailabilityTestAppleOHCIExists));
}

- (void)testNoKnownFireWireServiceMeansUnavailable
{
	XCTAssertFalse(HWGFireWireHardwareAvailableWithServiceLookup(HWFireWireAvailabilityTestNoServiceExists));
}

- (void)testMissingLookupMeansUnavailable
{
	XCTAssertFalse(HWGFireWireHardwareAvailableWithServiceLookup(NULL));
}

@end
