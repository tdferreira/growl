//
//  HWGrowlTimeMachineMonitor.m
//  HardwareGrowler
//
//  Created by Daniel Siemer on 5/19/12.
//  Copyright (c) 2012 The Growl Project, LLC. All rights reserved.
//

#import "HWGrowlTimeMachineMonitor.h"
#import <OSLog/OSLog.h>

@interface HWGrowlTimeMachineMonitor () {
	dispatch_queue_t tmQueue;
}

@property (nonatomic, assign) id<HWGrowlPluginControllerProtocol> delegate;

@property (nonatomic, retain) NSTimer *pollTimer;
@property (nonatomic, retain) NSDate *lastSearchTime, *lastStartTime, *lastEndTime;
@property (nonatomic, assign) BOOL postGrowlNotifications;
@property (nonatomic, assign) BOOL parsing;

@end

@implementation HWGrowlTimeMachineMonitor

@synthesize delegate;

@synthesize pollTimer;
@synthesize lastStartTime;
@synthesize lastSearchTime;
@synthesize lastEndTime;
@synthesize postGrowlNotifications;
@synthesize parsing;

-(id)init {
	if((self = [super init])){
		parsing = NO;
		
		tmQueue = dispatch_queue_create("com.growl.hardwaregrowler.tmmonitorqueue", DISPATCH_QUEUE_SERIAL);
	}
	return self;
}

-(void)dealloc {
	if (tmQueue)
		dispatch_release(tmQueue);
	[pollTimer invalidate];
	[pollTimer release];
    pollTimer = nil;
    
	[lastStartTime release];
    lastStartTime = nil;
	[lastSearchTime release];
    lastSearchTime = nil;
	[lastEndTime release];
    lastEndTime = nil;
	[super dealloc];
}

-(void)postRegistrationInit {
	[self startMonitoringTheLogs];
}

-(NSData*)timeMachineIcon {
	static NSData *data = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSURL *appURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.apple.backup.launcher"];
		NSImage *appIcon = appURL ? [[NSWorkspace sharedWorkspace] iconForFile:[appURL path]] : nil;
		NSData *tiffData = [appIcon TIFFRepresentation];
		NSBitmapImageRep *imageRep = tiffData ? [NSBitmapImageRep imageRepWithData:tiffData] : nil;
		data = [[imageRep representationUsingType:NSBitmapImageFileTypePNG
									   properties:[NSDictionary dictionary]] retain];
	});
	return data;
}

- (void) startMonitoringTheLogs {
	if(self.pollTimer)
		return;
	
	if([delegate pluginDisabled:self])
		return;
	
	self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
																	  target:self
																	selector:@selector(pollLogDatabase:)
																	userInfo:nil
																	 repeats:YES];
   [[NSRunLoop mainRunLoop] addTimer:pollTimer forMode:NSRunLoopCommonModes];
   [self pollLogDatabase:pollTimer];
}
- (void) stopMonitoringTheLogs {
	if(!pollTimer)
		return;
	
	[pollTimer invalidate];
	self.pollTimer = nil;
}

- (NSString *) stringWithTimeInterval:(NSTimeInterval)units {
	NSString *unitNames[] = {
		NSLocalizedString(@"seconds", /*comment*/ @"Unit names"),
		NSLocalizedString(@"minutes", /*comment*/ @"Unit names"),
		NSLocalizedString(@"hours", /*comment*/ @"Unit names")
	};
	NSUInteger unitNameIndex = 0UL;
	if (units >= 60.0) {
		units /= 60.0;
		++unitNameIndex;
	}
	if (units >= 60.0) {
		units /= 60.0;
		++unitNameIndex;
	}
	return [NSString localizedStringWithFormat:@"%.03f %@", units, unitNames[unitNameIndex]];
}

- (void) postBackupStartedNotification {
   __block HWGrowlTimeMachineMonitor *blockSelf = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		NSString *description = nil;
		NSString *timeString = [blockSelf stringWithTimeInterval:[blockSelf->lastStartTime timeIntervalSinceDate:blockSelf->lastEndTime]];
		if(blockSelf->lastEndTime)
			description = [NSString stringWithFormat:NSLocalizedString(@"%@ since last back-up", @""), timeString];
		else
			description = NSLocalizedString(@"First backup, or no previous backup found in the system log", @"");
        
        NSData *iconData = HWGPNGDataForSystemSymbol(@"clock.arrow.circlepath", @"TimeMachine-On");
		[blockSelf->delegate notifyWithName:@"TimeMachineStart"
												title:NSLocalizedString(@"Time Machine started", @"") 
										description:description
												 icon:iconData
								 identifierString:@"HWGTimeMachineMonitor"
									 contextString:nil
											  plugin:blockSelf];
	});
}

