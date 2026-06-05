#import <XCTest/XCTest.h>

#import "../VolumeMonitor/HWVolumeMonitorUtilities.h"

@interface HWVolumeMonitorUtilitiesTests : XCTestCase
@end

@implementation HWVolumeMonitorUtilitiesTests

- (void)testOnlyVolumesPathsCanOpenInFinder
{
	XCTAssertTrue(HWGVolumePathCanOpenInFinder(@"/Volumes/Samsung USB"));
	XCTAssertFalse(HWGVolumePathCanOpenInFinder(@"/Volumes/"));
	XCTAssertFalse(HWGVolumePathCanOpenInFinder(@"/System/Volumes/Data"));
	XCTAssertFalse(HWGVolumePathCanOpenInFinder(nil));
}

- (void)testResourcePolicyAllowsExternalUserMeaningfulVolumes
{
	XCTAssertTrue(HWGVolumeResourcePolicyShouldOpenInFinder(NO, YES, YES, NO, YES, NO, NO));
	XCTAssertTrue(HWGVolumeResourcePolicyShouldOpenInFinder(NO, YES, YES, NO, NO, YES, NO));
	XCTAssertTrue(HWGVolumeResourcePolicyShouldOpenInFinder(NO, YES, YES, NO, NO, NO, NO));
}

- (void)testResourcePolicyRejectsInternalOrSystemLikeVolumes
{
	XCTAssertFalse(HWGVolumeResourcePolicyShouldOpenInFinder(YES, YES, YES, NO, YES, NO, NO));
	XCTAssertFalse(HWGVolumeResourcePolicyShouldOpenInFinder(NO, NO, YES, NO, YES, NO, NO));
	XCTAssertFalse(HWGVolumeResourcePolicyShouldOpenInFinder(NO, YES, NO, NO, YES, NO, NO));
	XCTAssertFalse(HWGVolumeResourcePolicyShouldOpenInFinder(NO, YES, YES, NO, YES, NO, YES));
	XCTAssertFalse(HWGVolumeResourcePolicyShouldOpenInFinder(NO, YES, YES, YES, NO, NO, NO));
}

@end
