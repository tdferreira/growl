//
//  AppDelegate.m
//  HardwareGrowler
//
//  Created by Daniel Siemer on 5/2/12.
//  Copyright (c) 2012 The Growl Project, LLC. All rights reserved.
//

#import "AppDelegate.h"
#import "GrowlOnSwitch.h"
#import "HWGrowlPluginController.h"
#import "HWNotificationAdapter.h"
#import "HWLoginItemController.h"
#import "ACImageAndTextCell.h"

#define ShowDevicesTitle     NSLocalizedString(@"Show Connected Devices at Launch", nil)
#define QuitTitle	           NSLocalizedString(@"Quit HardwareGrowler", nil)
#define PreferencesTitle     NSLocalizedString(@"Preferences", nil)
#define OpenPreferencesTitle NSLocalizedString(@"Open HardwareGrowler Preferences...", nil)
#define IconTitle            NSLocalizedString(@"Icon:", nil)
#define StartAtLoginTitle    NSLocalizedString(@"Start HardwareGrowler at Login:", nil)
#define NoPluginPrefsTitle   NSLocalizedString(@"There are no preferences available for this monitor.", @"")
#define ModuleLabel          NSLocalizedString(@"Modules", @"")

static NSString * const HWGLoginHelperLaunchArgument = @"--hardwaregrowler-login-helper";

@interface AppDelegate ()

@property (nonatomic, assign) ProcessSerialNumber previousPSN;

@end

@implementation AppDelegate

@synthesize window = _window;
@synthesize iconPopUp;
@synthesize pluginController;

@synthesize showDevices;
@synthesize quitTitle;
@synthesize preferencesTitle;
@synthesize openPreferencesTitle;
@synthesize iconTitle;
@synthesize startAtLoginTitle;
@synthesize noPluginPrefsTitle;
@synthesize moduleLabel;

@synthesize iconInMenu;
@synthesize iconInDock;
@synthesize iconInBoth;
@synthesize noIcon;

@synthesize toolbar;
@synthesize generalItem;
@synthesize modulesItem;
@synthesize tabView;
@synthesize tableView;
@synthesize moduleColumn;
@synthesize containerView;
@synthesize noPrefsLabel;
@synthesize placeholderView;
@synthesize currentView;

@synthesize previousPSN;

+(void)initialize
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
																				[NSNumber numberWithBool:NO], @"OnLogin",
																				[NSNumber numberWithBool:YES], @"ShowExisting",
																				[NSNumber numberWithBool:NO], @"GroupNetwork",
																				[NSNumber numberWithInteger:0], @"Visibility", nil]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[super initialize];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[showDevices release];
	[quitTitle release];
	[preferencesTitle release];
	[openPreferencesTitle release];
	[iconTitle release];
	[startAtLoginTitle release];
	[noPluginPrefsTitle release];
	[moduleLabel release];
	
	[iconInMenu release];
	[iconInDock release];
		[iconInBoth release];
		[noIcon release];
		[placeholderView release];
	[pluginController release];
	[suppressPreferencesUntil release];
	[automaticPreferencesOpenDate release];
	[duplicateCleanupTimer invalidate];
	[duplicateCleanupTimer release];
	[modernGeneralView release];
	[modernModulesScrollView release];
	[modernModulesContentView release];
	[startAtLoginSwitch release];
	[showExistingSwitch release];
	[visibilitySegmentedControl release];
	[super dealloc];
}

