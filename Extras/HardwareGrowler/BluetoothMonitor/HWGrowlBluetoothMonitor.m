//
//  HWGrowlBluetoothMonitor.m
//  HardwareGrowler
//
//  Created by Daniel Siemer on 5/5/12.
//  Copyright (c) 2012 The Growl Project, LLC. All rights reserved.
//

#import "HWGrowlBluetoothMonitor.h"
#import "HWBluetoothMonitorUtilities.h"
#import "../HardwareGrowler/HWSystemSettingsRoutes.h"
#import <stdlib.h>
#import <IOBluetooth/IOBluetooth.h>
#import <os/log.h>

static NSString * const HWGBluetoothSymbolName = @"antenna.radiowaves.left.and.right";

@interface HWGrowlBluetoothMonitor ()

@property (nonatomic, assign) id<HWGrowlPluginControllerProtocol> delegate;
@property (nonatomic, assign) BOOL starting;
@property (nonatomic, assign) BOOL observingPowerNotifications;

@property (nonatomic, assign) IOBluetoothUserNotification *connectionNotification;
@property (nonatomic, retain) NSMutableSet *pendingNameRequestIdentifiers;

- (NSString *)displayNameForBluetoothDevice:(IOBluetoothDevice *)device;
- (NSString *)knownNameForBluetoothDevice:(IOBluetoothDevice *)device;
- (NSString *)knownNameForBluetoothDevice:(IOBluetoothDevice *)device inDevices:(NSArray *)devices;
- (NSString *)notificationDescriptionForBluetoothDevice:(IOBluetoothDevice *)device connected:(BOOL)connected;
- (NSString *)notificationIdentifierForBluetoothDevice:(IOBluetoothDevice *)device;
- (BOOL)hasDisplayableNameForBluetoothDevice:(IOBluetoothDevice *)device;
- (void)postBluetoothConnectionForDevice:(IOBluetoothDevice *)device;
- (void)bluetoothPowerStateChanged:(NSNotification *)notification;
- (void)notifyBluetoothPoweredOn:(BOOL)poweredOn;
- (BOOL)bluetoothNameDiagnosticsEnabled;
- (NSString *)bluetoothNameDiagnosticsLogFilePath;
- (void)appendBluetoothNameDiagnosticsLine:(NSString *)line;
- (void)logBluetoothNameDiagnosticsForDevice:(IOBluetoothDevice *)device eventName:(NSString *)eventName;

@end

@implementation HWGrowlBluetoothMonitor

@synthesize delegate;
@synthesize starting;
@synthesize observingPowerNotifications;
@synthesize connectionNotification;
@synthesize pendingNameRequestIdentifiers;

-(void)dealloc {
	[self stopObserving];
	[pendingNameRequestIdentifiers release];
	[super dealloc];
}

-(id)init {
	if((self = [super init])){
		self.pendingNameRequestIdentifiers = [NSMutableSet set];
	}
	return self;
}

-(void)postRegistrationInit {
	[self startObserving];
}

-(void)startObserving {
	[self appendBluetoothNameDiagnosticsLine:[NSString stringWithFormat:@"Bluetooth monitor startObserving; diagnosticsEnabled=%@; logFile=%@",
											  [self bluetoothNameDiagnosticsEnabled] ? @"YES" : @"NO",
											  [self bluetoothNameDiagnosticsLogFilePath]]];
	
	if (!self.connectionNotification) {
		self.starting = YES;
		self.connectionNotification = [IOBluetoothDevice registerForConnectNotifications:self
																			   selector:@selector(bluetoothConnection:device:)];
		self.starting = NO;
	}
	
	if (!self.observingPowerNotifications) {
		NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
		[notificationCenter addObserver:self
							   selector:@selector(bluetoothPowerStateChanged:)
								   name:IOBluetoothHostControllerPoweredOnNotification
								 object:nil];
		[notificationCenter addObserver:self
							   selector:@selector(bluetoothPowerStateChanged:)
								   name:IOBluetoothHostControllerPoweredOffNotification
								 object:nil];
		self.observingPowerNotifications = YES;
	}
}

-(void)stopObserving {
	[connectionNotification unregister];
	connectionNotification = nil;
	if (self.observingPowerNotifications) {
		NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
		[notificationCenter removeObserver:self
									  name:IOBluetoothHostControllerPoweredOnNotification
									object:nil];
		[notificationCenter removeObserver:self
									  name:IOBluetoothHostControllerPoweredOffNotification
									object:nil];
		self.observingPowerNotifications = NO;
	}
	self.starting = NO;
}

