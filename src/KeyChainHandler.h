//
//  KeyChainHandler.h
//  USBWeatherStationReader
//
//  Created by Per Ejeklint on 2009-05-28.
//  Copyright 2009 Heimore Group AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "EMKeychainProxy.h"


@interface KeyChainHandler : NSObject {

}

+ (EMGenericKeychainItem *) getTwitterKeychainItemForUser: (NSString *) username;
+ (EMGenericKeychainItem *) getCouchDBKeychainItemForUser: (NSString *) username;

@end
