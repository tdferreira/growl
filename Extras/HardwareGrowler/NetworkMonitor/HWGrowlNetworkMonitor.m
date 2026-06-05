//
//  HWGrowlNetworkMonitor.m
//  HardwareGrowler
//
//  Created by Daniel Siemer on 5/2/12.
//  Copyright (c) 2012 The Growl Project, LLC. All rights reserved.
//

#import "HWGrowlNetworkMonitor.h"
#import "HWNetworkMonitorUtilities.h"
#import "GrowlNetworkUtilities.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreWLAN/CoreWLAN.h>
#import <SystemConfiguration/SystemConfiguration.h>

#include <sys/socket.h>
#include <sys/sockio.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <net/if_media.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

/* @"Link Status" == 1 seems to mean disconnected */
#define AIRPORT_DISCONNECTED 1

static struct ifmedia_description ifm_subtype_ethernet_descriptions[] = IFM_SUBTYPE_ETHERNET_DESCRIPTIONS;
static struct ifmedia_description ifm_shared_option_descriptions[] = IFM_SHARED_OPTION_DESCRIPTIONS;

typedef enum {
	HWGAirPortInterface,
	HWGEthernetInterface,
} NetworkInterfaceType;

@interface HWGrowlNetworkInterfaceStatus : NSObject;

@property (nonatomic, retain) NSString *interface;
@property (nonatomic, retain) NSDictionary *status;
@property (nonatomic, assign) NetworkInterfaceType type;

-(id)initForInterface:(NSString*)anInterface ofType:(NetworkInterfaceType)aType withStatus:(NSDictionary*)theStatus;

@end

@implementation HWGrowlNetworkInterfaceStatus

@synthesize interface;
@synthesize status;
@synthesize type;

-(id)initForInterface:(NSString *)anInterface 
					ofType:(NetworkInterfaceType)aType 
			  withStatus:(NSDictionary *)theStatus 
{
	if((self = [super init])){
		self.interface = anInterface;
		self.type = aType;
		self.status = theStatus;
	}
	return self;
}

- (void)dealloc
{
    [interface release];
    interface = nil;
    
    [status release];
    status = nil;
    
    [super dealloc];
}

@end

@interface HWGrowlNetworkMonitor () <CLLocationManagerDelegate, CWEventDelegate>

@property (nonatomic, assign) id<HWGrowlPluginControllerProtocol> delegate;

@property (nonatomic, assign) SCDynamicStoreRef dynStore;
@property (nonatomic, assign) CFRunLoopSourceRef rlSrc;

@property (nonatomic, retain) NSMutableDictionary *networkInterfaceStates;
@property (nonatomic, retain) NSString *previousIPCombined;
@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, retain) CWWiFiClient *wifiClient;
@property (nonatomic, retain) NSString *previousWiFiSignature;
@property (nonatomic, retain) NSMutableDictionary *vpnInterfaceActiveStates;
@property (nonatomic, retain) NSMutableDictionary *vpnServiceInterfaces;
@property (nonatomic, retain) NSMutableDictionary *vpnServiceProtocolActiveStates;

- (NSString *)networkNameFromAirPortStatus:(NSDictionary *)status interface:(NSString *)interfaceName;
- (NSString *)stringFromSSIDValue:(id)ssidValue;
- (NSString *)stringFromBSSIDValue:(id)bssidValue;
- (NSString *)currentWiFiSSIDForInterface:(NSString *)interfaceName;
- (NSString *)currentWiFiBSSIDForInterface:(NSString *)interfaceName;
- (CWInterface *)wiFiInterfaceForName:(NSString *)interfaceName;
- (NSString *)ssidForWiFiInterface:(CWInterface *)wifiInterface;
- (void)startMonitoringWiFiEvents;
- (void)stopMonitoringWiFiEvents;
- (void)startMonitoringWiFiEvent:(CWEventType)eventType;
- (void)notifyAirportConnectedForInterface:(NSString *)interfaceName status:(NSDictionary *)status bssid:(id)bssidValue retryCount:(NSUInteger)retryCount;
- (void)notifyCurrentWiFiNetworkForInterface:(NSString *)interfaceName retryCount:(NSUInteger)retryCount;
- (void)logUnavailableWiFiSSIDForInterface:(NSString *)interfaceName status:(NSDictionary *)status;
- (void)notifyCurrentWiFiNetworkAfterLocationAuthorization;
- (BOOL)locationAuthorizationAllowsWiFiInfo:(CLAuthorizationStatus)authorizationStatus;
- (void)requestLocationAuthorizationIfNeeded;
- (void)updateVPNInterface:(NSString *)interfaceName active:(BOOL)active;
- (void)updateVPNServiceWithKey:(NSString *)key status:(NSDictionary *)status;