-(void)bluetoothDevice:(IOBluetoothDevice*)device connected:(BOOL)connected {
	NSString *title = connected ? NSLocalizedString(@"Bluetooth Connection", @"") : NSLocalizedString(@"Bluetooth Disconnection", @"");
	NSString *description = [self notificationDescriptionForBluetoothDevice:device connected:connected];
	NSData *iconData = HWGPNGDataForSystemSymbol(HWGBluetoothSymbolName, nil);
	
	[self logBluetoothNameDiagnosticsForDevice:device eventName:connected ? @"notification-send-connected" : @"notification-send-disconnected"];
	
	[delegate notifyWithName:connected ? @"BluetoothConnected" : @"BluetoothDisconnected"
					   title:title
				 description:description
						icon:iconData
			identifierString:[self notificationIdentifierForBluetoothDevice:device]
				contextString:HWGBluetoothSettingsURLString
					  plugin:self];
}

-(void)bluetoothPowerStateChanged:(NSNotification *)notification {
	if ([[notification name] isEqualToString:IOBluetoothHostControllerPoweredOnNotification]) {
		[self notifyBluetoothPoweredOn:YES];
	} else if ([[notification name] isEqualToString:IOBluetoothHostControllerPoweredOffNotification]) {
		[self notifyBluetoothPoweredOn:NO];
	}
}

-(void)notifyBluetoothPoweredOn:(BOOL)poweredOn {
	NSString *title = poweredOn ? NSLocalizedString(@"Bluetooth On", @"Bluetooth radio power state notification") : NSLocalizedString(@"Bluetooth Off", @"Bluetooth radio power state notification");
	NSString *description = poweredOn ? NSLocalizedString(@"Bluetooth is available.", @"Bluetooth radio powered on notification body") : NSLocalizedString(@"Bluetooth is off.", @"Bluetooth radio powered off notification body");
	
	[delegate notifyWithName:poweredOn ? @"BluetoothPoweredOn" : @"BluetoothPoweredOff"
					   title:title
				 description:description
						icon:HWGPNGDataForSystemSymbol(HWGBluetoothSymbolName, nil)
			identifierString:poweredOn ? @"HardwareGrowler-BluetoothPoweredOn" : @"HardwareGrowler-BluetoothPoweredOff"
				contextString:HWGBluetoothSettingsURLString
					  plugin:self];
}

-(NSString *)displayNameForBluetoothDevice:(IOBluetoothDevice *)device {
	NSString *name = [device name];
	if (![name length])
		name = [self knownNameForBluetoothDevice:device];
	if (![name length])
		name = [device nameOrAddress];
	if (![name length])
		name = [device addressString];
	return [name length] ? name : HWGBluetoothUnknownDeviceDisplayName();
}

-(NSString *)knownNameForBluetoothDevice:(IOBluetoothDevice *)device {
	NSString *name = [self knownNameForBluetoothDevice:device inDevices:[IOBluetoothDevice pairedDevices]];
	if (![name length])
		name = [self knownNameForBluetoothDevice:device inDevices:[IOBluetoothDevice favoriteDevices]];
	if (![name length])
		name = [self knownNameForBluetoothDevice:device inDevices:[IOBluetoothDevice recentDevices:0]];
	return name;
}

-(NSString *)knownNameForBluetoothDevice:(IOBluetoothDevice *)device inDevices:(NSArray *)devices {
	NSString *address = [device addressString];
	if (![address length])
		return nil;
	
	for (IOBluetoothDevice *knownDevice in devices) {
		if (HWGBluetoothAddressStringsMatch([knownDevice addressString], address) && [[knownDevice name] length])
			return [knownDevice name];
	}
	return nil;
}

-(NSString *)notificationDescriptionForBluetoothDevice:(IOBluetoothDevice *)device connected:(BOOL)connected {
	NSString *displayName = [self displayNameForBluetoothDevice:device];
	NSString *address = [device addressString];
	NSString *action = connected ? NSLocalizedString(@"Connected", @"Bluetooth device connected status") : NSLocalizedString(@"Disconnected", @"Bluetooth device disconnected status");
	
	if ([address length] && ![displayName isEqualToString:address]) {
		return [NSString stringWithFormat:NSLocalizedString(@"%@: %@\nAddress: %@", @"Bluetooth device notification body"), action, displayName, address];
	}
	
	return [NSString stringWithFormat:NSLocalizedString(@"%@: %@", @"Bluetooth device notification body without address"), action, displayName];
}

