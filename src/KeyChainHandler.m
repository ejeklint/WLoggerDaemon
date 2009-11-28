//
//  KeyChainHandler.m
//  USBWeatherStationReader
//
//  Created by Per Ejeklint on 2009-05-28.
//  Copyright 2009 Heimore Group AB. All rights reserved.
//

#import "KeyChainHandler.h"


@implementation KeyChainHandler

+ (EMGenericKeychainItem *) getTwitterKeychainItemForUser: (NSString *) username {
	return [[EMKeychainProxy sharedProxy]
			genericKeychainItemForService:@"WLoggerTwitter" withUsername:username];
}

+ (EMGenericKeychainItem *) getCouchDBKeychainItemForUser: (NSString *) username {
	return [[EMKeychainProxy sharedProxy]
			genericKeychainItemForService:@"WLoggerCouchDB" withUsername:username];
}	

@end