@end

@implementation HWGrowlNetworkMonitor

@synthesize delegate;
@synthesize rlSrc;
@synthesize dynStore;
@synthesize networkInterfaceStates;
@synthesize previousIPCombined;
@synthesize locationManager;
@synthesize wifiClient;
@synthesize previousWiFiSignature;
@synthesize vpnInterfaceActiveStates;
@synthesize vpnServiceInterfaces;
@synthesize vpnServiceProtocolActiveStates;
@synthesize locationAuthorizationRequester;

-(id)init {
	if((self = [super init])){
		self.previousIPCombined = nil;
		self.networkInterfaceStates = [NSMutableDictionary dictionary];
		self.vpnInterfaceActiveStates = [NSMutableDictionary dictionary];
		self.vpnServiceInterfaces = [NSMutableDictionary dictionary];
		self.vpnServiceProtocolActiveStates = [NSMutableDictionary dictionary];
	}
	return self;
}

-(void)dealloc {
	[self stopObserving];
	
	[networkInterfaceStates release];
    networkInterfaceStates = nil;
    
    [previousIPCombined release];
    previousIPCombined = nil;
	
	[locationManager setDelegate:nil];
		[locationManager release];
		locationManager = nil;
		
		[self stopMonitoringWiFiEvents];
		[wifiClient release];
		wifiClient = nil;
		
		[previousWiFiSignature release];
		previousWiFiSignature = nil;
		
		[vpnInterfaceActiveStates release];
		vpnInterfaceActiveStates = nil;
		
		[vpnServiceInterfaces release];
		vpnServiceInterfaces = nil;
		
	[vpnServiceProtocolActiveStates release];
	vpnServiceProtocolActiveStates = nil;
	
	[locationAuthorizationRequester release];
	locationAuthorizationRequester = nil;
	    
	[super dealloc];
}

-(void)fireOnLaunchNotes {
	[self interateInterfaces];
}

-(void)setupDynamicStore
{
   if(dynStore != NULL)
      return;
   
   SCDynamicStoreContext context = {0, self, NULL, NULL, NULL};
   
	dynStore = SCDynamicStoreCreate(kCFAllocatorDefault,
                                   CFBundleGetIdentifier(CFBundleGetMainBundle()),
                                   scCallback,
                                   &context);
	if (!dynStore) {
		NSLog(@"SCDynamicStoreCreate() failed: %s", SCErrorString(SCError()));
		return;
	}
   
   rlSrc = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, dynStore, 0);
	if (!rlSrc)
		return;
	CFRunLoopAddSource(CFRunLoopGetMain(), rlSrc, kCFRunLoopDefaultMode);
   CFRelease(rlSrc);
}

-(void)startObserving
{
	[self setupDynamicStore];
	if (!dynStore)
		return;
	[self startMonitoringWiFiEvents];
		
	NSArray *watchedKeys = [NSArray arrayWithObjects:@"State:/Network/Interface/.*/Link", @"State:/Network/Interface/.*/AirPort", @"State:/Network/Global/IPv4", @"State:/Network/Global/IPv6", @"State:/Network/Service/.*/IPv4", @"State:/Network/Service/.*/IPv6", nil];
	if (!SCDynamicStoreSetNotificationKeys(dynStore,
                                          NULL,
                                          (CFArrayRef)watchedKeys))
   {
		NSLog(@"SCDynamicStoreSetNotificationKeys() failed: %s", SCErrorString(SCError()));
		CFRelease(dynStore);
		dynStore = NULL;
	}
}

-(void)stopObserving
{
	if (rlSrc) {
		CFRunLoopRemoveSource(CFRunLoopGetMain(), rlSrc, kCFRunLoopDefaultMode);
		rlSrc = NULL;
	}
	if (dynStore) {
		CFRelease(dynStore);
		dynStore = NULL;
	}
	[self stopMonitoringWiFiEvents];
}

-(void)updateInterface:(NSString*)interface forType:(NetworkInterfaceType)type withStatus:(NSDictionary*)status {
	HWGrowlNetworkInterfaceStatus *new = [[[HWGrowlNetworkInterfaceStatus alloc] initForInterface:interface
																														ofType:type
																												  withStatus:status] autorelease];	
	if(type == HWGAirPortInterface)
		[self updateAirportWithInterface:new];
	else if(type == HWGEthernetInterface)
		[self updateLinkWithInterface:new];
	
	[networkInterfaceStates setObject:new forKey:interface];
}