- (BOOL)wasLaunchedByLoginHelper
{
	return [[[NSProcessInfo processInfo] arguments] containsObject:HWGLoginHelperLaunchArgument];
}

	- (void)configurePreferencesAppearance
	{
		NSColor *tableBackgroundColor = [NSColor controlBackgroundColor];
		NSColor *windowBackgroundColor = [NSColor windowBackgroundColor];
		NSScrollView *moduleScrollView = [tableView enclosingScrollView];
		NSClipView *moduleClipView = [moduleScrollView contentView];
		
	[tableView setUsesAlternatingRowBackgroundColors:NO];
	[tableView setBackgroundColor:tableBackgroundColor];
	[moduleScrollView setDrawsBackground:YES];
	[moduleScrollView setBackgroundColor:tableBackgroundColor];
	[moduleClipView setDrawsBackground:YES];
	[moduleClipView setBackgroundColor:tableBackgroundColor];
	
	[noPrefsLabel setStringValue:NoPluginPrefsTitle];
	[noPrefsLabel setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
	[noPrefsLabel setTextColor:[NSColor secondaryLabelColor]];
	[noPrefsLabel setDrawsBackground:NO];
		[noPrefsLabel setBordered:NO];
		[noPrefsLabel setEditable:NO];
		[noPrefsLabel setSelectable:NO];
		
		if ([containerView respondsToSelector:@selector(setAppearance:)])
			[containerView setAppearance:nil];
		if ([placeholderView respondsToSelector:@selector(setAppearance:)])
			[placeholderView setAppearance:nil];
		
		[self.window setBackgroundColor:windowBackgroundColor];
	[tableView reloadData];
	}

- (NSTextField *)modernLabelWithString:(NSString *)string
                                  font:(NSFont *)font
                             textColor:(NSColor *)textColor
{
	NSTextField *label = [[[NSTextField alloc] initWithFrame:NSZeroRect] autorelease];
	[label setStringValue:string ?: @""];
	[label setFont:font];
	[label setTextColor:textColor];
	[label setBezeled:NO];
	[label setBordered:NO];
	[label setDrawsBackground:NO];
	[label setEditable:NO];
	[label setSelectable:NO];
	return label;
}

- (void)setTopAnchoredAutoresizingMaskForView:(NSView *)view
{
	[view setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
}

- (void)setTopRightAnchoredAutoresizingMaskForView:(NSView *)view
{
	[view setAutoresizingMask:NSViewMinYMargin | NSViewMinXMargin];
}

- (void)installModernGeneralPane
{
	NSView *generalPane = [[tabView tabViewItemAtIndex:0] view];
	for (NSView *subview in [generalPane subviews])
		[subview setHidden:YES];
	
	modernGeneralView = [[NSView alloc] initWithFrame:[generalPane bounds]];
	[modernGeneralView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[generalPane addSubview:modernGeneralView];
	CGFloat topOffset = MAX(0.0, NSHeight([modernGeneralView bounds]) - 240.0);
	CGFloat contentWidth = NSWidth([modernGeneralView bounds]);
	CGFloat controlX = MAX(426.0, contentWidth - 74.0);
	
	NSTextField *title = [self modernLabelWithString:NSLocalizedString(@"General", @"")
												font:[NSFont systemFontOfSize:20.0 weight:NSFontWeightSemibold]
										   textColor:[NSColor labelColor]];
	[title setFrame:NSMakeRect(24.0, topOffset + 190.0, MAX(120.0, contentWidth - 48.0), 26.0)];
	[self setTopAnchoredAutoresizingMaskForView:title];
	[modernGeneralView addSubview:title];
	
	NSTextField *subtitle = [self modernLabelWithString:NSLocalizedString(@"Choose how HardwareGrowler appears and starts.", @"General preferences subtitle")
												   font:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]
											  textColor:[NSColor secondaryLabelColor]];
	[subtitle setFrame:NSMakeRect(24.0, topOffset + 169.0, MAX(120.0, contentWidth - 48.0), 18.0)];
	[self setTopAnchoredAutoresizingMaskForView:subtitle];
	[modernGeneralView addSubview:subtitle];
	
	NSTextField *loginTitle = [self modernLabelWithString:NSLocalizedString(@"Start at login", @"General preference row title")
													 font:[NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium]
												textColor:[NSColor labelColor]];
	[loginTitle setFrame:NSMakeRect(24.0, topOffset + 128.0, MAX(120.0, contentWidth - 116.0), 18.0)];
	[self setTopAnchoredAutoresizingMaskForView:loginTitle];
	[modernGeneralView addSubview:loginTitle];
	NSTextField *loginDetail = [self modernLabelWithString:NSLocalizedString(@"Launch HardwareGrowler automatically when you sign in.", @"General preference row detail")
													  font:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]
												 textColor:[NSColor secondaryLabelColor]];
	[loginDetail setFrame:NSMakeRect(24.0, topOffset + 108.0, MAX(120.0, contentWidth - 116.0), 18.0)];
	[self setTopAnchoredAutoresizingMaskForView:loginDetail];
	[modernGeneralView addSubview:loginDetail];
	startAtLoginSwitch = [[NSSwitch alloc] initWithFrame:NSMakeRect(controlX, topOffset + 117.0, 42.0, 25.0)];
	[startAtLoginSwitch sizeToFit];
	[self setTopRightAnchoredAutoresizingMaskForView:startAtLoginSwitch];
	[startAtLoginSwitch setTarget:self];
	[startAtLoginSwitch setAction:@selector(startAtLoginSwitchChanged:)];
	[modernGeneralView addSubview:startAtLoginSwitch];
	
	NSBox *divider = [[[NSBox alloc] initWithFrame:NSMakeRect(24.0, topOffset + 92.0, MAX(120.0, contentWidth - 48.0), 1.0)] autorelease];
	[divider setBoxType:NSBoxSeparator];
	[self setTopAnchoredAutoresizingMaskForView:divider];
	[modernGeneralView addSubview:divider];
	
	NSTextField *showTitle = [self modernLabelWithString:NSLocalizedString(@"Show connected devices at launch", @"General preference row title")
													font:[NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium]
											   textColor:[NSColor labelColor]];
	[showTitle setFrame:NSMakeRect(24.0, topOffset + 61.0, MAX(120.0, contentWidth - 116.0), 18.0)];
	[self setTopAnchoredAutoresizingMaskForView:showTitle];
	[modernGeneralView addSubview:showTitle];
	NSTextField *showDetail = [self modernLabelWithString:NSLocalizedString(@"Send a startup summary for devices that are already connected.", @"General preference row detail")
													 font:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]
												textColor:[NSColor secondaryLabelColor]];
	[showDetail setFrame:NSMakeRect(24.0, topOffset + 41.0, MAX(120.0, contentWidth - 116.0), 18.0)];
	[self setTopAnchoredAutoresizingMaskForView:showDetail];
	[modernGeneralView addSubview:showDetail];
	showExistingSwitch = [[NSSwitch alloc] initWithFrame:NSMakeRect(controlX, topOffset + 50.0, 42.0, 25.0)];
	[showExistingSwitch sizeToFit];
	[self setTopRightAnchoredAutoresizingMaskForView:showExistingSwitch];
	[showExistingSwitch setTarget:self];
	[showExistingSwitch setAction:@selector(showExistingSwitchChanged:)];
	[modernGeneralView addSubview:showExistingSwitch];
	
	NSTextField *visibilityTitle = [self modernLabelWithString:NSLocalizedString(@"App icon", @"General preference row title")
														  font:[NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium]
													 textColor:[NSColor labelColor]];
	[visibilityTitle setFrame:NSMakeRect(24.0, topOffset + 13.0, 100.0, 18.0)];
	[visibilityTitle setAutoresizingMask:NSViewMinYMargin];
	[modernGeneralView addSubview:visibilityTitle];
	visibilitySegmentedControl = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(124.0, topOffset + 8.0, MAX(160.0, contentWidth - 148.0), 28.0)];
	[visibilitySegmentedControl setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
	[visibilitySegmentedControl setSegmentCount:4];
	[visibilitySegmentedControl setTrackingMode:NSSegmentSwitchTrackingSelectOne];
	[visibilitySegmentedControl setLabel:NSLocalizedString(@"Menu Bar", @"App icon visibility option") forSegment:0];
	[visibilitySegmentedControl setLabel:NSLocalizedString(@"Dock", @"App icon visibility option") forSegment:1];
	[visibilitySegmentedControl setLabel:NSLocalizedString(@"Both", @"App icon visibility option") forSegment:2];
	[visibilitySegmentedControl setLabel:NSLocalizedString(@"Hidden", @"App icon visibility option") forSegment:3];
	[visibilitySegmentedControl setTarget:self];
	[visibilitySegmentedControl setAction:@selector(visibilitySegmentedControlChanged:)];
	[modernGeneralView addSubview:visibilitySegmentedControl];
	
	[self syncModernPreferenceControls];
}

- (void)setPreferenceView:(NSView *)view enabled:(BOOL)enabled
{
	if ([view respondsToSelector:@selector(setEnabled:)])
		[(id)view setEnabled:enabled];
	for (NSView *subview in [view subviews])
		[self setPreferenceView:subview enabled:enabled];
}

- (CGFloat)modernPreferenceHeightForPlugin:(id<HWGrowlPluginProtocol>)plugin
{
	NSView *preferencePane = [plugin preferencePane];
	if (!preferencePane)
		return 0.0;
	return MAX(44.0, [self compactHeightForPreferencePane:preferencePane]);
}