- (void) pollLogDatabase:(NSTimer *)timer {
	//We really shouldn't pile parse upon parse
	if(!parsing){
      __block HWGrowlTimeMachineMonitor *blockSelf = self;
		dispatch_async(tmQueue, ^{
			[blockSelf parseLogDatabase];
		});
	}else {
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			NSLog(@"WARNING: The Time Machine Montior relies on parsing the console log, and it is taking too long to parse due to high volume of messages, you may see high CPU usage as a result");
		});
	}
}

- (void) parseLogDatabase {
	__block HWGrowlTimeMachineMonitor *blockSelf = self;
	
	NSError *storeError = nil;
	OSLogStore *store = [OSLogStore storeWithScope:OSLogStoreSystem error:&storeError];
	if (!store) {
		NSLog(@"Unable to open system log store for Time Machine monitor: %@", storeError);
		postGrowlNotifications = YES;
		dispatch_async(dispatch_get_main_queue(), ^{
			[blockSelf setParsing:NO];
		});
		return;
	}
	
	NSDate *searchDate = lastSearchTime ? lastSearchTime : [NSDate dateWithTimeIntervalSinceNow:-3600.0];
	OSLogPosition *position = [store positionWithDate:searchDate];
	NSError *enumeratorError = nil;
	OSLogEnumerator *enumerator = [store entriesEnumeratorWithOptions:0
															 position:position
															predicate:nil
																error:&enumeratorError];
	if (!enumerator) {
		NSLog(@"Unable to enumerate system log for Time Machine monitor: %@", enumeratorError);
		postGrowlNotifications = YES;
		dispatch_async(dispatch_get_main_queue(), ^{
			[blockSelf setParsing:NO];
		});
		return;
	}
	
	BOOL lastWasCanceled = NO;
	
	NSUInteger numFoundMessages = 0UL;
	NSDate *lastFoundMessageDate = nil;
	NSDate *pollEndDate = [NSDate date];
	OSLogEntry *entry = nil;
	while ((entry = [enumerator nextObject])) {
		NSDate *messageDate = [entry date];
		if (lastSearchTime && [messageDate compare:lastSearchTime] != NSOrderedDescending)
			continue;
		
		NSString *message = [entry composedMessage];
		NSString *eventName = [self timeMachineEventNameForLogMessage:message];
		if (!eventName)
			continue;
		
		++numFoundMessages;
		lastFoundMessageDate = messageDate;
		
		if ([eventName isEqualToString:@"start"]) {
				self.lastStartTime = lastFoundMessageDate;
				lastWasCanceled = NO;
				
				if (postGrowlNotifications) {
					[self postBackupStartedNotification];
				}
				
		} else if ([eventName isEqualToString:@"finish"]) {
				self.lastEndTime = lastFoundMessageDate;
				lastWasCanceled = NO;
				
				if (postGrowlNotifications) {
					dispatch_async(dispatch_get_main_queue(), ^{
						NSString *timeString = [blockSelf stringWithTimeInterval:[blockSelf->lastEndTime timeIntervalSinceDate:blockSelf->lastStartTime]];
                        NSData *iconData = HWGPNGDataForSystemSymbol(@"clock.badge.checkmark", @"TimeMachine-Off");
                        [blockSelf->delegate notifyWithName:@"TimeMachineFinish"
																title:NSLocalizedString(@"Time Machine finished", @"")
														description:[NSString stringWithFormat:NSLocalizedString(@"Back-up took %@", @""), timeString]
																 icon:iconData
												 identifierString:@"HWGTimeMachineMonitor"
													 contextString:nil
															  plugin:blockSelf];
					});
				}
				
		} else if ([eventName isEqualToString:@"canceled"] || [eventName isEqualToString:@"failed"]) {
				NSDate *date = lastFoundMessageDate;
				lastWasCanceled = YES;
				BOOL wasFailure = [eventName isEqualToString:@"failed"];
				
				if (postGrowlNotifications) {
					dispatch_async(dispatch_get_main_queue(), ^{
						NSString *description = nil;
						NSString *timeString = [blockSelf stringWithTimeInterval:[date timeIntervalSinceDate:blockSelf->lastStartTime]];
						if(wasFailure)
							description = [NSString stringWithFormat:NSLocalizedString(@"Failed after %@", @""), timeString];
						else
							description = [NSString stringWithFormat:NSLocalizedString(@"Canceled after %@", @""), timeString];
                        NSData *iconData = HWGPNGDataForSystemSymbol(wasFailure ? @"clock.badge.exclamationmark" : @"clock.badge.xmark", @"TimeMachine-Failed");

						[blockSelf->delegate notifyWithName:wasFailure ? @"TimeMachineFailed" : @"TimeMachineCanceled"
																title:wasFailure ? NSLocalizedString(@"Time Machine Failed", @"") : NSLocalizedString(@"Time Machine Canceled", @"")
														description:description
																 icon:iconData
												 identifierString:@"HWGTimeMachineMonitor"
													 contextString:nil
															  plugin:blockSelf];
					});
				}
		}
	}
	
	//If a Time Machine back-up is running now, post the notification even if we are on our first run.
	if (numFoundMessages > 0 &&
		 !postGrowlNotifications &&
		 !lastWasCanceled && 
		 (!lastEndTime || [lastStartTime compare:lastEndTime] == NSOrderedDescending)) 
	{
		[self postBackupStartedNotification];
	}
	
	if (numFoundMessages > 0) {
		self.lastSearchTime = lastFoundMessageDate;
	} else {
		self.lastSearchTime = pollEndDate;
	}
	postGrowlNotifications = YES;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[blockSelf setParsing:NO]; 
	});
}

