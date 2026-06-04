//
//  AppDelegate.m
//  HardwareGrowlerLauncher
//
//  Created by Daniel Siemer on 5/2/12.
//  Copyright (c) 2012 The Growl Project, LLC. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
   NSArray *growlInstances = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.growl.hardwaregrowler"];
   if(!growlInstances.count)
   {
      NSURL* appURL = [[[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:@"../../../.." isDirectory:YES] URLByResolvingSymlinksInPath];
      NSLog(@"Launching HardwareGrowler at URL: %@", appURL);
      NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
      [configuration setArguments:[NSArray arrayWithObject:@"--hardwaregrowler-login-helper"]];
      [[NSWorkspace sharedWorkspace] openApplicationAtURL:appURL
                                            configuration:configuration
                                        completionHandler:^(NSRunningApplication *app, NSError *error) {
         if (error)
            NSLog(@"%@", error);
         [NSApp terminate:nil];
      }];
      return;
   }
	[NSApp terminate:nil];
}

@end
