#import <XCTest/XCTest.h>

#import "../HardwareGrowler/HWLoginItemUtilities.h"

@interface HWLoginItemUtilitiesTests : XCTestCase
@end

@implementation HWLoginItemUtilitiesTests

- (void)testEnablingRunsRegisterOperationOnly
{
	__block NSUInteger registerCount = 0;
	__block NSUInteger unregisterCount = 0;
	
	BOOL result = HWLoginItemSetEnabledWithOperations(YES, ^BOOL(NSError **error) {
		registerCount++;
		return YES;
	}, ^BOOL(NSError **error) {
		unregisterCount++;
		return NO;
	}, nil);
	
	XCTAssertTrue(result);
	XCTAssertEqual(registerCount, (NSUInteger)1);
	XCTAssertEqual(unregisterCount, (NSUInteger)0);
}

- (void)testDisablingRunsUnregisterOperationOnly
{
	__block NSUInteger registerCount = 0;
	__block NSUInteger unregisterCount = 0;
	
	BOOL result = HWLoginItemSetEnabledWithOperations(NO, ^BOOL(NSError **error) {
		registerCount++;
		return NO;
	}, ^BOOL(NSError **error) {
		unregisterCount++;
		return YES;
	}, nil);
	
	XCTAssertTrue(result);
	XCTAssertEqual(registerCount, (NSUInteger)0);
	XCTAssertEqual(unregisterCount, (NSUInteger)1);
}

- (void)testMissingOperationFails
{
	XCTAssertFalse(HWLoginItemSetEnabledWithOperations(YES, nil, nil, nil));
	XCTAssertFalse(HWLoginItemSetEnabledWithOperations(NO, nil, nil, nil));
}

@end
