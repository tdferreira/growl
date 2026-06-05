#import <XCTest/XCTest.h>

#import "../HardwareGrowler/HWAppIconVisibility.h"

@interface HWAppIconVisibilityTests : XCTestCase
@end

@implementation HWAppIconVisibilityTests

- (void)testHiddenVisibilityHidesDockAndMenuBarIcons
{
	XCTAssertFalse(HWGIconVisibilityShowsDockIcon(kDontShowIcon));
	XCTAssertFalse(HWGIconVisibilityShowsMenuBarIcon(kDontShowIcon));
	XCTAssertEqual(HWGIconVisibilityActivationPolicy(kDontShowIcon), NSApplicationActivationPolicyAccessory);
	XCTAssertTrue(HWGIconVisibilityNeedsStatusItemRemoval(kDontShowIcon, YES));
	XCTAssertFalse(HWGIconVisibilityNeedsStatusItem(kDontShowIcon, NO));
}

- (void)testMenuBarVisibilityShowsOnlyMenuBarIcon
{
	XCTAssertFalse(HWGIconVisibilityShowsDockIcon(kShowIconInMenu));
	XCTAssertTrue(HWGIconVisibilityShowsMenuBarIcon(kShowIconInMenu));
	XCTAssertEqual(HWGIconVisibilityActivationPolicy(kShowIconInMenu), NSApplicationActivationPolicyAccessory);
	XCTAssertTrue(HWGIconVisibilityNeedsStatusItem(kShowIconInMenu, NO));
	XCTAssertFalse(HWGIconVisibilityNeedsStatusItemRemoval(kShowIconInMenu, YES));
}

- (void)testDockVisibilityShowsOnlyDockIcon
{
	XCTAssertTrue(HWGIconVisibilityShowsDockIcon(kShowIconInDock));
	XCTAssertFalse(HWGIconVisibilityShowsMenuBarIcon(kShowIconInDock));
	XCTAssertEqual(HWGIconVisibilityActivationPolicy(kShowIconInDock), NSApplicationActivationPolicyRegular);
	XCTAssertTrue(HWGIconVisibilityNeedsStatusItemRemoval(kShowIconInDock, YES));
	XCTAssertFalse(HWGIconVisibilityNeedsStatusItem(kShowIconInDock, NO));
}

- (void)testBothVisibilityShowsDockAndMenuBarIcons
{
	XCTAssertTrue(HWGIconVisibilityShowsDockIcon(kShowIconInBoth));
	XCTAssertTrue(HWGIconVisibilityShowsMenuBarIcon(kShowIconInBoth));
	XCTAssertEqual(HWGIconVisibilityActivationPolicy(kShowIconInBoth), NSApplicationActivationPolicyRegular);
	XCTAssertTrue(HWGIconVisibilityNeedsStatusItem(kShowIconInBoth, NO));
	XCTAssertFalse(HWGIconVisibilityNeedsStatusItemRemoval(kShowIconInBoth, YES));
}

@end