- (NSRect)visibleContentRectForPreferencePane:(NSView *)preferencePane
{
	NSRect visibleRect = NSZeroRect;
	BOOL foundSubview = NO;
	
	for (NSView *subview in [preferencePane subviews]) {
		if ([subview isHidden])
			continue;
		NSRect frame = [subview frame];
		if (NSIsEmptyRect(frame))
			continue;
		visibleRect = foundSubview ? NSUnionRect(visibleRect, frame) : frame;
		foundSubview = YES;
	}
	
	if (!foundSubview)
		return [preferencePane bounds];
	
	CGFloat padding = 8.0;
	visibleRect = NSInsetRect(visibleRect, -padding, -padding);
	NSRect bounds = [preferencePane bounds];
	visibleRect.origin.x = 0.0;
	visibleRect.size.width = NSWidth(bounds);
	visibleRect.origin.y = MAX(0.0, NSMinY(visibleRect));
	if (NSMaxY(visibleRect) > NSMaxY(bounds))
		visibleRect.size.height = NSMaxY(bounds) - NSMinY(visibleRect);
	return visibleRect;
}

	- (CGFloat)compactHeightForPreferencePane:(NSView *)preferencePane
	{
		NSRect visibleRect = [self visibleContentRectForPreferencePane:preferencePane];
		return MIN(NSHeight([preferencePane bounds]), NSHeight(visibleRect));
	}
	
	- (NSString *)moduleDescriptionForPlugin:(id<HWGrowlPluginProtocol>)plugin
	{
		NSString *pluginClassName = NSStringFromClass([plugin class]);
		NSDictionary *descriptions = [NSDictionary dictionaryWithObjectsAndKeys:
									   NSLocalizedString(@"Watches Bluetooth power changes and device connections.", @"Bluetooth module description"), @"HWGrowlBluetoothMonitor",
									   NSLocalizedString(@"Watches legacy FireWire devices as they connect or disconnect.", @"FireWire module description"), @"HWGrowlFirewireMonitor",
									   NSLocalizedString(@"Watches Caps Lock, Shift, and Fn key state changes.", @"Keyboard module description"), @"HWGrowlKeyboardMonitor",
									   NSLocalizedString(@"Watches Wi-Fi, network interfaces, and IP address changes.", @"Network module description"), @"HWGrowlNetworkMonitor",
									   NSLocalizedString(@"Watches legacy Bluetooth hands-free phone call and message events.", @"Phone module description"), @"HWGrowlPhoneMonitor",
									   NSLocalizedString(@"Watches battery level, charging, and power source changes.", @"Power module description"), @"HWGrowlPowerMonitor",
									   NSLocalizedString(@"Watches Thunderbolt devices as they connect or disconnect.", @"Thunderbolt module description"), @"HWGrowlThunderboltMonitor",
									   NSLocalizedString(@"Watches Time Machine backup start, finish, cancel, and failure events.", @"Time Machine module description"), @"HWGrowlTimeMachineMonitor",
									   NSLocalizedString(@"Watches USB devices as they connect or disconnect.", @"USB module description"), @"HWGrowlUSBMonitor",
									   NSLocalizedString(@"Watches user-mounted drives and removable volumes.", @"Volume module description"), @"HWGrowlVolumeMonitor",
									   nil];
		return [descriptions objectForKey:pluginClassName];
	}
	
	- (NSString *)configurationDescriptionForPlugin:(id<HWGrowlPluginProtocol>)plugin
	{
		NSString *pluginClassName = NSStringFromClass([plugin class]);
		NSDictionary *descriptions = [NSDictionary dictionaryWithObjectsAndKeys:
									   NSLocalizedString(@"Choose which keyboard state changes should send notifications.", @"Keyboard module configuration description"), @"HWGrowlKeyboardMonitor",
									   NSLocalizedString(@"Choose whether battery status repeats and how often it repeats.", @"Power module configuration description"), @"HWGrowlPowerMonitor",
									   NSLocalizedString(@"Choose which mounted volumes should be ignored.", @"Volume module configuration description"), @"HWGrowlVolumeMonitor",
									   nil];
		return [descriptions objectForKey:pluginClassName];
	}

