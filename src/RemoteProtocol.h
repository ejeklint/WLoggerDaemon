//
//  RemoteProtocol.h
//  WLoggerDaemon
//
//  Created by Per Ejeklint on 2009-11-19.
//  Copyright 2009 Heimore Group AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define KEY_LEVEL_RAIN @"rainBatteryLevel"
#define KEY_LEVEL_WIND @"windBatteryLevel"
#define KEY_LEVEL_UV @"uvBatteryLevel"
#define KEY_LEVEL_SENSOR_ @"tempBatteryLevelSensor_"


@protocol RemoteProtocol

- (NSDictionary *) getSettings;
- (NSDictionary *) getLevels;
- (BOOL) saveSettings: (NSDictionary *) dict;
- (BOOL) setupTwitter: (NSDictionary*) settings;
- (BOOL) setupCouchDB: (NSDictionary*) settings;
- (BOOL) setDebug: (NSNumber*) state;

@end
