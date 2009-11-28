//
//  RemoteProtocol.h
//  WLoggerDaemon
//
//  Created by Per Ejeklint on 2009-11-19.
//  Copyright 2009 Heimore Group AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol RemoteProtocol

- (NSDictionary *) getSettings;
- (BOOL) saveSettings: (NSDictionary *) dict;
- (BOOL) setupTwitter: (NSDictionary*) settings;
- (BOOL) setupCouchDB: (NSDictionary*) settings;


@end