-(void)updateAirportWithInterface:(HWGrowlNetworkInterfaceStatus*)interface {
	NSString *interfaceString = [interface interface];
	NSDictionary *newValue = [interface status];
	NSDictionary *existing = [(HWGrowlNetworkInterfaceStatus*)[networkInterfaceStates objectForKey:interfaceString] status];
	//	NSLog(CFSTR("AirPort event"));
	
	id newBSSID = nil;
	if (newValue)
		newBSSID = [newValue objectForKey:@"BSSID"];
	
	id oldBSSID = nil;
	if (existing)
		oldBSSID = [existing objectForKey:@"BSSID"];
		
	if (newValue && ![oldBSSID isEqual:newBSSID] && !(newBSSID && oldBSSID && CFEqual(oldBSSID, newBSSID))) {
		NSNumber *linkStatus = [newValue objectForKey:@"Link Status"];
		NSNumber *powerStatus = [newValue objectForKey:@"Power Status"];
		if (linkStatus || powerStatus) {
			int status = 0;
			if (linkStatus) {
				status = [linkStatus intValue];
			} else if (powerStatus) {
				status = [powerStatus intValue];
				status = !status;
			}
			NSString *networkName = nil;
			if (status == AIRPORT_DISCONNECTED) {
				networkName = [self networkNameFromAirPortStatus:existing interface:nil];
				if(networkName)
                    [self airportDisconnected:networkName];
			} else {
				[self notifyAirportConnectedForInterface:interfaceString status:newValue bssid:newBSSID retryCount:3];
			}
		}
	}
}

- (NSString *)networkNameFromAirPortStatus:(NSDictionary *)status interface:(NSString *)interfaceName
{
	NSString *networkName = [self stringFromSSIDValue:[status objectForKey:@"SSID_STR"]];
	if (!networkName)
		networkName = [self stringFromSSIDValue:[status objectForKey:@"SSID"]];
	return networkName;
}

- (NSString *)stringFromSSIDValue:(id)ssidValue
{
	return HWGNetworkStringFromSSIDValue(ssidValue);
}

