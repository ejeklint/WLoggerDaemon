/* AppDelegate */

#import <Cocoa/Cocoa.h>

#import "WMR100NDeviceController.h"
#import "ReadingAssembler.h"
#import "CouchObjC.h"
#import "MGTwitterEngine.h"
#import <WebKit/WebKit.h>
#include <sys/time.h>


@interface AppDelegate : NSObject
{
	NSUserDefaultsController *defaults;
	NSTimer *myTickTimer;
	
	NSConnection *serverConnection;
	
	// My worker objects
	WMR100NDeviceController *wmr100n;
	ReadingAssembler *ra;
	
	MGTwitterEngine *twitterEngine;
    SBCouchServer *couch;
    SBCouchDatabase *db;
	NSMutableDictionary *weatherReport;
	NSMutableDictionary *levels;
}

+ (BOOL) debugPrint;
- (NSDictionary *) getSettings;
- (BOOL) saveSettings: (NSDictionary *) dict;
- (void) setupConnection;
- (void) setupNotificationSubscription;
- (BOOL) setupTwitter: (NSDictionary*) settings;
- (BOOL) setupCouchDB: (NSDictionary*) settings;


@end
