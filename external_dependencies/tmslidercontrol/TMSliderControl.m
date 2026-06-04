//
//  TMSliderControl.m
//  HardwareGrowler
//
//  Compatibility replacement for the historical TMSliderControl dependency.
//

#import "TMSliderControl.h"

@implementation TMSliderControl

@synthesize state = _state;

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect])) {
		_state = NO;
	}
	return self;
}

- (BOOL)isFlipped
{
	return YES;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)canBecomeKeyView
{
	return YES;
}

- (void)setState:(BOOL)newState
{
	if (_state == newState)
		return;

	[self willChangeValueForKey:@"state"];
	_state = newState;
	[self didChangeValueForKey:@"state"];
	[self setNeedsDisplay:YES];
}

- (NSInteger)integerValue
{
	return self.state ? 1 : 0;
}

- (void)setIntegerValue:(NSInteger)value
{
	self.state = (value != 0);
}

- (id)objectValue
{
	return [NSNumber numberWithBool:self.state];
}

- (void)setObjectValue:(id)objectValue
{
	self.state = [objectValue boolValue];
}

- (void)drawRect:(NSRect)dirtyRect
{
	[[NSColor clearColor] set];
	NSRectFill(dirtyRect);
}

- (void)mouseDown:(NSEvent *)event
{
	if (![self isEnabled])
		return;

	self.state = !self.state;
	[self sendAction:[self action] to:[self target]];
}

- (void)keyDown:(NSEvent *)event
{
	NSString *characters = [event charactersIgnoringModifiers];
	if ([characters length] == 0) {
		[super keyDown:event];
		return;
	}

	unichar character = [characters characterAtIndex:0];
	if (character == NSRightArrowFunctionKey || character == NSCarriageReturnCharacter || character == ' ') {
		[self moveRight:self];
	} else if (character == NSLeftArrowFunctionKey) {
		[self moveLeft:self];
	} else {
		[super keyDown:event];
	}
}

- (IBAction)moveLeft:(id)sender
{
	if (![self isEnabled])
		return;

	self.state = NO;
	[self sendAction:[self action] to:[self target]];
}

- (IBAction)moveRight:(id)sender
{
	if (![self isEnabled])
		return;

	self.state = YES;
	[self sendAction:[self action] to:[self target]];
}

@end