- (void)requestLocationAuthorizationIfNeeded
{
	if (self.locationAuthorizationRequester) {
		self.locationAuthorizationRequester();
		return;
	}
	
	if (![CLLocationManager locationServicesEnabled])
		return;
	
	if (!self.locationManager)
		self.locationManager = [[[CLLocationManager alloc] init] autorelease];
	
	self.locationManager.delegate = self;
	CLAuthorizationStatus authorizationStatus = [self.locationManager authorizationStatus];
	if (authorizationStatus == kCLAuthorizationStatusNotDetermined)
		[self.locationManager requestWhenInUseAuthorization];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager
{
	CLAuthorizationStatus authorizationStatus = [manager authorizationStatus];
	if ([self locationAuthorizationAllowsWiFiInfo:authorizationStatus]) {
		[self notifyCurrentWiFiNetworkAfterLocationAuthorization];
	}
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
	if ([self locationAuthorizationAllowsWiFiInfo:status]) {
		[self notifyCurrentWiFiNetworkAfterLocationAuthorization];
	}
}

- (BOOL)locationAuthorizationAllowsWiFiInfo:(CLAuthorizationStatus)authorizationStatus
{
	return authorizationStatus == kCLAuthorizationStatusAuthorized ||
		   authorizationStatus == kCLAuthorizationStatusAuthorizedAlways;
}

- (NSString *)currentWiFiSSIDForInterface:(NSString *)interfaceName
{
	CWInterface *wifiInterface = [self wiFiInterfaceForName:interfaceName];
	NSString *ssid = [self ssidForWiFiInterface:wifiInterface];
	if (!ssid && [interfaceName length]) {
		CWInterface *defaultInterface = [self.wifiClient interface];
		if (defaultInterface != wifiInterface)
			ssid = [self ssidForWiFiInterface:defaultInterface];
	}
	return ssid;
}

- (NSString *)currentWiFiBSSIDForInterface:(NSString *)interfaceName
{
	CWInterface *wifiInterface = [self wiFiInterfaceForName:interfaceName];
	NSString *bssid = [self stringFromBSSIDValue:[wifiInterface bssid]];
	if (!bssid && [interfaceName length]) {
		CWInterface *defaultInterface = [self.wifiClient interface];
		if (defaultInterface != wifiInterface)
			bssid = [self stringFromBSSIDValue:[defaultInterface bssid]];
	}
	return bssid;
}

- (CWInterface *)wiFiInterfaceForName:(NSString *)interfaceName
{
	CWInterface *wifiInterface = nil;
	if ([interfaceName length])
		wifiInterface = [self.wifiClient interfaceWithName:interfaceName];
	if (!wifiInterface)
		wifiInterface = [self.wifiClient interface];
	return wifiInterface;
}

- (NSString *)ssidForWiFiInterface:(CWInterface *)wifiInterface
{
	NSString *ssid = [self stringFromSSIDValue:[wifiInterface ssid]];
	if (!ssid)
		ssid = [self stringFromSSIDValue:[wifiInterface ssidData]];
	return ssid;
}

- (void)startMonitoringWiFiEvents
{
	if (!self.wifiClient)
		self.wifiClient = [CWWiFiClient sharedWiFiClient];
	
	self.wifiClient.delegate = self;
	[self startMonitoringWiFiEvent:CWEventTypeSSIDDidChange];
	[self startMonitoringWiFiEvent:CWEventTypeBSSIDDidChange];
	[self startMonitoringWiFiEvent:CWEventTypeLinkDidChange];
}

- (void)stopMonitoringWiFiEvents
{
	if (self.wifiClient.delegate == self)
		self.wifiClient.delegate = nil;
	
	NSError *error = nil;
	if (![self.wifiClient stopMonitoringAllEventsAndReturnError:&error] && error)
		NSLog(@"Unable to stop CoreWLAN event monitoring: %@", error);
}

- (void)startMonitoringWiFiEvent:(CWEventType)eventType
{
	NSError *error = nil;
	if (![self.wifiClient startMonitoringEventWithType:eventType error:&error] && error)
		NSLog(@"Unable to start CoreWLAN event monitoring for %ld: %@", (long)eventType, error);
}

- (void)ssidDidChangeForWiFiInterfaceWithName:(NSString *)interfaceName
{
	[self notifyCurrentWiFiNetworkForInterface:interfaceName retryCount:3];
}

- (void)bssidDidChangeForWiFiInterfaceWithName:(NSString *)interfaceName
{
	[self notifyCurrentWiFiNetworkForInterface:interfaceName retryCount:3];
}

- (void)linkDidChangeForWiFiInterfaceWithName:(NSString *)interfaceName
{
	[self notifyCurrentWiFiNetworkForInterface:interfaceName retryCount:3];
}

- (void)clientConnectionInterrupted
{
	self.previousWiFiSignature = nil;
}

- (void)clientConnectionInvalidated
{
	self.previousWiFiSignature = nil;
}

- (void)notifyCurrentWiFiNetworkForInterface:(NSString *)interfaceName retryCount:(NSUInteger)retryCount
{
	[self requestLocationAuthorizationIfNeeded];
	NSString *networkName = [self currentWiFiSSIDForInterface:interfaceName];
	NSString *bssid = [self currentWiFiBSSIDForInterface:interfaceName];
	
	if (networkName) {
		[self airportConnected:networkName bssid:bssid];
		return;
	}
	
	if (retryCount == 0)
	{
		[self logUnavailableWiFiSSIDForInterface:interfaceName status:nil];
		return;
	}
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self notifyCurrentWiFiNetworkForInterface:interfaceName retryCount:retryCount - 1];
	});
}

- (void)notifyAirportConnectedForInterface:(NSString *)interfaceName status:(NSDictionary *)status bssid:(id)bssidValue retryCount:(NSUInteger)retryCount
{
	NSString *networkName = [self networkNameFromAirPortStatus:status interface:interfaceName];
	id effectiveBSSID = bssidValue;
	if (!networkName) {
		[self requestLocationAuthorizationIfNeeded];
		networkName = [self currentWiFiSSIDForInterface:interfaceName];
		if (!effectiveBSSID)
			effectiveBSSID = [self currentWiFiBSSIDForInterface:interfaceName];
	}
	
	if (networkName) {
		[self airportConnected:networkName bssid:effectiveBSSID];
		return;
	}
	
	if (retryCount == 0) {
		[self logUnavailableWiFiSSIDForInterface:interfaceName status:status];
		return;
	}
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		NSString *key = [NSString stringWithFormat:@"State:/Network/Interface/%@/AirPort", interfaceName];
		CFDictionaryRef latestStatus = SCDynamicStoreCopyValue(dynStore, (CFStringRef)key);
		NSDictionary *latestStatusDictionary = nil;
		if (latestStatus)
			latestStatusDictionary = [(NSDictionary *)latestStatus autorelease];
		
		id latestBSSID = [latestStatusDictionary objectForKey:@"BSSID"];
		if (!latestBSSID)
			latestBSSID = [self currentWiFiBSSIDForInterface:interfaceName];
		
		[self notifyAirportConnectedForInterface:interfaceName status:latestStatusDictionary bssid:latestBSSID retryCount:retryCount - 1];
	});
	}

