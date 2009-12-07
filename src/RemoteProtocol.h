//
//  RemoteProtocol.h
//  WLoggerDaemon
//
//  Created by Per Ejeklint on 2009-11-19.
//  Copyright 2009 Heimore Group AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define KEY_REMOTE_CONNECTION_NAME @"se.ejeklint.WLoggerDaemonConnection"

#define KEY_LEVEL_RAIN @"rainBatteryLevel"
#define KEY_LEVEL_WIND @"windBatteryLevel"
#define KEY_LEVEL_UV @"uvBatteryLevel"
#define KEY_LEVEL_BASE @"baseBatteryLevel"
#define KEY_LEVEL_SENSOR_ @"tempBatteryLevelSensor_"

#define KEY_POWER_BASE @"baseHasExternalPower"
#define KEY_RADIO_CLOCK_SYNC @"baseHasRadioSync"
#define KEY_RADIO_CLOCK_LEVEL @"baseRadioSyncLevel"
#define KEY_BASE_STATION_TIME @"baseStationTime"
#define KEY_RAIN_TOTAL_RESET_TIME @"rainTotalResetTime"


@protocol RemoteProtocol

- (NSDictionary *) getSettings;
- (NSDictionary *) getLevels;
- (BOOL) saveSettings: (NSDictionary *) dict;
- (BOOL) setupTwitter: (NSDictionary*) settings;
- (BOOL) setupCouchDB: (NSDictionary*) settings;
- (BOOL) setDebug: (NSNumber*) state;
- (void) hourChime: (NSTimer*) timer;

@end
