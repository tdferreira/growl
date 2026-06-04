//
//  HWGrowlVolumeMonitor.m
//  HardwareGrowler
//
//  Created by Daniel Siemer on 5/3/12.
//  Copyright (c) 2012 The Growl Project, LLC. All rights reserved.
//

#import "HWGrowlVolumeMonitor.h"

#define VolumeNotifierUnmountWaitSeconds	600.0
#define VolumeEjectCacheInfoIndex			0
#define VolumeEjectCacheTimerIndex			1

@implementation VolumeInfo

@synthesize iconData;
@synthesize path;
@synthesize name;

+ (NSImage*)ejectIconImage {
	static NSImage *_ejectIconImage = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_ejectIconImage = [HWGSystemSymbolImage(@"eject", @"DisksVolumes-Eject") retain];
	});
	return _ejectIconImage;
}

+ (NSData*)mountIconData {
	static NSData *_mountIconData = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_mountIconData = [HWGPNGDataForSystemSymbol(@"externaldrive", nil) retain];
	});
	return _mountIconData;
}

+ (VolumeInfo *) volumeInfoForMountWithPath:(NSString *)aPath {
	return [[[VolumeInfo alloc] initForMountWithPath:aPath] autorelease];
}

+ (VolumeInfo *) volumeInfoForUnmountWithPath:(NSString *)aPath {
	return [[[VolumeInfo alloc] initForUnmountWithPath:aPath] autorelease];
}

- (id) initForMountWithPath:(NSString *)aPath {
	if ((self = [self initWithPath:aPath])) {
		self.iconData = [VolumeInfo mountIconData];
	}
	
	return self;
}

- (id) initForUnmountWithPath:(NSString *)aPath {
	if ((self = [self initWithPath:aPath])) {
		self.iconData = HWGPNGDataForSystemSymbol(@"externaldrive", nil);
	}
	
	return self;
}

- (id) initWithPath:(NSString *)aPath {
	if ((self = [super init])) {
		if (aPath) {
			path = [aPath retain];
			name = [[[NSFileManager defaultManager] displayNameAtPath:path] retain];
		}
	}
	
	return self;
}

- (void) dealloc {
	[path release];
	path = nil;
	
	[name release];
	name = nil;
	
	[iconData release];
	iconData = nil;
	
	[super dealloc];
}

- (NSString *) description {
	NSMutableDictionary *desc = [NSMutableDictionary dictionary];
	
	if (name)
		[desc setObject:name forKey:@"name"];
	if (path)
		[desc setObject:path forKey:@"path"];
	if (iconData)
		[desc setObject:@"<yes>" forKey:@"iconData"];
	
	return [desc description];
}

@end

@interface HWGrowlVolumeMonitor ()

@property (nonatomic, assign) id<HWGrowlPluginControllerProtocol> delegate;
@property (nonatomic, retain) NSMutableDictionary *ejectCache;
@property (nonatomic, retain) NSString *ignoredVolumeColumnTitle;

@property (nonatomic, assign) IBOutlet NSArrayController *arrayController;
@property (nonatomic, assign) IBOutlet NSTableView *tableView;

- (BOOL)shouldOpenMountedVolumeInFinder:(VolumeInfo *)volume;
- (BOOL)boolResourceValueForURL:(NSURL *)url key:(NSURLResourceKey)key defaultValue:(BOOL)defaultValue;
- (void)modernizePreferencePane;

@end

@implementation HWGrowlVolumeMonitor

@synthesize delegate;
@synthesize ejectCache;

@synthesize prefsView;
@synthesize arrayController;
@synthesize tableView;

-(id)init {
	if((self = [super init])){
		self.ejectCache = [NSMutableDictionary dictionary];
		self.ignoredVolumeColumnTitle = NSLocalizedString(@"Ignored Drives:", @"Title for colum in table of ignored volumes");
	}
	return self;
}

