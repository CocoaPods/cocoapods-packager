//
//  AppDelegate.m
//  LibraryConsumer
//
//  Created by Ole Gammelgaard Poulsen on 16/10/14.
//  Copyright (c) 2014 Shape A/S. All rights reserved.
//

#import "AppDelegate.h"
#import "MyDemoClass.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

	NSLog(@"%@", [MyDemoClass welcomeMessage]);

	return YES;
}

@end