- (void)logUnavailableWiFiSSIDForInterface:(NSString *)interfaceName status:(NSDictionary *)status
{
	CLAuthorizationStatus authorizationStatus = self.locationManager ? [self.locationManager authorizationStatus] : kCLAuthorizationStatusNotDetermined;
	CWInterface *wifiInterface = [self wiFiInterfaceForName:interfaceName];
	NSLog(@"Wi-Fi SSID unavailable for interface %@. Location enabled=%@ authorization=%d CoreWLAN interface=%@ ssid=%@ ssidDataLength=%lu dynamicStoreSSID_STR=%@ dynamicStoreSSID=%@",
		  interfaceName,
		  [CLLocationManager locationServicesEnabled] ? @"YES" : @"NO",
		  authorizationStatus,
		  [wifiInterface interfaceName],
		  [wifiInterface ssid],
		  (unsigned long)[[wifiInterface ssidData] length],
		  [status objectForKey:@"SSID_STR"],
		  [status objectForKey:@"SSID"]);
}

- (void)notifyCurrentWiFiNetworkAfterLocationAuthorization
{
	CWInterface *wifiInterface = [self.wifiClient interface];
	NSString *networkName = [self ssidForWiFiInterface:wifiInterface];
	if (!networkName)
		return;
	
	[self airportConnected:networkName bssid:[wifiInterface bssid]];
}

-(void)airportDisconnected:(NSString*)networkName {
	self.previousWiFiSignature = nil;
	
	    NSData *iconData = HWGPNGDataForSystemSymbol(@"wifi.slash", @"Network-Wifi-Off");
    [delegate notifyWithName:@"AirportDisconnected"
							 title:NSLocalizedString(@"AirPort Disconnected", @"")
					 description:[NSString stringWithFormat:NSLocalizedString(@"Left network %@.", @""), networkName]
							  icon:iconData
			  identifierString:@"HWGrowlAirPort"
				  contextString:HWGWiFiSettingsURLString
							plugin:self];
}

-(void)airportConnected:(NSString*)name bssid:(id)bssidValue {
	NSString *ssid = [self stringFromSSIDValue:name];
	if (!ssid)
		return;
	
	NSString *bssid = [self stringFromBSSIDValue:bssidValue];
	NSString *signature = [NSString stringWithFormat:@"%@|%@", ssid, bssid ? bssid : @""];
	if ([signature isEqualToString:self.previousWiFiSignature])
		return;
	self.previousWiFiSignature = signature;
	
	NSString *description = [NSString stringWithFormat:NSLocalizedString(@"Joined network.\nSSID: %@\nBSSID: %@", @"AirPort connected notification body"),
										 ssid,
										 bssid ? bssid : NSLocalizedString(@"Unknown", @"Unknown network BSSID")];
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"AirPort Connected: %@", @"AirPort connected notification title with SSID"), ssid];
	NSString *identifier = [NSString stringWithFormat:@"HWGrowlAirPort-%@-%@", ssid, bssid ? bssid : @"UnknownBSSID"];
	
    
    NSData *iconData = HWGPNGDataForSystemSymbol(@"wifi", @"Network-Wifi-4");

	[delegate notifyWithName:@"AirportConnected"
							 title:title
					 description:description
							  icon:iconData
			  identifierString:identifier
				  contextString:HWGWiFiSettingsURLString
							plugin:self];
}

- (NSString *)stringFromBSSIDValue:(id)bssidValue
{
	return HWGNetworkStringFromBSSIDValue(bssidValue);
}

-(void)updateLinkWithInterface:(HWGrowlNetworkInterfaceStatus*)interface {
	NSString *interfaceString = [interface interface];
	NSDictionary *newValue = [interface status];
	NSDictionary *existing = [(HWGrowlNetworkInterfaceStatus*)[networkInterfaceStates objectForKey:interfaceString] status];
	int newActive = [[newValue objectForKey:@"Active"] intValue];
	int oldActive = [[existing objectForKey:@"Active"] intValue];
	BOOL isVPNInterface = HWGNetworkInterfaceNameIsVPN(interfaceString);
	if (isVPNInterface)
		[self updateVPNInterface:interfaceString active:(newActive != 0)];
	
	NSString *noteName = nil;
	NSString *noteTitle = nil;
	NSString *noteDescription = nil;
	NSString *imageName = nil;
	if (newActive && !oldActive) {
		if (isVPNInterface) {
			noteName = nil;
		} else {
			noteName = @"NetworkLinkUp";
			noteTitle = NSLocalizedString(@"Network Link Up", @"");
			noteDescription = [NSString stringWithFormat:
									 NSLocalizedString(@"Interface:\t%@\nMedia:\t%@", "The first %@ will be replaced with the interface (en0, en1, etc) second %@ will be replaced by a description of the Ethernet media such as '100BT/full-duplex'"),
									 interfaceString,
									 [self getMediaForInterface:interfaceString]];
			imageName = @"Network-Ethernet-On";
		}
	} else if (!newActive && oldActive) {
		if (isVPNInterface) {
			noteName = nil;
		} else {
			noteName = @"NetworkLinkDown";
			noteTitle = NSLocalizedString(@"Network Link Down", @"");
			noteDescription = [NSString stringWithFormat:NSLocalizedString(@"Interface:\t%@", nil), interfaceString];
			imageName = @"Network-Ethernet-Off";
		}
	}
	
    NSData *iconData = HWGPNGDataForSystemSymbol(newActive ? @"network" : @"network.slash", imageName);
   
	if(noteName){
		[delegate notifyWithName:noteName
								 title:noteTitle
						 description:noteDescription
								  icon:iconData
				  identifierString:@"HWGrowlNetworkLink"
					  contextString:HWGNetworkSettingsURLString
								plugin:self];
	}
}

