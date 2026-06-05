//
//  HWGrowlPluginController.m
//  HardwareGrowler
//
//  Created by Daniel Siemer on 5/2/12.
//  Copyright (c) 2012 The Growl Project, LLC. All rights reserved.
//

#import "HWGrowlPluginController.h"

//DO NOT TOUCH, FOR KEEPING LOCALIZATION SCRIPT SIMPLER
#define GrowlOffSwitchFake NSLocalizedString(@"OFF", @"If the string is too long, use O");
#define GrowlOnSwitchFake NSLocalizedString(@"ON", @"If the string is too long, use I");

@interface HWGrowlPluginController ()

@property (nonatomic, retain) NSMutableArray *notifiers;
@property (nonatomic, retain) NSMutableArray *monitors;
@property (nonatomic, retain) HWNotificationAdapter *notificationAdapter;

- (void)startEnabledPlugins;
- (void)startPlugin:(id)plugin;

@end

@implementation HWGrowlPluginController

@synthesize plugins;
@synthesize notifiers;
@synthesize monitors;
@synthesize notificationAdapter;

-(void)dealloc {
	[plugins release];
	[notifiers release];
	[monitors release];
	[notificationAdapter release];
	[super dealloc];
}

-(id)init {
	if((self = [super init])){
			self.plugins = [NSMutableArray array];
			self.notifiers = [NSMutableArray array];
			self.monitors = [NSMutableArray array];
			[self loadPlugins];
			
			self.notificationAdapter = [[[HWNotificationAdapter alloc] init] autorelease];
			self.notificationAdapter.delegate = self;
			[self.notificationAdapter requestAuthorization];
			
			[self startEnabledPlugins];
		
		if([self onLaunchEnabled])
			[self fireOnLaunchNotes];
	}
	return self;
}

-(void)loadPlugins {
	NSString *pluginsPath = [[NSBundle mainBundle] builtInPlugInsPath];
	NSArray *pluginBundles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pluginsPath 
																										  error:nil];
	if(pluginBundles) {
		NSDictionary *disabledPlugins = [[NSUserDefaults standardUserDefaults] objectForKey:@"DisabledPlugins"];
		
		__block HWGrowlPluginController *blockSelf = self;
		[pluginBundles enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			NSString *bundlePath = [pluginsPath stringByAppendingPathComponent:obj];
			NSBundle *pluginBundle = [NSBundle bundleWithPath:bundlePath];
			if(pluginBundle && [pluginBundle load])
			{
				NSString *bundleID = [pluginBundle bundleIdentifier];
				id plugin = [[[pluginBundle principalClass] alloc] init];
				if(plugin)
				{ 
					if([plugin conformsToProtocol:@protocol(HWGrowlPluginProtocol)])
					{
						[plugin setDelegate:self];
						if(!HWGPluginIsAvailable(plugin)) {
							[plugin release];
							return;
						}
						BOOL disabled = HWGPluginShouldBeDisabled(plugin, bundleID, disabledPlugins);
						
						NSMutableDictionary *pluginDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:plugin, @"plugin", 
																	  [NSNumber numberWithBool:disabled], @"disabled", nil];
						[blockSelf.plugins addObject:pluginDict];
						
						if([plugin conformsToProtocol:@protocol(HWGrowlPluginNotifierProtocol)])
							[blockSelf.notifiers addObject:plugin];
						if([plugin conformsToProtocol:@protocol(HWGrowlPluginMonitorProtocol)])
							[blockSelf.monitors addObject:plugin];
					}else{
						NSLog(@"%@ does not conform to HWGrowlPluginProtocol", NSStringFromClass([pluginBundle principalClass]));
					}
					[plugin release];
				}else{
					NSLog(@"We couldn't instantiate %@ for plugin %@", NSStringFromClass([pluginBundle principalClass]), bundleID);
				}
			}else{
				NSLog(@"%@ is not a bundle or could not be loaded", bundlePath);
			}
		}];
	}
	[plugins sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		return [[[obj1 objectForKey:@"plugin"] pluginDisplayName] compare:[[obj2 objectForKey:@"plugin"] pluginDisplayName]];
	}];
}
			
-(void)startEnabledPlugins {
	[plugins enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			if(!HWGPluginDictionaryIsDisabled(obj))
			[self startPlugin:[obj objectForKey:@"plugin"]];
	}];
}

- (void)startPlugin:(id)plugin
{
	if([plugin respondsToSelector:@selector(startObserving)])
		[plugin startObserving];
	else if([plugin respondsToSelector:@selector(postRegistrationInit)])
		[plugin postRegistrationInit];
}

-(void)fireOnLaunchNotes {
	[notifiers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			if(![self pluginDisabled:obj] && [obj respondsToSelector:@selector(fireOnLaunchNotes)])
			[obj fireOnLaunchNotes];
	}];
}

-(void)notifyWithName:(NSString*)name 
					 title:(NSString*)title
			 description:(NSString*)description
					  icon:(NSData*)iconData
	  identifierString:(NSString*)identifier
		  contextString:(NSString*)context
					plugin:(id)plugin
{
	__block BOOL disabled = NO;
	[plugins enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if([obj objectForKey:@"plugin"] == plugin) 
		{
			disabled = [[obj objectForKey:@"disabled"] boolValue];
			*stop = YES;
		}
	}];
	if(disabled)
		return;
	
	[notificationAdapter notifyWithName:name
								  title:title
							description:description
								   icon:iconData
					   identifierString:identifier
						  contextString:context
								 plugin:plugin];
}

-(BOOL)onLaunchEnabled {
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowExisting"];
}

-(BOOL)pluginDisabled:(id)plugin {
	__block BOOL disabled = NO;
	[plugins enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if([obj objectForKey:@"plugin"] == plugin) 
		{
			disabled = [[obj objectForKey:@"disabled"] boolValue];
			*stop = YES;
		}
	}];
	return disabled;
}

- (void)notificationAdapter:(HWNotificationAdapter *)adapter
didCloseNotificationForPluginClassName:(NSString *)pluginClassName
                   context:(NSString *)context
                   byClick:(BOOL)click
{
	if(!pluginClassName || !context)
		return;
	
	[notifiers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			if(HWGPluginMatchesClassName(obj, pluginClassName)){
			if([obj respondsToSelector:@selector(noteClosed:byClick:)])
				[obj noteClosed:context byClick:click];
			*stop = YES;
		}
	}];
}

@end
