//
//  TMSliderControl.h
//  HardwareGrowler
//
//  Compatibility replacement for the historical TMSliderControl dependency.
//

#import <Cocoa/Cocoa.h>

@interface TMSliderControl : NSControl {
@private
	BOOL _state;
}

@property (nonatomic, assign) BOOL state;

- (IBAction)moveLeft:(id)sender;
- (IBAction)moveRight:(id)sender;

@end