- (void)reloadModernModulesPane
{
		if (!modernModulesContentView) {
			return;
		}
	
		NSArray *existingSubviews = [[[modernModulesContentView subviews] copy] autorelease];
		for (NSView *subview in existingSubviews) {
			[subview removeFromSuperview];
		}
	
		CGFloat viewportWidth = NSWidth([[modernModulesScrollView contentView] bounds]);
		if (viewportWidth <= 0.0)
			viewportWidth = NSWidth([modernModulesScrollView bounds]);
		CGFloat contentWidth = MAX(500.0, viewportWidth);
		CGFloat totalHeight = 74.0;
		CGFloat baseRowHeight = 84.0;
		CGFloat configurationDescriptionHeight = 34.0;
		
		for (NSDictionary *pluginDict in [pluginController plugins]) {
			id<HWGrowlPluginProtocol> plugin = [pluginDict objectForKey:@"plugin"];
			totalHeight += baseRowHeight;
			CGFloat preferenceHeight = [self modernPreferenceHeightForPlugin:plugin];
			if (preferenceHeight > 0.0) {
				NSString *configurationDescription = [self configurationDescriptionForPlugin:plugin];
				if ([configurationDescription length])
					totalHeight += configurationDescriptionHeight;
				totalHeight += preferenceHeight + 16.0;
			}
			totalHeight += 1.0;
		}
	totalHeight += 22.0;
	
	[modernModulesContentView setFrame:NSMakeRect(0.0, 0.0, contentWidth, totalHeight)];
	[modernModulesContentView setAutoresizingMask:NSViewWidthSizable];
	
	CGFloat y = totalHeight - 34.0;
	NSTextField *title = [self modernLabelWithString:NSLocalizedString(@"Modules", @"")
												font:[NSFont systemFontOfSize:20.0 weight:NSFontWeightSemibold]
										   textColor:[NSColor labelColor]];
	[title setFrame:NSMakeRect(24.0, y, contentWidth - 48.0, 26.0)];
	[title setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[modernModulesContentView addSubview:title];
	y -= 36.0;
	
	NSInteger rowIndex = 0;
	for (NSDictionary *pluginDict in [pluginController plugins]) {
		id<HWGrowlPluginProtocol> plugin = [pluginDict objectForKey:@"plugin"];
		BOOL enabled = ![[pluginDict objectForKey:@"disabled"] boolValue];
			NSView *preferencePane = [plugin preferencePane];
			NSRect preferenceVisibleRect = preferencePane ? [self visibleContentRectForPreferencePane:preferencePane] : NSZeroRect;
			CGFloat preferenceHeight = preferencePane ? MAX(44.0, NSHeight(preferenceVisibleRect)) : 0.0;
			NSString *configurationDescription = preferencePane ? [self configurationDescriptionForPlugin:plugin] : nil;
			CGFloat activeConfigurationDescriptionHeight = ([configurationDescription length] && preferencePane) ? configurationDescriptionHeight : 0.0;
			CGFloat rowTop = y;
			CGFloat rowHeight = baseRowHeight + (preferencePane ? activeConfigurationDescriptionHeight + preferenceHeight + 16.0 : 0.0);
			
			NSImageView *imageView = [[[NSImageView alloc] initWithFrame:NSMakeRect(24.0, rowTop - 48.0, 28.0, 28.0)] autorelease];
			[imageView setImage:[self preferenceIconForPlugin:plugin]];
			[imageView setImageScaling:NSImageScaleProportionallyDown];
			[imageView setAutoresizingMask:NSViewMinYMargin];
		[modernModulesContentView addSubview:imageView];
		
			NSTextField *nameLabel = [self modernLabelWithString:[plugin pluginDisplayName]
															font:[NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium]
													   textColor:[NSColor labelColor]];
			[nameLabel setFrame:NSMakeRect(64.0, rowTop - 34.0, MAX(80.0, contentWidth - 142.0), 18.0)];
			[nameLabel setLineBreakMode:NSLineBreakByTruncatingTail];
			[nameLabel setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
			[modernModulesContentView addSubview:nameLabel];
			
			NSTextField *descriptionLabel = [self modernLabelWithString:[self moduleDescriptionForPlugin:plugin]
																	font:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]
															   textColor:[NSColor secondaryLabelColor]];
			[descriptionLabel setFrame:NSMakeRect(64.0, rowTop - 66.0, MAX(80.0, contentWidth - 142.0), 34.0)];
			[descriptionLabel setLineBreakMode:NSLineBreakByWordWrapping];
			[descriptionLabel setUsesSingleLineMode:NO];
			[descriptionLabel setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
			[modernModulesContentView addSubview:descriptionLabel];
			
			NSSwitch *moduleSwitch = [[[NSSwitch alloc] initWithFrame:NSMakeRect(0.0, 0.0, 42.0, 25.0)] autorelease];
			[moduleSwitch sizeToFit];
			NSSize switchSize = [moduleSwitch frame].size;
			[moduleSwitch setFrame:NSMakeRect(contentWidth - switchSize.width - 24.0,
											  rowTop - 44.0,
											  switchSize.width,
											  switchSize.height)];
		[moduleSwitch setState:enabled ? NSControlStateValueOn : NSControlStateValueOff];
		[moduleSwitch setTag:rowIndex];
		[moduleSwitch setTarget:self];
		[moduleSwitch setAction:@selector(moduleSwitchChanged:)];
		[moduleSwitch setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
			[modernModulesContentView addSubview:moduleSwitch];
			
			if (activeConfigurationDescriptionHeight > 0.0) {
				NSTextField *configurationLabel = [self modernLabelWithString:configurationDescription
																		 font:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]
																	textColor:enabled ? [NSColor secondaryLabelColor] : [NSColor tertiaryLabelColor]];
				[configurationLabel setFrame:NSMakeRect(64.0,
														rowTop - baseRowHeight - activeConfigurationDescriptionHeight,
														MAX(100.0, contentWidth - 88.0),
														activeConfigurationDescriptionHeight)];
				[configurationLabel setLineBreakMode:NSLineBreakByWordWrapping];
				[configurationLabel setUsesSingleLineMode:NO];
				[configurationLabel setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
				[modernModulesContentView addSubview:configurationLabel];
			}
			
			if (preferencePane) {
				if ([preferencePane superview])
					[preferencePane removeFromSuperview];
				[preferencePane setBoundsOrigin:NSMakePoint(0.0, NSMinY(preferenceVisibleRect))];
				[preferencePane setFrame:NSMakeRect(64.0,
													rowTop - baseRowHeight - activeConfigurationDescriptionHeight - preferenceHeight - 8.0,
													MAX(100.0, contentWidth - 88.0),
													preferenceHeight)];
			[preferencePane setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
			[preferencePane setAlphaValue:enabled ? 1.0 : 0.45];
			[self setPreferenceView:preferencePane enabled:enabled];
			[modernModulesContentView addSubview:preferencePane];
		}
		
		NSBox *divider = [[[NSBox alloc] initWithFrame:NSMakeRect(24.0, rowTop - rowHeight, contentWidth - 48.0, 1.0)] autorelease];
		[divider setBoxType:NSBoxSeparator];
		[divider setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
		[modernModulesContentView addSubview:divider];
		
		y -= rowHeight + 1.0;
		rowIndex++;
	}
	
	CGFloat visibleHeight = NSHeight([[modernModulesScrollView contentView] bounds]);
	if (totalHeight > visibleHeight)
		[modernModulesContentView scrollPoint:NSMakePoint(0.0, totalHeight - visibleHeight)];
	else
		[modernModulesContentView scrollPoint:NSZeroPoint];
}

- (void)modernizeModulesPane
{
	NSView *modulesPane = [[tabView tabViewItemAtIndex:1] view];
	for (NSView *subview in [modulesPane subviews])
		[subview setHidden:YES];
	
	modernModulesScrollView = [[NSScrollView alloc] initWithFrame:[modulesPane bounds]];
	[modernModulesScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[modernModulesScrollView setBorderType:NSNoBorder];
	[modernModulesScrollView setHasVerticalScroller:YES];
	[modernModulesScrollView setDrawsBackground:NO];
	
	modernModulesContentView = [[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, NSWidth([modulesPane bounds]), NSHeight([modulesPane bounds]))];
	[modernModulesScrollView setDocumentView:modernModulesContentView];
	[modulesPane addSubview:modernModulesScrollView];
	
	[self reloadModernModulesPane];
}

- (void)modernizePreferencesWindow
{
	[self.window setTitle:NSLocalizedString(@"HardwareGrowler Settings", @"Preferences window title")];
	[self.window setContentMinSize:NSMakeSize(500.0, 260.0)];
	[self.window setDelegate:self];
	[self installModernGeneralPane];
	[self modernizeModulesPane];
}

- (void)windowDidResize:(NSNotification *)notification
{
	[self reloadModernModulesPane];
}

- (void)syncModernPreferenceControls
{
	NSUserDefaults *defaults = [[NSUserDefaultsController sharedUserDefaultsController] defaults];
	[startAtLoginSwitch setState:[defaults boolForKey:@"OnLogin"] ? NSControlStateValueOn : NSControlStateValueOff];
	[showExistingSwitch setState:[defaults boolForKey:@"ShowExisting"] ? NSControlStateValueOn : NSControlStateValueOff];
	[visibilitySegmentedControl setSelectedSegment:[defaults integerForKey:@"Visibility"]];
}

- (IBAction)startAtLoginSwitchChanged:(id)sender
{
	BOOL enabled = ([startAtLoginSwitch state] == NSControlStateValueOn);
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	[[controller values] setValue:[NSNumber numberWithBool:enabled] forKey:@"OnLogin"];
	[controller save:nil];
}

- (IBAction)showExistingSwitchChanged:(id)sender
{
	BOOL enabled = ([showExistingSwitch state] == NSControlStateValueOn);
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	[[controller values] setValue:[NSNumber numberWithBool:enabled] forKey:@"ShowExisting"];
	[controller save:nil];
}

- (IBAction)visibilitySegmentedControlChanged:(id)sender
{
	NSInteger selectedSegment = [visibilitySegmentedControl selectedSegment];
	if (selectedSegment < 0)
		return;
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	[[controller values] setValue:[NSNumber numberWithInteger:selectedSegment] forKey:@"Visibility"];
	[controller save:nil];
}

- (void) awakeFromNib {
	self.iconInMenu = NSLocalizedString(@"Show icon in the menubar", @"default option for where the icon should be seen");
	self.iconInDock = NSLocalizedString(@"Show icon in the dock", @"display the icon only in the dock");
	self.iconInBoth = NSLocalizedString(@"Show icon in both", @"display the icon in both the menubar and the dock");
	self.noIcon = NSLocalizedString(@"No icon visible", @"display no icon at all");
	
	[generalItem setLabel:NSLocalizedString(@"General", @"")];
	[modulesItem setLabel:NSLocalizedString(@"Modules", @"")];
	
	NSNumber *visibility = [[NSUserDefaults standardUserDefaults] objectForKey:@"Visibility"];
	if(visibility == nil || [visibility integerValue] == kShowIconInDock || [visibility integerValue] == kShowIconInBoth){
		[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
	}
	
	if(visibility == nil || [visibility integerValue] == kShowIconInMenu || [visibility integerValue] == kShowIconInBoth){
		[self initMenu];
	}
	
	[onLoginSwitch setState:[[[NSUserDefaultsController sharedUserDefaultsController] defaults] boolForKey:@"OnLogin"]];
   [onLoginSwitch addObserver:self 
						 forKeyPath:@"state" 
							 options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
							 context:nil];
	
	self.pluginController = [[[HWGrowlPluginController alloc] init] autorelease];
	
	ACImageAndTextCell *imageTextCell = [[[ACImageAndTextCell alloc] init] autorelease];
	[imageTextCell setTextColor:[NSColor labelColor]];
   [moduleColumn setDataCell:imageTextCell];
	[self configurePreferencesAppearance];
	[self modernizePreferencesWindow];
}

#ifndef NSFoundationVersionNumber10_7
#define NSFoundationVersionNumber10_7   833.1
#endif
	- (IBAction)showPreferences:(id)sender
	{
		preferencesOpenedAutomatically = NO;
		[self configurePreferencesAppearance];
		[NSApp activateIgnoringOtherApps:YES];
   if(![self.window isVisible]){
      [self.window center];
      [self.window setFrameAutosaveName:@"HWGrowlerPrefsWindowFrame"];
      [self.window setFrameUsingName:@"HWGrowlerPrefsWindowFrame" force:YES];
		}
		[self.window makeKeyAndOrderFront:sender];
	
		if((BOOL)isgreaterequal(NSFoundationVersionNumber, NSFoundationVersionNumber10_7)) {
			ProcessSerialNumber psn = { 0, kCurrentProcess };
			TransformProcessType(&psn, kProcessTransformToForegroundApplication);
		NSNotificationCenter *nc = [[NSWorkspace sharedWorkspace] notificationCenter];
		[nc addObserverForName:NSWorkspaceDidActivateApplicationNotification
							 object:nil
							  queue:[NSOperationQueue mainQueue]
						usingBlock:^(NSNotification *note) {
							ProcessSerialNumber newFrontPSN;
							GetFrontProcess(&newFrontPSN);
							ProcessSerialNumber growlPsn = { 0, kCurrentProcess };
							Boolean result;
							SameProcess(&newFrontPSN, &growlPsn, &result);
							if(!result){
								GetFrontProcess(&previousPSN);
							}
							}];
		}
	}
		
		- (void)showPreferencesFromAutomaticLaunchOrReopen
		{
		BOOL wasVisible = [self.window isVisible];
		[self configurePreferencesAppearance];
		[NSApp activateIgnoringOtherApps:YES];
		if(!wasVisible){
			[self.window center];
			[self.window setFrameAutosaveName:@"HWGrowlerPrefsWindowFrame"];
			[self.window setFrameUsingName:@"HWGrowlerPrefsWindowFrame" force:YES];
		}
		[self.window makeKeyAndOrderFront:self];
		
		if (!wasVisible) {
			preferencesOpenedAutomatically = YES;
			[automaticPreferencesOpenDate release];
			automaticPreferencesOpenDate = [[NSDate date] retain];
			}
		}
	
	- (void)windowWillClose:(NSNotification *)notification {
	if((BOOL)isgreaterequal(NSFoundationVersionNumber, NSFoundationVersionNumber10_7)) {
		NSNumber *value = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] valueForKey:@"Visibility"];
		HWGrowlIconState visibility = [value integerValue];
		if(visibility == kDontShowIcon || visibility == kShowIconInMenu){
			dispatch_async(dispatch_get_main_queue(), ^{
				ProcessSerialNumber psn = { 0, kCurrentProcess };
				TransformProcessType(&psn, kProcessTransformToUIElementApplication);
				SetFrontProcess(&previousPSN);
			});
		}
	}
}

- (void) initMenu{
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setMenu:statusMenu];
	
	NSImage *icon = nil;
	NSString* icon_path = [[NSBundle mainBundle] pathForResource:@"menubarIconTemplate" ofType:@"png"];
	if (icon_path) {
		icon = [[NSImage alloc] initWithContentsOfFile:icon_path];
		[icon setSize:NSMakeSize(18.0, 18.0)];
		[icon setTemplate:YES];
	}

	[statusItem setImage:icon];
	if ([statusItem respondsToSelector:@selector(button)]) {
		[[statusItem button] setImage:icon];
	}
	[icon release];
	
	[statusItem setHighlightMode:YES];
	
}

- (void) initTitles{
	self.showDevices = ShowDevicesTitle;
	self.quitTitle = QuitTitle;
	self.preferencesTitle = PreferencesTitle;
	self.openPreferencesTitle = OpenPreferencesTitle;
	self.iconTitle = IconTitle;
	self.startAtLoginTitle = StartAtLoginTitle;
	self.noPluginPrefsTitle = NoPluginPrefsTitle;
	self.moduleLabel = ModuleLabel;
}

	- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
	{
		launchedByLoginHelper = [self wasLaunchedByLoginHelper];
		if ([self terminateThisInstanceIfLoginHelperLaunchedDuplicate])
			return;
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(notificationClickWillBeHandled:)
													 name:HWNotificationAdapterWillHandleNotificationResponseNotification
												   object:nil];
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
																selector:@selector(workspaceApplicationDidLaunch:)
																	name:NSWorkspaceDidLaunchApplicationNotification
																  object:nil];
		
	[[self toolbar] setVisible:YES];
	if([[[self toolbar] items] count] == 0){
		[[self toolbar] insertItemWithItemIdentifier:@"General" atIndex:0];
		[[self toolbar] insertItemWithItemIdentifier:@"Modules" atIndex:1];
	}
	[self selectTabIndex:0];
	[self expiryCheck];
	[self initTitles];
		
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self 
																				 forKeyPath:@"values.Visibility" 
																					 options:NSKeyValueObservingOptionNew 
																					 context:nil];
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self 
																				 forKeyPath:@"values.OnLogin" 
																					 options:NSKeyValueObservingOptionNew 
																					 context:nil];
	oldIconValue = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] integerForKey:@"Visibility"];
	oldOnLoginValue = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] boolForKey:@"OnLogin"];
	
		if (!launchedByLoginHelper)
			[self schedulePreferencesOpenFromManualLaunchOrReopen];
		
		[self terminateOtherHardwareGrowlerInstances];
		duplicateCleanupTimer = [[NSTimer scheduledTimerWithTimeInterval:2.0
																  target:self
																selector:@selector(terminateOtherHardwareGrowlerInstances)
																userInfo:nil
																 repeats:YES] retain];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self terminateOtherHardwareGrowlerInstances];
		});
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self terminateOtherHardwareGrowlerInstances];
		});
	}