- (NSString *)timeMachineEventNameForLogMessage:(NSString *)message
{
	if (![message length])
		return nil;
	
	if ([message rangeOfString:@"Starting standard backup"].location != NSNotFound)
		return @"start";
	if ([message rangeOfString:@"Backup completed successfully"].location != NSNotFound)
		return @"finish";
	if ([message rangeOfString:@"Backup canceled"].location != NSNotFound)
		return @"canceled";
	if ([message rangeOfString:@"Backup failed"].location != NSNotFound)
		return @"failed";
	
	return nil;
}

#pragma mark HWGrowlPluginProtocol

-(void)setDelegate:(id<HWGrowlPluginControllerProtocol>)aDelegate{
	delegate = aDelegate;
}
-(id<HWGrowlPluginControllerProtocol>)delegate {
	return delegate;
}
-(NSString*)pluginDisplayName {
	return NSLocalizedString(@"TimeMachine Monitor", @"");
}
-(NSImage*)preferenceIcon {
	static NSImage *_icon = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_icon = [[NSImage imageNamed:@"HWGPrefsTimeMachine"] retain];
	});
	return _icon;
}
-(NSView*)preferencePane {
	return nil;
}
-(void)startObserving {
	[self startMonitoringTheLogs];
}
-(void)stopObserving {
	[self stopMonitoringTheLogs];
}
-(BOOL)enabledByDefault {
	return NO;
}

#pragma mark HWGrowlPluginNotifierProtocol

-(NSArray*)noteNames {
	return [NSArray arrayWithObjects:@"TimeMachineStart", @"TimeMachineFinish", @"TimeMachineCanceled", @"TimeMachineFailed", nil];
}
-(NSDictionary*)localizedNames {
	return [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Time Machine Started", @""), @"TimeMachineStart",
			  NSLocalizedString(@"Time Machine Finished", @""), @"TimeMachineFinish",
			  NSLocalizedString(@"Time Machine Canceled", @""), @"TimeMachineCanceled",
			  NSLocalizedString(@"Time Machine Failed", @""), @"TimeMachineFailed", nil];
}
-(NSDictionary*)noteDescriptions {
	return [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Sent when Time Machine starts backing up", @""), @"TimeMachineStart",
			  NSLocalizedString(@"Sent when Time Machine finishes backing up", @""), @"TimeMachineFinish",
			  NSLocalizedString(@"Sent when Time Machine is canceled", @""), @"TimeMachineCanceled",
			  NSLocalizedString(@"Sent when Time Machine failed to back up", @""), @"TimeMachineFailed", nil];
}
-(NSArray*)defaultNotifications {
	return [NSArray arrayWithObjects:@"TimeMachineStart", @"TimeMachineFinish", @"TimeMachineCanceled", @"TimeMachineFailed", nil];
}

@end