- (void)updateVPNInterface:(NSString *)interfaceName active:(BOOL)active
{
	if (![interfaceName length])
		return;
	
	NSNumber *oldActiveNumber = [self.vpnInterfaceActiveStates objectForKey:interfaceName];
	BOOL oldActive = [oldActiveNumber boolValue];
	if (oldActiveNumber && oldActive == active)
		return;
	
	[self.vpnInterfaceActiveStates setObject:[NSNumber numberWithBool:active] forKey:interfaceName];
	if (!oldActiveNumber && !active)
		return;
	
	NSString *noteName = active ? @"VPNConnected" : @"VPNDisconnected";
	NSString *noteTitle = active ? NSLocalizedString(@"VPN Connected", @"") : NSLocalizedString(@"VPN Disconnected", @"");
	NSString *noteDescription = [NSString stringWithFormat:NSLocalizedString(@"Interface:\t%@", nil), interfaceName];
	NSData *iconData = HWGPNGDataForSystemSymbol(active ? @"network.badge.shield.half.filled" : @"network.slash", active ? @"Network-Generic-On" : @"Network-Generic-Off");
	NSString *identifier = [NSString stringWithFormat:@"HWGrowlVPN-%@", interfaceName];
	
	[delegate notifyWithName:noteName
						 title:noteTitle
				 description:noteDescription
						  icon:iconData
		  identifierString:identifier
			  contextString:HWGVPNSettingsURLString
						plugin:self];
}

- (void)updateVPNServiceWithKey:(NSString *)key status:(NSDictionary *)status
{
	NSArray *components = [key componentsSeparatedByString:@"/"];
	if ([components count] < 5)
		return;
	
	NSString *serviceID = [components objectAtIndex:3];
	NSString *protocolName = [components lastObject];
	NSString *serviceProtocolKey = [NSString stringWithFormat:@"%@/%@", serviceID, protocolName];
	NSString *interfaceName = [status objectForKey:@"InterfaceName"];
	if (!interfaceName)
		interfaceName = [self.vpnServiceInterfaces objectForKey:serviceID];
	if (![interfaceName length])
		return;
	if (!HWGNetworkInterfaceNameIsVPN(interfaceName))
		return;
	
	if ([status objectForKey:@"InterfaceName"])
		[self.vpnServiceInterfaces setObject:interfaceName forKey:serviceID];
	
	NSArray *addresses = [status objectForKey:@"Addresses"];
	BOOL protocolActive = [addresses isKindOfClass:[NSArray class]] && [addresses count] > 0;
	[self.vpnServiceProtocolActiveStates setObject:[NSNumber numberWithBool:protocolActive] forKey:serviceProtocolKey];
	
	BOOL serviceActive = NO;
	NSString *servicePrefix = [serviceID stringByAppendingString:@"/"];
	for (NSString *trackedKey in self.vpnServiceProtocolActiveStates) {
		if ([trackedKey hasPrefix:servicePrefix] && [[self.vpnServiceProtocolActiveStates objectForKey:trackedKey] boolValue]) {
			serviceActive = YES;
			break;
		}
	}
	
	[self updateVPNInterface:interfaceName active:serviceActive];
	if (!serviceActive)
		[self.vpnServiceInterfaces removeObjectForKey:serviceID];
}

