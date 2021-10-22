//
//  AppDelegate.m
//  KitemetricsObjC
//
//  Created by mcl on 3/20/17.
//  Copyright © 2017 Kitefaster, LLC. All rights reserved.
//

#import "AppDelegate.h"

//If you do not want to use modules for import you can use the below #import statement instead
//#import <Kitemetrics/Kitemetrics-Swift.h>
@import Kitemetrics;

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[Kitemetrics shared] initSessionWithApiKey:@"API_KEY"];
    //If userIdentifier is known on startup, you can set it here
//    [[Kitemetrics shared] initSessionWithApiKey:@"API_KEY" userIdentifier:@"012345abc"];
    
//    Log in app purchase events with logInAppPurchase after the purchase has been verified.  If the IAP type is known set it with KFPurchaseTypeAppleInAppNonConsumable, KFPurchaseTypeAppleInAppConsumable, KFPurchaseTypeAppleInAppRenewableSubscription, or KFPurchaseTypeAppleInAppNonRenewingSubscription.
//    [[Kitemetrics shared] logInAppPurchase:skProduct quantity:1 purchaseType:KFPurchaseType];
//  If the SKProduct is unavailble or this is an eCommerce transaction you can pass the productIdentifier, price and currency code manually
    NSDecimal price = [[[NSDecimalNumber alloc] initWithFloat:0.99f] decimalValue];
    [[Kitemetrics shared] logPurchaseWithProductIdentifier:@"com.kitefaster.demo.KitemetricsObjC.TestPurchase1" price:price currencyCode:@"USD" quantity:1 purchaseType:KFPurchaseTypeAppleInAppConsumable];
    
    [[Kitemetrics shared] logError:@"Test Error"];
    [[Kitemetrics shared] logEvent:@"Test Event"];
    [[Kitemetrics shared] logInviteWithMethod:@"Test Invite" code: @"Test Code 001"];
    [[Kitemetrics shared] logRedeemInviteWithCode:@"Test Code 001"];
    [[Kitemetrics shared] logSignUpWithMethod:@"email" userIdentifier:@"012345abc"];
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