- (void)dealloc {
	[self stopObserving];
	
	[ejectCache enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		[[obj objectAtIndex:VolumeEjectCacheTimerIndex] invalidate];
	}];		
	
	[ejectCache release];
	ejectCache = nil;
	
	    [_ignoredVolumeColumnTitle release];
		_ignoredVolumeColumnTitle = nil;
	
	[prefsView release];
	prefsView = nil;

	[super dealloc];
}

- (void)startObserving {
	NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
	[center removeObserver:self];
	
	[center addObserver:self selector:@selector(volumeDidMount:) name:NSWorkspaceDidMountNotification object:nil];
	//Note that we must use both WILL and DID unmount, so we can only get the volume's icon before the volume has finished unmounting.
	//The icon and data is stored during WILL unmount, and then displayed during DID unmount.
	[center addObserver:self selector:@selector(volumeDidUnmount:) name:NSWorkspaceDidUnmountNotification object:nil];
	[center addObserver:self selector:@selector(volumeWillUnmount:) name:NSWorkspaceWillUnmountNotification object:nil];
}

- (void)stopObserving {
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (void) sendMountNotificationForVolume:(VolumeInfo*)volume mounted:(BOOL)mounted {
	NSArray *exceptions = [[NSUserDefaults standardUserDefaults] objectForKey:@"HWGVolumeMonitorExceptions"];
	__block BOOL found = NO;
	[exceptions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		NSString *justAString = [obj valueForKey:@"justastring"];
		NSString *path = [volume path];
		NSString *name = [volume name];
		BOOL hasWildCard = [justAString hasSuffix:@"*"];
		if(!hasWildCard){
			if([path caseInsensitiveCompare:justAString] == NSOrderedSame ||
				[name caseInsensitiveCompare:justAString] == NSOrderedSame)
			{
				found = YES;
				*stop = YES;
			}
		}else{
			justAString = [justAString substringToIndex:[justAString length] - 1];
			if([path rangeOfString:justAString options:(NSAnchoredSearch | NSCaseInsensitivePredicateOption)].location != NSNotFound ||
				[name rangeOfString:justAString options:(NSAnchoredSearch | NSCaseInsensitivePredicateOption)].location != NSNotFound)
			{
				found = YES;
				*stop = YES;
			}
		}
	}];
	if(found)
		return;
	
	NSString *context = (mounted && [self shouldOpenMountedVolumeInFinder:volume]) ? [volume path] : nil;
	NSString *type = mounted ? @"VolumeMounted" : @"VolumeUnmounted";
	NSString *title = [NSString stringWithFormat:@"%@ %@", [volume name], mounted ? NSLocalizedString(@"Mounted", @"") : NSLocalizedString(@"Unmounted", @"")];
	[delegate notifyWithName:type
							 title:title
					 description:[context length] ? NSLocalizedString(@"Click to open", @"Message body on a volume mount notification, clicking it opens the drive in finder") : nil
							  icon:[volume iconData]
			  identifierString:[volume path]
				  contextString:context 
							plugin:self];
}

- (BOOL)shouldOpenMountedVolumeInFinder:(VolumeInfo *)volume
{
	NSString *path = [volume path];
	if (![path hasPrefix:@"/Volumes/"])
		return NO;
	
	NSURL *url = [NSURL fileURLWithPath:path isDirectory:YES];
	BOOL hidden = [self boolResourceValueForURL:url key:NSURLIsHiddenKey defaultValue:NO];
	BOOL browsable = [self boolResourceValueForURL:url key:NSURLVolumeIsBrowsableKey defaultValue:YES];
	BOOL local = [self boolResourceValueForURL:url key:NSURLVolumeIsLocalKey defaultValue:YES];
	BOOL internal = [self boolResourceValueForURL:url key:NSURLVolumeIsInternalKey defaultValue:NO];
	BOOL ejectable = [self boolResourceValueForURL:url key:NSURLVolumeIsEjectableKey defaultValue:NO];
	BOOL removable = [self boolResourceValueForURL:url key:NSURLVolumeIsRemovableKey defaultValue:NO];
	BOOL automounted = [self boolResourceValueForURL:url key:NSURLVolumeIsAutomountedKey defaultValue:NO];
	
	if (hidden || !browsable || !local || automounted)
		return NO;
	
	return ejectable || removable || !internal;
}

