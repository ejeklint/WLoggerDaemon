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

#define KEY_POWER_BASE @"baseStationPower"
#define KEY_RADIO_CLOCK_SYNC @"baseRadioSync"
#define KEY_RADIO_CLOCK_LEVEL @"baseRadioLevel"


@protocol RemoteProtocol

- (NSDictionary *) getSettings;
- (NSDictionary *) getLevels;
- (BOOL) saveSettings: (NSDictionary *) dict;
- (BOOL) setupTwitter: (NSDictionary*) settings;
- (BOOL) setupCouchDB: (NSDictionary*) settings;
- (BOOL) setDebug: (NSNumber*) state;

@end