- (BOOL) applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
	[self schedulePreferencesOpenFromManualLaunchOrReopen];
	return YES;
}

	- (NSMenu *)applicationDockMenu:(NSApplication *)sender
{
	NSMenu *dockMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSString *title = [openPreferencesTitle length] ? openPreferencesTitle : OpenPreferencesTitle;
	NSMenuItem *preferencesItem = [[[NSMenuItem alloc] initWithTitle:title
															 action:@selector(showPreferences:)
													  keyEquivalent:@""] autorelease];
	[preferencesItem setTarget:self];
	[dockMenu addItem:preferencesItem];
	return dockMenu;
	}
	
	- (BOOL)terminateThisInstanceIfLoginHelperLaunchedDuplicate
	{
		if (!launchedByLoginHelper)
			return NO;
		
		NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
		NSArray *instances = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier];
		pid_t currentPID = [[NSProcessInfo processInfo] processIdentifier];
		for (NSRunningApplication *application in instances) {
			if ([application processIdentifier] != currentPID) {
				[NSApp terminate:self];
				return YES;
			}
		}
		return NO;
	}
	
	- (void)terminateOtherHardwareGrowlerInstances
	{
		NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
		NSArray *instances = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier];
		pid_t currentPID = [[NSProcessInfo processInfo] processIdentifier];
		for (NSRunningApplication *application in instances) {
			if ([application processIdentifier] == currentPID)
				continue;
			
			if (![application terminate])
				[application forceTerminate];
			else {
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					if (![application isTerminated])
						[application forceTerminate];
				});
			}
		}
	}
	
	- (void)workspaceApplicationDidLaunch:(NSNotification *)notification
	{
		NSRunningApplication *application = [[notification userInfo] objectForKey:NSWorkspaceApplicationKey];
		NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
		if ([[application bundleIdentifier] isEqualToString:bundleIdentifier])
			[self terminateOtherHardwareGrowlerInstances];
	}
	
	- (void)notificationClickWillBeHandled:(NSNotification *)notification
	{
		if ([NSThread isMainThread]) {
			[self suppressPreferencesOpenForNotificationInteraction];
		} else {
			dispatch_async(dispatch_get_main_queue(), ^{
				[self suppressPreferencesOpenForNotificationInteraction];
			});
		}
	}
	
	- (void)suppressPreferencesOpenForNotificationInteraction
	{
		suppressNextPreferencesOpen = YES;
		pendingPreferencesOpen = NO;
		if (preferencesOpenedAutomatically && [automaticPreferencesOpenDate timeIntervalSinceNow] > -10.0) {
			[self.window orderOut:self];
			preferencesOpenedAutomatically = NO;
		}
		[suppressPreferencesUntil release];
		suppressPreferencesUntil = [[NSDate dateWithTimeIntervalSinceNow:3.0] retain];
		
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			if ([suppressPreferencesUntil timeIntervalSinceNow] <= 0.0)
				suppressNextPreferencesOpen = NO;
		});
	}
	
	- (BOOL)shouldSuppressPreferencesOpen
	{
		if (suppressNextPreferencesOpen)
			return YES;
		return [suppressPreferencesUntil timeIntervalSinceNow] > 0.0;
	}
	
	- (void)schedulePreferencesOpenFromManualLaunchOrReopen
	{
		if ([self shouldSuppressPreferencesOpen])
			return;
		
		pendingPreferencesOpen = YES;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			if (!pendingPreferencesOpen || [self shouldSuppressPreferencesOpen])
				return;
			if (![NSApp isActive]) {
				pendingPreferencesOpen = NO;
				return;
			}
		
			pendingPreferencesOpen = NO;
			[self showPreferencesFromAutomaticLaunchOrReopen];
		});
	}