-(NSString *)notificationIdentifierForBluetoothDevice:(IOBluetoothDevice *)device {
	NSString *identifier = [device addressString];
	if (![identifier length])
		identifier = [self displayNameForBluetoothDevice:device];
	return identifier;
}

-(BOOL)hasDisplayableNameForBluetoothDevice:(IOBluetoothDevice *)device {
	return HWGBluetoothDisplayNameIsKnown([self displayNameForBluetoothDevice:device]);
}

-(BOOL)bluetoothNameDiagnosticsEnabled {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"HWGBluetoothNameDiagnostics"])
		return YES;
	
	/* HardwareGrowler has used both bundle-id spellings over time. Check both
	   while diagnostics are temporary so local investigation is not blocked by
	   a preference-domain mismatch. */
	NSArray *applicationIDs = [NSArray arrayWithObjects:@"com.growl.hardwaregrowler", @"com.growl.HardwareGrowler", nil];
	for (NSString *applicationID in applicationIDs) {
		CFPropertyListRef value = CFPreferencesCopyAppValue(CFSTR("HWGBluetoothNameDiagnostics"), (CFStringRef)applicationID);
		if (value) {
			BOOL enabled = CFGetTypeID(value) == CFBooleanGetTypeID() && CFBooleanGetValue((CFBooleanRef)value);
			CFRelease(value);
			if (enabled)
				return YES;
		}
	}
	
	return NO;
}

-(NSString *)bluetoothNameDiagnosticsLogFilePath {
	NSString *logsDirectoryPath = [[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:@"Logs"] stringByAppendingPathComponent:@"HardwareGrowler"];
	return [logsDirectoryPath stringByAppendingPathComponent:@"BluetoothNameDiagnostics.log"];
}

-(void)appendBluetoothNameDiagnosticsLine:(NSString *)line {
	if (![line length])
		return;
	
	NSString *logFilePath = [self bluetoothNameDiagnosticsLogFilePath];
	NSString *directoryPath = [logFilePath stringByDeletingLastPathComponent];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSError *error = nil;
	
	if (![fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:&error]) {
		NSLog(@"Unable to create Bluetooth diagnostics log directory %@: %@", directoryPath, error);
		return;
	}
	
	if (![fileManager fileExistsAtPath:logFilePath] && ![fileManager createFileAtPath:logFilePath contents:nil attributes:nil]) {
		NSLog(@"Unable to create Bluetooth diagnostics log file %@", logFilePath);
		return;
	}
	
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
	if (!fileHandle) {
		NSLog(@"Unable to open Bluetooth diagnostics log file %@", logFilePath);
		return;
	}
	
	NSString *timestampedLine = [NSString stringWithFormat:@"%@ %@\n", [[NSDate date] descriptionWithLocale:nil], line];
	NSData *lineData = [timestampedLine dataUsingEncoding:NSUTF8StringEncoding];
	[fileHandle seekToEndOfFile];
	[fileHandle writeData:lineData];
	[fileHandle closeFile];
}

-(void)logBluetoothNameDiagnosticsForDevice:(IOBluetoothDevice *)device eventName:(NSString *)eventName {
	NSString *name = [device name];
	NSString *knownName = [self knownNameForBluetoothDevice:device];
	NSString *nameOrAddress = [device nameOrAddress];
	NSString *address = [device addressString];
	NSString *displayName = [self displayNameForBluetoothDevice:device];
	BOOL diagnosticsEnabled = [self bluetoothNameDiagnosticsEnabled];
	NSString *diagnostics = HWGBluetoothNameDiagnosticsDescription(eventName, name, knownName, nameOrAddress, address, displayName);
	[self appendBluetoothNameDiagnosticsLine:[NSString stringWithFormat:@"diagnosticsEnabled=%@ %@", diagnosticsEnabled ? @"YES" : @"NO", diagnostics]];
	if (diagnosticsEnabled) {
		os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "%{public}@", diagnostics);
		NSLog(@"%@", diagnostics);
	}
}

-(void)postBluetoothConnectionForDevice:(IOBluetoothDevice *)device {
	[self bluetoothDevice:device connected:YES];
}

