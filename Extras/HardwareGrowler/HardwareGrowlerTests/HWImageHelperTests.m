#import <XCTest/XCTest.h>

#import "../HardwareGrowler/HardwareGrowlPlugin.h"

@interface HWImageHelperTests : XCTestCase
@end

@implementation HWImageHelperTests

- (void)testPNGDataForNilImageReturnsNil
{
	XCTAssertNil(HWGPNGDataForImage(nil, 64.0));
}

- (void)testSystemSymbolImageIsTemplateWhenSymbolExists
{
	NSImage *image = HWGSystemSymbolImage(@"bell.fill", nil);
	
	XCTAssertNotNil(image);
	XCTAssertTrue([image isTemplate]);
}

- (void)testUnknownSymbolWithoutFallbackReturnsNil
{
	NSImage *image = HWGSystemSymbolImage(@"not.a.real.symbol.for.hardwaregrowler.tests", nil);
	
	XCTAssertNil(image);
}

- (void)testPNGDataForSystemSymbolHasPNGSignature
{
	NSData *data = HWGPNGDataForSystemSymbol(@"bell.fill", nil);
	const unsigned char expectedSignature[] = {0x89, 'P', 'N', 'G'};
	
	XCTAssertNotNil(data);
	XCTAssertGreaterThan([data length], (NSUInteger)4);
	XCTAssertEqual(memcmp([data bytes], expectedSignature, sizeof(expectedSignature)), 0);
}

@end