- (void)observeValueForKeyPath:(NSString*)keyPath 
							 ofObject:(id)object 
								change:(NSDictionary*)change 
							  context:(void*)context
{
	NSUserDefaultsController *defaultController = [NSUserDefaultsController sharedUserDefaultsController];
	if([keyPath isEqualToString:@"values.Visibility"])
	{
		NSNumber *value = [[defaultController defaults] valueForKey:@"Visibility"];
		HWGrowlIconState index   = [value integerValue];
		switch (index) {
			case kDontShowIcon:
				if(![[defaultController defaults] boolForKey:@"SuppressNoIconWarn"])
				{
					[NSApp activateIgnoringOtherApps:YES];
					NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Warning! Enabling this option will cause HardwareGrowler to run in the background", nil)
																defaultButton:NSLocalizedString(@"Ok", nil)
															 alternateButton:NSLocalizedString(@"Cancel", nil)
																  otherButton:nil
												informativeTextWithFormat:NSLocalizedString(@"Enabling this option will cause HardwareGrowler to run without showing a dock icon or a menu item.\n\nTo access preferences, tap HardwareGrowler in Launchpad, or open HardwareGrowler in Finder.", nil)];
					alert.showsSuppressionButton = YES;
					NSInteger allow = [alert runModal];
					if(allow == NSAlertDefaultReturn)
					{
						if([[alert suppressionButton] state] == NSOnState){
							[[defaultController defaults] setBool:YES forKey:@"SuppressNoIconWarn"];
						}
						[self warnUserAboutIcons];
						[[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
						[statusItem release];
						statusItem = nil;
					}
					else
					{
						[[defaultController defaults] setInteger:oldIconValue forKey:@"Visibility"];
						[[defaultController defaults] synchronize];
						[iconPopUp selectItemAtIndex:oldIconValue];
					}
				}else{
					[self warnUserAboutIcons];
					[[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
					[statusItem release];
					statusItem = nil;
				}
				break;
			case kShowIconInBoth:
				[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
				if(!statusItem)
					[self initMenu];
				break;
			case kShowIconInDock:
				[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
				[[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
				[statusItem release];
				statusItem = nil;
				break;
			case kShowIconInMenu:
			default:
				if(!statusItem)
					[self initMenu];
				if(oldIconValue == kShowIconInBoth || oldIconValue == kShowIconInDock)
					[self warnUserAboutIcons];
				break;
		}
		oldIconValue = index;
		[self syncModernPreferenceControls];
	}
	else if ([keyPath isEqualToString:@"values.OnLogin"])
	{
		BOOL state = [[defaultController defaults] boolForKey:@"OnLogin"];
		if(state && (oldOnLoginValue != state))
		{
			if(![[defaultController defaults] boolForKey:@"SuppressStartAtLogin"])
			{
				[NSApp activateIgnoringOtherApps:YES];
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Alert! Enabling this option will add HardwareGrowler to your login items", nil)
															defaultButton:NSLocalizedString(@"Ok", nil)
														 alternateButton:NSLocalizedString(@"Cancel", nil)
															  otherButton:nil
											informativeTextWithFormat:NSLocalizedString(@"Allowing this will let HardwareGrowler launch everytime you login, so that it is available for applications which use it at all times", nil)];
				alert.showsSuppressionButton = YES;
				NSInteger allow = [alert runModal];
				if(allow == NSAlertDefaultReturn)
				{
					if([[alert suppressionButton] state] == NSOnState){
						[[defaultController defaults] setBool:YES forKey:@"SuppressStartAtLogin"];
					}
					[self setStartAtLogin:YES];
				}
				else
				{
					[self setStartAtLogin:NO];
					[[defaultController defaults] setBool:oldOnLoginValue forKey:@"OnLogin"];
					[[defaultController defaults] synchronize];
					[onLoginSwitch setState:oldOnLoginValue];
				}
			}else{
				[self setStartAtLogin:YES];
			}
		}
		else{
			[self setStartAtLogin:NO];
		}
		oldOnLoginValue = state;
		[self syncModernPreferenceControls];
	}
	else if(object == onLoginSwitch && [keyPath isEqualToString:@"state"])
	{
		[[defaultController values] setValue:[NSNumber numberWithBool:[onLoginSwitch state]] forKey:@"OnLogin"];
		[defaultController save:nil];
	}
}

- (void)warnUserAboutIcons
{
	if((BOOL)isless(NSFoundationVersionNumber, NSFoundationVersionNumber10_7)) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:NSLocalizedString(@"This setting will take effect when Hardware Growler restarts",nil)];
		[alert runModal];
	}
}

- (void) setStartAtLogin:(BOOL)enabled {
	NSError *error = nil;
	if(![HWLoginItemController setStartAtLogin:enabled error:&error])
		NSLog(@"Failure setting HardwareGrowlerLauncher to %@start at login: %@", enabled ? @"" : @"not ", error);
}

#pragma mark Module Table

- (NSImage *)preferenceIconForPlugin:(id<HWGrowlPluginProtocol>)plugin
{
	NSString *pluginClassName = NSStringFromClass([plugin class]);
	NSDictionary *symbolNames = [NSDictionary dictionaryWithObjectsAndKeys:
								 @"antenna.radiowaves.left.and.right", @"HWGrowlBluetoothMonitor",
								 @"cable.connector", @"HWGrowlFirewireMonitor",
								 @"keyboard", @"HWGrowlKeyboardMonitor",
								 @"network", @"HWGrowlNetworkMonitor",
								 @"iphone", @"HWGrowlPhoneMonitor",
								 @"battery.100", @"HWGrowlPowerMonitor",
								 @"bolt.horizontal", @"HWGrowlThunderboltMonitor",
								 @"clock.arrow.circlepath", @"HWGrowlTimeMachineMonitor",
								 @"cable.connector", @"HWGrowlUSBMonitor",
								 @"externaldrive", @"HWGrowlVolumeMonitor",
								 nil];
	NSDictionary *fallbackNames = [NSDictionary dictionaryWithObjectsAndKeys:
								   @"HWGPrefsBluetooth", @"HWGrowlBluetoothMonitor",
								   @"HWGPrefsFireWire", @"HWGrowlFirewireMonitor",
								   @"HWGPrefsCapster", @"HWGrowlKeyboardMonitor",
								   @"HWGPrefsNetwork", @"HWGrowlNetworkMonitor",
								   @"HWGPrefsPhone", @"HWGrowlPhoneMonitor",
								   @"HWGPrefsPower", @"HWGrowlPowerMonitor",
								   @"HWGPrefsThunderbolt", @"HWGrowlThunderboltMonitor",
								   @"HWGPrefsTimeMachine", @"HWGrowlTimeMachineMonitor",
								   @"HWGPrefsUSB", @"HWGrowlUSBMonitor",
								   @"HWGPrefsDrivesVolumes", @"HWGrowlVolumeMonitor",
								   nil];
	NSString *symbolName = [symbolNames objectForKey:pluginClassName];
	if ([symbolName length]) {
		NSImage *symbolImage = HWGSystemSymbolImage(symbolName, [fallbackNames objectForKey:pluginClassName]);
		if (symbolImage)
			return symbolImage;
	}
	
	static NSImage *placeholder = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		placeholder = [HWGSystemSymbolImage(@"square.grid.2x2", @"HWGPrefsDefault") retain];
	});
	return placeholder;
}

- (void)setPluginAtRow:(NSInteger)row enabled:(BOOL)enabled
{
	if(row < 0 || (NSUInteger)row >= [[pluginController plugins] count])
		return;
	
	NSMutableDictionary *pluginDict = [[pluginController plugins] objectAtIndex:row];
	id<HWGrowlPluginProtocol> plugin = [pluginDict objectForKey:@"plugin"];
	BOOL disabled = !enabled;
	BOOL wasDisabled = [[pluginDict objectForKey:@"disabled"] boolValue];
	if (wasDisabled == disabled)
		return;
	
	[pluginDict setObject:[NSNumber numberWithBool:disabled] forKey:@"disabled"];
	if(disabled){
		if([plugin respondsToSelector:@selector(stopObserving)])
			[plugin stopObserving];
	}else{
		if([plugin respondsToSelector:@selector(startObserving)])
			[plugin startObserving];
		else if([plugin respondsToSelector:@selector(postRegistrationInit)])
			[plugin postRegistrationInit];
	}
	
	NSString *identifier = [[NSBundle bundleForClass:[plugin class]] bundleIdentifier];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *disabledDict = [[[defaults objectForKey:@"DisabledPlugins"] mutableCopy] autorelease];
	if(!disabledDict)
		disabledDict = [NSMutableDictionary dictionary];
	[disabledDict setObject:[NSNumber numberWithBool:disabled] forKey:identifier];
	[defaults setObject:disabledDict forKey:@"DisabledPlugins"];
	[defaults synchronize];
	[tableView reloadData];
	[self reloadModernModulesPane];
}

- (IBAction)moduleSwitchChanged:(id)sender
{
	[self setPluginAtRow:[sender tag] enabled:([(NSSwitch *)sender state] == NSControlStateValueOn)];
}

-(IBAction)moduleCheckbox:(id)sender {
	NSInteger selection = [tableView clickedRow];
	if(selection >= 0 && (NSUInteger)selection < [[pluginController plugins] count]){
		NSMutableDictionary *pluginDict = [[pluginController plugins] objectAtIndex:selection];
		id<HWGrowlPluginProtocol> plugin = [pluginDict objectForKey:@"plugin"];
		NSString *identifier = [[NSBundle bundleForClass:[plugin class]] bundleIdentifier];
		NSNumber *disabled = [pluginDict objectForKey:@"disabled"];
		
		if([disabled boolValue]){
			if([plugin respondsToSelector:@selector(stopObserving)])
				[plugin stopObserving];
		}else{
			if([plugin respondsToSelector:@selector(startObserving)])
				[plugin startObserving];
			else if([plugin respondsToSelector:@selector(postRegistrationInit)])
				[plugin postRegistrationInit];
		}
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSMutableDictionary *disabledDict = [[[defaults objectForKey:@"DisabledPlugins"] mutableCopy] autorelease];
		if(!disabledDict)
			disabledDict = [NSMutableDictionary dictionary];
		[disabledDict setObject:disabled forKey:identifier];
		[defaults setObject:disabledDict forKey:@"DisabledPlugins"];
		[defaults synchronize];
	}
}

- (NSView *)tableView:(NSTableView *)aTableView viewForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ((NSUInteger)rowIndex >= [[pluginController plugins] count])
		return nil;
	
	NSDictionary *pluginDict = [[pluginController plugins] objectAtIndex:rowIndex];
	id<HWGrowlPluginProtocol> plugin = [pluginDict objectForKey:@"plugin"];
	BOOL enabled = ![[pluginDict objectForKey:@"disabled"] boolValue];
	
	if (aTableColumn == moduleColumn) {
		NSView *cellView = [[[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, [aTableColumn width], 46.0)] autorelease];
		
		NSImageView *imageView = [[[NSImageView alloc] initWithFrame:NSMakeRect(10.0, 9.0, 28.0, 28.0)] autorelease];
		[imageView setImage:[self preferenceIconForPlugin:plugin]];
		[imageView setImageScaling:NSImageScaleProportionallyDown];
		[cellView addSubview:imageView];
		
		NSTextField *nameLabel = [self modernLabelWithString:[plugin pluginDisplayName]
														font:[NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium]
												   textColor:[NSColor labelColor]];
		[nameLabel setFrame:NSMakeRect(48.0, 14.0, MAX(20.0, [aTableColumn width] - 52.0), 18.0)];
		[nameLabel setLineBreakMode:NSLineBreakByTruncatingTail];
		[cellView addSubview:nameLabel];
		
		return cellView;
	}
	
	NSView *switchCellView = [[[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, [aTableColumn width], 46.0)] autorelease];
	NSSwitch *moduleSwitch = [[[NSSwitch alloc] initWithFrame:NSMakeRect(([aTableColumn width] - 42.0) / 2.0, 10.0, 42.0, 25.0)] autorelease];
	[moduleSwitch setState:enabled ? NSControlStateValueOn : NSControlStateValueOff];
	[moduleSwitch setTag:rowIndex];
	[moduleSwitch setTarget:self];
	[moduleSwitch setAction:@selector(moduleSwitchChanged:)];
	[switchCellView addSubview:moduleSwitch];
	return switchCellView;
}

-(void)tableViewSelectionDidChange:(NSNotification *)notification {
	NSInteger selection = [tableView selectedRow];
	NSView *newView = nil;
	if(selection >= 0 && (NSUInteger)selection < [[pluginController plugins] count]){
		id<HWGrowlPluginProtocol> plugin = [[[pluginController plugins] objectAtIndex:selection] objectForKey:@"plugin"];
		if([plugin preferencePane]){
			newView = [plugin preferencePane];
		}else{
			newView = placeholderView;
		}
	}else
		newView = placeholderView;
	[newView setFrameSize:[containerView frame].size];
	if([currentView superview])
		[currentView removeFromSuperview];
	[containerView addSubview:newView];
	self.currentView = newView;
	[_window recalculateKeyViewLoop];
}

- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	if (aTableColumn == moduleColumn) {
		NSCell *cell = [aTableColumn dataCellForRow:rowIndex];
		id<HWGrowlPluginProtocol> plugin = [[[pluginController plugins] objectAtIndex:rowIndex] objectForKey:@"plugin"];
		if([plugin preferenceIcon])
			[cell setImage:[plugin preferenceIcon]];
		else{
			static NSImage *placeholder = nil;
			static dispatch_once_t onceToken;
			dispatch_once(&onceToken, ^{
				placeholder = [[NSImage imageNamed:@"HWGPrefsDefault"] retain];
			});
			[cell setImage:placeholder];
		}
   }
	return nil;
}