/* TO DO: REWRITE ME WITH BETTER METHODS OF GETTING INFO */
- (NSString *)getMediaForInterface:(NSString*)interfaceString {
	// This is all made by looking through Darwin's src/network_cmds/ifconfig.tproj.
	// There's no pretty way to get media stuff; I've stripped it down to the essentials
	// for what I'm doing.
	
	const char *interface = [interfaceString UTF8String];
	size_t length = strlen(interface);
	if (length >= IFNAMSIZ)
		NSLog(@"Interface name too long");
	
	int s = socket(AF_INET, SOCK_DGRAM, 0);
	if (s < 0) {
		NSLog(@"Can't open datagram socket");
		return NULL;
	}
	struct ifmediareq ifmr;
	memset(&ifmr, 0, sizeof(ifmr));
	strncpy(ifmr.ifm_name, interface, sizeof(ifmr.ifm_name));
	
	if (ioctl(s, SIOCGIFMEDIA, (caddr_t)&ifmr) < 0) {
		// Media not supported.
		close(s);
		return NULL;
	}
	
	close(s);
	
	// Now ifmr.ifm_current holds the selected type (probably auto-select)
	// ifmr.ifm_active holds details (100baseT <full-duplex> or similar)
	// We only want the ifm_active bit.
	
	const char *type = "Unknown";
	
	// We'll only look in the Ethernet list. I don't care about anything else.
	struct ifmedia_description *desc;
	for (desc = ifm_subtype_ethernet_descriptions; desc->ifmt_string; ++desc) {
		if (IFM_SUBTYPE(ifmr.ifm_active) == desc->ifmt_word) {
			type = desc->ifmt_string;
			break;
		}
	}
	
	NSMutableString *options = nil;
	
	// And fill in the duplex settings.
	for (desc = ifm_shared_option_descriptions; desc->ifmt_string; desc++) {
		if (ifmr.ifm_active & desc->ifmt_word) {
			if (options) {
				[options appendFormat:@",%s", desc->ifmt_string];
			} else {
				options = [NSMutableString stringWithUTF8String:desc->ifmt_string];
			}
		}
	}
	
	NSString *media;
	if (options) {
		media = [NSString stringWithFormat:@"%s <%@>",
					type,
					options];
	} else {
		media = [NSString stringWithUTF8String:type];
	}
	
	return media;
}

-(void)updateIP {
	NSArray *routable = [GrowlNetworkUtilities routableIPAddresses];
	NSString *combined = [routable componentsJoinedByString:@"\n"];
	if([combined isEqualTo:previousIPCombined])
		return;
    
	NSString *imageName = nil;
	if([combined isEqualToString:@""]) {
		combined = nil;
		imageName = @"Network-Generic-Off";
	}else{
		imageName = @"Network-Generic-On";
	}

    NSData *iconData = HWGPNGDataForSystemSymbol([combined length] ? @"network" : @"network.slash", imageName);
	[delegate notifyWithName:@"IPAddressChange"
							 title:NSLocalizedString(@"IP Addresses Updated", @"")
					 description:combined ? combined : NSLocalizedString(@"No routable IP addresses", @"")
							  icon:iconData
			  identifierString:@"HWGrowlIPAddressChange"
				  contextString:HWGNetworkSettingsURLString
							plugin:self];
	
	self.previousIPCombined = combined;
}

- (void) interateInterfaces
{
    __block NSMutableArray *keys = [NSMutableArray array];
    //process the currently standing interfaces and fire off notifications for those
    CFDictionaryRef interfaces = SCDynamicStoreCopyValue(dynStore, CFSTR("State:/Network/Interface"));
    NSArray *interfaceNames = [(NSDictionary*)interfaces objectForKey:@"Interfaces"];

    [interfaceNames enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (![obj hasPrefix:@"en"] || [obj length] < 3 || !isdigit([obj characterAtIndex:2])) {
			return;
		}
		
		//Check against airport first
		NSString *key = [NSString stringWithFormat:@"State:/Network/Interface/%@/AirPort", obj];
		CFDictionaryRef status = SCDynamicStoreCopyValue(dynStore, (CFStringRef)key);
        if(status)
        {
            [keys addObject:key];
            CFRelease(status);
        }
        else
        {
            key = [NSString stringWithFormat:@"State:/Network/Interface/%@/Link", obj];
            status = SCDynamicStoreCopyValue(dynStore, (CFStringRef)key);
            if(status)
            {
                [keys addObject:key];
                CFRelease(status);
            }
        }
    }];
    if(interfaces)
        CFRelease(interfaces);

    //fire off IPv4 and IPv6 notifications
    [keys addObject:@"State:/Network/Global/IPv4"];
    [keys addObject:@"State:/Network/Global/IPv6"];

    scCallback(dynStore, (CFArrayRef)keys, self);
}