- (BOOL)boolResourceValueForURL:(NSURL *)url key:(NSURLResourceKey)key defaultValue:(BOOL)defaultValue
{
	NSNumber *value = nil;
	NSError *error = nil;
	if (![url getResourceValue:&value forKey:key error:&error] || !value)
		return defaultValue;
	return [value boolValue];
}

- (void) staleEjectItemTimerFired:(NSTimer *)theTimer {
	VolumeInfo *info = [theTimer userInfo];
	
	[ejectCache removeObjectForKey:[info path]];
}

- (void) volumeDidMount:(NSNotification *)aNotification {
	//send notification
	VolumeInfo *volume = [VolumeInfo volumeInfoForMountWithPath:[[aNotification userInfo] objectForKey:@"NSDevicePath"]];
	[self sendMountNotificationForVolume:volume mounted:YES];
}

- (void) volumeWillUnmount:(NSNotification *)aNotification {
	NSString *path = [[aNotification userInfo] objectForKey:@"NSDevicePath"];
	
	if (path) {
		VolumeInfo *info = [VolumeInfo volumeInfoForUnmountWithPath:path];
		NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:VolumeNotifierUnmountWaitSeconds
																		  target:self
																		selector:@selector(staleEjectItemTimerFired:)
																		userInfo:info
																		 repeats:NO];
		
		// need to invalidate the timer for a previous item if it exists
		NSArray *cacheItem = [ejectCache objectForKey:path];
		if (cacheItem)
			[[cacheItem objectAtIndex:VolumeEjectCacheTimerIndex] invalidate];
		
		[ejectCache setObject:[NSArray arrayWithObjects:info, timer, nil] forKey:path];
	}
}

- (void) volumeDidUnmount:(NSNotification *)aNotification {
	VolumeInfo *info = nil;
	NSString *path = [[aNotification userInfo] objectForKey:@"NSDevicePath"];
	NSArray *cacheItem = path ? [ejectCache objectForKey:path] : nil;
	
	if (cacheItem)
		info = [cacheItem objectAtIndex:VolumeEjectCacheInfoIndex];
	else
		info = [VolumeInfo volumeInfoForUnmountWithPath:path];
	
	//Send notification
	[self sendMountNotificationForVolume:info mounted:NO];
	
	if (cacheItem) {
		[[cacheItem objectAtIndex:VolumeEjectCacheTimerIndex] invalidate];
		// we need to remove the item from the cache AFTER calling volumeDidUnmount so that "info" stays
		// retained long enough to be useful. After this next call, "info" is no longer valid.
		[ejectCache removeObjectForKey:path];
		info = nil;
	}
}

#pragma mark UI

-(void)tableViewSelectionDidChange:(NSNotification *)notification {
   NSArray *arranged = [arrayController arrangedObjects];
   NSUInteger selection = [arrayController selectionIndex];
   if(selection < [arranged count] && [arranged count]){
      NSString *justastring = [[arranged objectAtIndex:selection] valueForKey:@"justastring"];
      if(!justastring || [justastring isEqualToString:@""])
         [self.tableView editColumn:0 row:selection withEvent:nil select:YES];
   }
}