#pragma mark Toolbar

-(void)selectTabIndex:(NSInteger)tab {
	if(tab < 0 || tab > 1)
		tab = 0;
	[toolbar setSelectedItemIdentifier:[NSString stringWithFormat:@"%ld", tab]];
	[tabView selectTabViewItemAtIndex:tab];
}

-(IBAction)selectTab:(id)sender {
	[self selectTabIndex:[sender tag]];
}

-(BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
	return YES;
}

-(NSArray*)toolbarSelectableItemIdentifiers:(NSToolbar*)aToolbar
{
	return [NSArray arrayWithObjects:@"0", @"1", nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
   return [NSArray arrayWithObjects:@"0", @"1", nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)aToolbar 
{
   return [NSArray arrayWithObjects:@"0", @"1", nil];
}

#ifdef BETA
#define DAYSTOEXPIRY 21
- (NSCalendarDate *)dateWithString:(NSString *)str {
	str = [str stringByReplacingOccurrencesOfString:@"  " withString:@" "];
	NSArray *dateParts = [str componentsSeparatedByString:@" "];
	int month = 1;
	NSString *monthString = [dateParts objectAtIndex:0];
	if ([monthString isEqualToString:@"Feb"]) {
		month = 2;
	} else if ([monthString isEqualToString:@"Mar"]) {
		month = 3;
	} else if ([monthString isEqualToString:@"Apr"]) {
		month = 4;
	} else if ([monthString isEqualToString:@"May"]) {
		month = 5;
	} else if ([monthString isEqualToString:@"Jun"]) {
		month = 6;
	} else if ([monthString isEqualToString:@"Jul"]) {
		month = 7;
	} else if ([monthString isEqualToString:@"Aug"]) {
		month = 8;
	} else if ([monthString isEqualToString:@"Sep"]) {
		month = 9;
	} else if ([monthString isEqualToString:@"Oct"]) {
		month = 10;
	} else if ([monthString isEqualToString:@"Nov"]) {
		month = 11;
	} else if ([monthString isEqualToString:@"Dec"]) {
		month = 12;
	}
	
	NSString *dateString = [NSString stringWithFormat:@"%@-%d-%@ 00:00:00 +0000", [dateParts objectAtIndex:2], month, [dateParts objectAtIndex:1]];
	return [NSCalendarDate dateWithString:dateString];
}

- (BOOL)expired
{
	BOOL result = YES;
	
	NSCalendarDate* nowDate = [self dateWithString:[NSString stringWithUTF8String:__DATE__]];
	NSCalendarDate* expiryDate = [nowDate dateByAddingTimeInterval:(60*60*24* DAYSTOEXPIRY)];
	
	if ([expiryDate earlierDate:[NSDate date]] != expiryDate)
		result = NO;
	
	return result;
}

- (void)expiryCheck
{
	if([self expired])
	{
		[NSApp activateIgnoringOtherApps:YES];
		NSInteger alert = NSRunAlertPanel(@"This Beta Has Expired", [NSString stringWithFormat:@"Please download a new version to keep using %@.", [[NSProcessInfo processInfo] processName]], @"Quit", nil, nil);
		if (alert == NSOKButton) 
		{
			[NSApp terminate:self];
		}
	}
}
#else
- (void)expiryCheck{
}
#endif

@end
