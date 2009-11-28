//
//  WLoggerPreferencesPref.h
//
//  Created by Per Ejeklint on 2009-11-16.
//  Copyright 2009 Heimore Group AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <PreferencePanes/PreferencePanes.h>
#import <CoreFoundation/CoreFoundation.h>

@interface WLoggerPreferencesPref : NSPreferencePane {
    IBOutlet id debug;
	NSMutableDictionary *settings;
	IBOutlet id spinner;
	NSArray *updateValues;
	NSString *selectedUpdateInterval;

	CFStringRef appID;
	NSDistantObject *proxy;
}

- (IBAction)debugClicked:(id)sender;
- (IBAction)validateClicked:(id)sender;
- (void) setUpdateInterval:(NSString *)updateInterval;
- (NSString*) updateInterval;

@end