static void scCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
	@autoreleasepool {
        HWGrowlNetworkMonitor *observer = info;
        
        [(NSArray*)changedKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
            if([key hasPrefix:@"State:/Network/Global"])
                [observer updateIP];
            else if([key hasPrefix:@"State:/Network/Interface"])
            {
                NSArray *notification = [key componentsSeparatedByString:@"/"];
                NSString *interface = [notification objectAtIndex:[notification count]-2];
                
                    if([key hasSuffix:@"AirPort"])  //Check against airport first
                    {
                        CFDictionaryRef status = SCDynamicStoreCopyValue(store, (CFStringRef)key);
                        if(status) {
                            [observer updateInterface:interface forType:HWGAirPortInterface withStatus:(NSDictionary*)status];
                            CFRelease(status);
                        }
                    }
                    else if([key hasSuffix:@"Link"])
                    {
                        NSString *isAnAirportConnection = [key stringByReplacingOccurrencesOfString:@"Link" withString:@"AirPort"];
                        CFDictionaryRef status = SCDynamicStoreCopyValue(store, (CFStringRef)isAnAirportConnection);
                        if(!status)
                        {
                            status = SCDynamicStoreCopyValue(store, (CFStringRef)key);
                            if(status) {
                                [observer updateInterface:interface forType:HWGEthernetInterface withStatus:(NSDictionary*)status];
                                CFRelease(status);
                            }
                        }
                        else
                            CFRelease(status);
                    }
                    else
                        NSLog(@"Invalid Notification: %@", key);
            }
			else if([key hasPrefix:@"State:/Network/Service"])
			{
				CFDictionaryRef status = SCDynamicStoreCopyValue(store, (CFStringRef)key);
				[observer updateVPNServiceWithKey:key status:(NSDictionary *)status];
				if (status)
					CFRelease(status);
			}
        }];
    }
}

#pragma mark HWGrowlPluginProtocol

-(void)setDelegate:(id<HWGrowlPluginControllerProtocol>)aDelegate{
	delegate = aDelegate;
}
-(id<HWGrowlPluginControllerProtocol>)delegate {
	return delegate;
}
-(NSString*)pluginDisplayName {
	return NSLocalizedString(@"Network Monitor", @"");
}
-(NSImage*)preferenceIcon {
	static NSImage *_icon = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_icon = [[NSImage imageNamed:@"HWGPrefsNetwork"] retain];
	});
	return _icon;
}
-(NSView*)preferencePane {
	return nil;
}

#pragma mark HWGrowlPluginNotifierProtocol

-(NSArray*)noteNames {
	return [NSArray arrayWithObjects:@"IPAddressChange", @"NetworkLinkUp", @"NetworkLinkDown", @"AirportConnected", @"AirportDisconnected", @"VPNConnected", @"VPNDisconnected", nil];
}
-(NSDictionary*)localizedNames {
	return [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"IP Address Changed", @""), @"IPAddressChange",
			  NSLocalizedString(@"Network Link Up", @""), @"NetworkLinkUp",
			  NSLocalizedString(@"Network Link Down", @""), @"NetworkLinkDown", 
			  NSLocalizedString(@"AirPort Connected", @""), @"AirportConnected", 
			  NSLocalizedString(@"AirPort Disconnected", @""), @"AirportDisconnected",
			  NSLocalizedString(@"VPN Connected", @""), @"VPNConnected",
			  NSLocalizedString(@"VPN Disconnected", @""), @"VPNDisconnected", nil];
}
-(NSDictionary*)noteDescriptions {
	return [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Sent when the systems IP address changes", @""), @"IPAddressChange", 
			  NSLocalizedString(@"Sent when an Ethernet link starts", @""), @"NetworkLinkUp",
			  NSLocalizedString(@"Sent when an Ethernet link goes down", @""), @"NetworkLinkDown", 
			  NSLocalizedString(@"Sent when AirPort connects to a network", @""), @"AirportConnected", 
			  NSLocalizedString(@"Sent when AirPort disconnects from a network", @""), @"AirportDisconnected",
			  NSLocalizedString(@"Sent when a VPN connects", @""), @"VPNConnected",
			  NSLocalizedString(@"Sent when a VPN disconnects", @""), @"VPNDisconnected", nil];
}
-(NSArray*)defaultNotifications {
	return [NSArray arrayWithObjects:@"IPAddressChange", @"NetworkLinkUp", @"NetworkLinkDown", @"AirportConnected", @"AirportDisconnected", @"VPNConnected", @"VPNDisconnected", nil];
}

-(void)noteClosed:(NSString*)contextString byClick:(BOOL)clicked {
	if(clicked && [contextString length]) {
		NSURL *settingsURL = [NSURL URLWithString:contextString];
		dispatch_async(dispatch_get_main_queue(), ^{
			if (![[NSWorkspace sharedWorkspace] openURL:settingsURL]) {
				NSURL *fallbackURL = [NSURL URLWithString:HWGNetworkSettingsURLString];
				[[NSWorkspace sharedWorkspace] openURL:fallbackURL];
			}
		});
	}
}

@end
