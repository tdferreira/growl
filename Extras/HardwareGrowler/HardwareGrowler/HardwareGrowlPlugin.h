//
//  HardwareGrowlPlugin.h
//  HardwareGrowler
//
//  Created by Daniel Siemer on 5/2/12.
//  Copyright (c) 2012 The Growl Project, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

static inline NSImage *HWGSystemSymbolImage(NSString *symbolName, NSString *fallbackImageName)
{
	NSImage *image = nil;
	if ([NSImage respondsToSelector:@selector(imageWithSystemSymbolName:accessibilityDescription:)]) {
		image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil];
		if (image && [NSImageSymbolConfiguration respondsToSelector:@selector(configurationWithPointSize:weight:)]) {
			NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPointSize:18.0
																									weight:NSFontWeightRegular];
			NSImage *configuredImage = [image imageWithSymbolConfiguration:configuration];
			if (configuredImage)
				image = configuredImage;
		}
		[image setTemplate:YES];
	}
	if (!image && [fallbackImageName length])
		image = [NSImage imageNamed:fallbackImageName];
	return image;
}

static inline NSData *HWGPNGDataForImage(NSImage *image, CGFloat size)
{
	if (!image)
		return nil;
	
	NSSize imageSize = [image size];
	if (imageSize.width <= 0.0 || imageSize.height <= 0.0)
		imageSize = NSMakeSize(size, size);
	
	CGFloat inset = size * 0.18;
	CGFloat maxSize = size - (inset * 2.0);
	CGFloat scale = MIN(maxSize / imageSize.width, maxSize / imageSize.height);
	NSSize drawingSize = NSMakeSize(floor(imageSize.width * scale), floor(imageSize.height * scale));
	NSRect imageRect = NSMakeRect(floor((size - drawingSize.width) / 2.0),
								  floor((size - drawingSize.height) / 2.0),
								  drawingSize.width,
								  drawingSize.height);
	BOOL templateImage = [image isTemplate];
	
	NSImage *renderedImage = [[[NSImage alloc] initWithSize:NSMakeSize(size, size)] autorelease];
	[renderedImage lockFocus];
	[[NSColor clearColor] setFill];
	NSRectFill(NSMakeRect(0.0, 0.0, size, size));
	
	[image drawInRect:imageRect
			 fromRect:NSZeroRect
			operation:NSCompositingOperationSourceOver
			 fraction:1.0
	   respectFlipped:YES
				hints:nil];
	if (templateImage) {
		[[NSColor systemBlueColor] setFill];
		NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceIn);
	}
	[renderedImage unlockFocus];
	
	NSData *tiffData = [renderedImage TIFFRepresentation];
	NSBitmapImageRep *imageRep = tiffData ? [NSBitmapImageRep imageRepWithData:tiffData] : nil;
	return [imageRep representationUsingType:NSBitmapImageFileTypePNG properties:[NSDictionary dictionary]];
}

static inline NSData *HWGPNGDataForSystemSymbol(NSString *symbolName, NSString *fallbackImageName)
{
	return HWGPNGDataForImage(HWGSystemSymbolImage(symbolName, fallbackImageName), 64.0);
}

@protocol HWGrowlPluginControllerProtocol <NSObject>
@required
-(void)notifyWithName:(NSString*)name 
					 title:(NSString*)title
			 description:(NSString*)description
					  icon:(NSData*)iconData
	  identifierString:(NSString*)identifier
		  contextString:(NSString*)context
					plugin:(id)plugin;

-(BOOL)onLaunchEnabled;
-(BOOL)pluginDisabled:(id)plugin;

@end

@protocol HWGrowlPluginProtocol <NSObject>
@required
-(void)setDelegate:(id<HWGrowlPluginControllerProtocol>)aDelegate;
-(id<HWGrowlPluginControllerProtocol>)delegate;
-(NSString*)pluginDisplayName;
-(NSImage*)preferenceIcon;
-(NSView*)preferencePane;

@optional
-(void)startObserving;
-(void)stopObserving;
-(void)postRegistrationInit;
-(BOOL)enabledByDefault;
-(BOOL)isAvailable;

@end

@protocol HWGrowlPluginNotifierProtocol <NSObject>
@required
-(NSArray*)noteNames;
-(NSDictionary*)localizedNames;
-(NSDictionary*)noteDescriptions;
-(NSArray*)defaultNotifications;

@optional
-(void)fireOnLaunchNotes;
-(void)noteClosed:(NSString*)contextString byClick:(BOOL)clicked;

@end

/* Used for purely stat monitoring plugins */
@protocol HWGrowlPluginMonitorProtocol <NSObject>
@optional
-(NSView*)menuBarSizedView;
-(NSView*)menuViewOfWidth:(CGFloat)width;

@end