-(void)bluetoothDisconnection:(IOBluetoothUserNotification*)note 
							  device:(IOBluetoothDevice*)device
{
	[self logBluetoothNameDiagnosticsForDevice:device eventName:@"live-disconnect"];
	[self bluetoothDevice:device connected:NO];
	[note unregister];
		
}

-(void)bluetoothConnection:(IOBluetoothUserNotification*)note 
						  device:(IOBluetoothDevice*)device 
{
	[self logBluetoothNameDiagnosticsForDevice:device eventName:starting ? @"startup-connect" : @"live-connect"];
	if (!starting || [delegate onLaunchEnabled]) {
		if ([self hasDisplayableNameForBluetoothDevice:device]) {
			[self bluetoothDevice:device connected:YES];
		} else {
			NSString *identifier = [self notificationIdentifierForBluetoothDevice:device];
			if ([identifier length])
				[pendingNameRequestIdentifiers addObject:identifier];
			[device remoteNameRequest:self];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				if ([self hasDisplayableNameForBluetoothDevice:device])
					[self postBluetoothConnectionForDevice:device];
				else
					NSLog(@"Bluetooth device connected, but macOS did not expose a name or address for it.");
			});
		}
	}
		
	[device registerForDisconnectNotification:self selector:@selector(bluetoothDisconnection:device:)];
}

-(void)remoteNameRequestComplete:(IOBluetoothDevice *)device status:(IOReturn)status
{
	[self logBluetoothNameDiagnosticsForDevice:device eventName:@"remote-name-complete"];
	NSString *identifier = [self notificationIdentifierForBluetoothDevice:device];
	if ([identifier length])
		[pendingNameRequestIdentifiers removeObject:identifier];
	
	if (status == kIOReturnSuccess && [device isConnected] && [self hasDisplayableNameForBluetoothDevice:device])
		[self bluetoothDevice:device connected:YES];
}

#pragma mark HWGrowlPluginProtocol

-(void)setDelegate:(id<HWGrowlPluginControllerProtocol>)aDelegate {
	delegate = aDelegate;
}
-(id<HWGrowlPluginControllerProtocol>)delegate {
	return delegate;
}
-(NSString*)pluginDisplayName {
	return NSLocalizedString(@"Bluetooth Monitor", @"");
}
-(NSImage*)preferenceIcon {
	static NSImage *_icon = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_icon = [HWGSystemSymbolImage(HWGBluetoothSymbolName, nil) retain];
	});
	return _icon;
}
-(NSView*)preferencePane {
	return nil;
}

#pragma mark HWGrowlPluginNotifierProtocol

-(NSArray*)noteNames {
	return [NSArray arrayWithObjects:@"BluetoothConnected", @"BluetoothDisconnected", @"BluetoothPoweredOn", @"BluetoothPoweredOff", nil];
}
-(NSDictionary*)localizedNames {
	return [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Bluetooth Connected", @""), @"BluetoothConnected",
			  NSLocalizedString(@"Bluetooth Disconnected", @""), @"BluetoothDisconnected",
			  NSLocalizedString(@"Bluetooth On", @"Bluetooth radio power state notification"), @"BluetoothPoweredOn",
			  NSLocalizedString(@"Bluetooth Off", @"Bluetooth radio power state notification"), @"BluetoothPoweredOff", nil];
}
-(NSDictionary*)noteDescriptions {
	return [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Sent when a Bluetooth Device is connected", @""), @"BluetoothConnected",
			  NSLocalizedString(@"Sent when a Bluetooth Device is disconnected", @""), @"BluetoothDisconnected",
			  NSLocalizedString(@"Sent when Bluetooth is turned on", @"Bluetooth radio powered on notification description"), @"BluetoothPoweredOn",
			  NSLocalizedString(@"Sent when Bluetooth is turned off", @"Bluetooth radio powered off notification description"), @"BluetoothPoweredOff", nil];
}
-(NSArray*)defaultNotifications {
	return [NSArray arrayWithObjects:@"BluetoothConnected", @"BluetoothDisconnected", @"BluetoothPoweredOn", @"BluetoothPoweredOff", nil];
}

-(void)noteClosed:(NSString*)contextString byClick:(BOOL)clicked {
	if(clicked && [contextString length]) {
		NSURL *settingsURL = [NSURL URLWithString:contextString];
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSWorkspace sharedWorkspace] openURL:settingsURL];
		});
	}
}

@end