- (void)modernizePreferencePane {
	NSScrollView *scrollView = [self.tableView enclosingScrollView];
	NSClipView *clipView = [scrollView contentView];
	
	if (![self.tableView headerView]) {
		NSTableHeaderView *headerView = [[[NSTableHeaderView alloc] initWithFrame:NSMakeRect(0.0, 0.0, NSWidth([self.tableView frame]), 22.0)] autorelease];
		[headerView setAutoresizingMask:NSViewWidthSizable];
		[self.tableView setHeaderView:headerView];
	}
	
	[self.tableView setRowHeight:24.0];
	[self.tableView setIntercellSpacing:NSMakeSize(3.0, 2.0)];
	[self.tableView setUsesAlternatingRowBackgroundColors:NO];
	[self.tableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleRegular];
	[self.tableView setBackgroundColor:[NSColor textBackgroundColor]];
	[self.tableView setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
	[self.tableView setGridColor:[NSColor separatorColor]];
	
	for (NSTableColumn *column in [self.tableView tableColumns]) {
		[[column headerCell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize] weight:NSFontWeightMedium]];
		[[column headerCell] setTextColor:[NSColor secondaryLabelColor]];
		NSCell *cell = [column dataCell];
		if ([cell respondsToSelector:@selector(setFont:)])
			[(id)cell setFont:[NSFont systemFontOfSize:13.0]];
		if ([cell respondsToSelector:@selector(setTextColor:)])
			[(id)cell setTextColor:[NSColor controlTextColor]];
		if ([cell respondsToSelector:@selector(setBackgroundColor:)])
			[(id)cell setBackgroundColor:[NSColor textBackgroundColor]];
	}
	
	[scrollView setBorderType:NSBezelBorder];
	[scrollView setDrawsBackground:YES];
	[scrollView setBackgroundColor:[NSColor textBackgroundColor]];
	[clipView setDrawsBackground:YES];
	[clipView setBackgroundColor:[NSColor textBackgroundColor]];
	
	for (NSView *subview in [prefsView subviews]) {
		if ([subview isKindOfClass:[NSButton class]]) {
			NSButton *button = (NSButton *)subview;
			[button setBezelStyle:NSBezelStyleTexturedRounded];
			[button setBordered:YES];
			[[button cell] setImagePosition:NSImageOnly];
		}
	}
}

-(IBAction)addVolumeEntry:(id)sender {
   NSMutableDictionary *dict = [NSMutableDictionary dictionary];
   [self.arrayController addObject:dict];
   [self.arrayController setSelectedObjects:[NSArray arrayWithObject:dict]];
}
#pragma mark HWGrowlPluginProtocol

-(void)setDelegate:(id<HWGrowlPluginControllerProtocol>)aDelegate{
	delegate = aDelegate;
}
-(id<HWGrowlPluginControllerProtocol>)delegate {
	return delegate;
}
-(NSString*)pluginDisplayName{
	return NSLocalizedString(@"Volume Monitor", @"");
}
-(NSImage*)preferenceIcon {
	static NSImage *_icon = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_icon = [[NSImage imageNamed:@"HWGPrefsDrivesVolumes"] retain];
	});
	return _icon;
}
-(NSView*)preferencePane {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[NSBundle loadNibNamed:@"VolumeMonitorPrefs" owner:self];
		[self modernizePreferencePane];
	});
	return prefsView;
}

#pragma mark HWGrowlPluginNotifierProtocol

-(NSArray*)noteNames {
	return [NSArray arrayWithObjects:@"VolumeMounted", @"VolumeUnmounted", nil];
}
-(NSDictionary*)localizedNames {
	return [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Volume Mounted", @""), @"VolumeMounted",
			  NSLocalizedString(@"Volume Unmounted", @""), @"VolumeUnmounted", nil];
}
-(NSDictionary*)noteDescriptions {
	return [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Sent when a volume is mounted", @""), @"VolumeMounted",
			  NSLocalizedString(@"Sent when a volume is unmounted", @""), @"VolumeUnmounted", nil];
}
-(NSArray*)defaultNotifications {
	return [NSArray arrayWithObjects:@"VolumeMounted", @"VolumeUnmounted", nil];
}

-(void)fireOnLaunchNotes{
	NSArray *paths = [[NSWorkspace sharedWorkspace] mountedLocalVolumePaths];
	__block HWGrowlVolumeMonitor *blockSelf = self;
	[paths enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		[blockSelf sendMountNotificationForVolume:[VolumeInfo volumeInfoForMountWithPath:obj] mounted:YES];
	}];
}
-(void)noteClosed:(NSString*)contextString byClick:(BOOL)clicked {
	if(clicked && [contextString length]) {
		if (![contextString hasPrefix:@"/Volumes/"])
			return;
		NSURL *volumeURL = [NSURL fileURLWithPath:contextString isDirectory:YES];
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSWorkspace sharedWorkspace] openURL:volumeURL];
		});
	}
}

@end
