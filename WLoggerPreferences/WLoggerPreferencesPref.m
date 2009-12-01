//
//  WLoggerPreferencesPref.m
//
//  Created by Per Ejeklint on 2009-11-16.
//  Copyright 2009 Heimore Group AB. All rights reserved.
//

#import "WLoggerPreferencesPref.h"
#import "RemoteProtocol.h"
#import "KeyChainHandler.h"

@implementation WLoggerPreferencesPref


- (id) initWithBundle:(NSBundle *)bundle {
	if ((self = [super initWithBundle:bundle]) != nil) {		
		// Set connection to daemon and get its settings
		connection = [NSConnection connectionWithRegisteredName:@"se.ejeklint.WLoggerDaemonConnection" host:nil];
		[connection setRequestTimeout:1.0];
		proxy = [[connection rootProxy] retain];
		[proxy setProtocolForProxy:@protocol(RemoteProtocol)];
		settings = [NSMutableDictionary dictionaryWithDictionary: [proxy getSettings]];
	}
	return self;
}


- (void) didSelect {
	if (!proxy || !settings) {
		// No connection to daemon, inform user
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:@"No connection"];
		[alert setInformativeText:@"Make sure that the WLoggerDaemon is installed and running."];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert beginSheetModalForWindow:[[NSApplication sharedApplication] keyWindow] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
	[spinner setDisplayedWhenStopped:NO];
	
//	[debugLogging setEnabled:[[settings objectForKey:"@useDebugLogging"] boolValue]];
	
	NSDictionary *levels = [proxy getLevels];
	if (levels) {
		NSNumber *l = [levels objectForKey:KEY_LEVEL_RAIN];
		if (l) {
			[rainBatteryIndicator setIntValue:[l integerValue]];
			[rainLabel setTextColor:[NSColor blackColor]];
		} else {
			[rainBatteryIndicator setIntValue:0];
			[rainLabel setTextColor:[NSColor grayColor]];
		}
		
		l = [levels objectForKey:KEY_LEVEL_WIND];
		if (l) {
			[windBatteryIndicator setIntValue:[l integerValue]];
			[windLabel setTextColor:[NSColor blackColor]];
		} else {
			[windBatteryIndicator setIntValue:0];
			[windLabel setTextColor:[NSColor grayColor]];
		}
		
		l = [levels objectForKey:[NSString stringWithFormat:@"%@1", KEY_LEVEL_SENSOR_]];
		if (l) {
			[outdoorTempBatteryIndicator setIntValue:[l integerValue]];
			[outdoorLabel setTextColor:[NSColor blackColor]];
		} else {
			[outdoorTempBatteryIndicator setIntValue:0];
			[outdoorLabel setTextColor:[NSColor grayColor]];
		}
		
		l = [levels objectForKey:[NSString stringWithFormat:@"%@0", KEY_LEVEL_SENSOR_]];
		if (l) {
			[indoorTempBatteryIndicator setIntValue:[l integerValue]];
			[indoorLabel setTextColor:[NSColor blackColor]];
		} else {
			[indoorTempBatteryIndicator setIntValue:0];
			[indoorLabel setTextColor:[NSColor grayColor]];
		}
		
		l = [levels objectForKey:KEY_LEVEL_UV];
		if (l) {
			[uvBatteryIndicator setIntValue:[l integerValue]];
			[uvLabel setTextColor:[NSColor blackColor]];
		} else {
			[uvBatteryIndicator setIntValue:0];
			[uvLabel setTextColor:[NSColor grayColor]];
		}
		
		l = [levels objectForKey:KEY_RADIO_CLOCK_SYNC];
		if (l) {
			[clockSynkIndicator setIntValue:[l integerValue]];
			[clockSynkLabel setTextColor:[NSColor blackColor]];
		} else {
			[clockSynkIndicator setIntValue:0];
			[clockSynkLabel setTextColor:[NSColor grayColor]];
		}
		l = [levels objectForKey:KEY_POWER_BASE];
		if (l) {
			[basePowerIndicator setState:([l boolValue] ? NSOnState : NSOffState)];
			[basePowerLabel setTextColor:[NSColor grayColor]];
		} else {
			[basePowerIndicator setState:NSOffState];
			[basePowerIndicator setEnabled:NO];
			[basePowerLabel setTextColor:[NSColor grayColor]];
		}
	}
}

- (void) alertDidEnd: (NSAlert*) alert returnCode: (NSInteger) returnCode contextInfo: (void*) contextInfo {
	//
}


- (IBAction)debugClicked:(id)sender {
	// Immediatey change log settings
    [proxy setDebug:[NSNumber numberWithBool:[sender state]]];
	// Also save settings
	[settings setObject:[NSNumber numberWithBool:[sender state]] forKey:@"useDebugLogging"];
}


- (void) doValidate: (NSTimer*) timer {
	[spinner startAnimation:self];
    if ([proxy setupCouchDB:settings] == NO) {
		// Bad values
	} else {
		// OK
	}
	[spinner stopAnimation:self];
}
					  
- (IBAction)validateClicked:(id)sender {
	// Smart hack to make  latest First Responer text field save it's values in case user didn't tab out from it
	[[sender window] makeFirstResponder:nil];
	// Must let go for a while to let updates from gui pour in
	[self performSelector:@selector(doValidate:) withObject:self afterDelay:0.1];
}


- (void) willUnselect {
	// Save settings before pane closes
	[proxy saveSettings:settings];
}

/*
- (NSString *) twitterPassword {
	return @"dummy";
}


- (void) setTwitterPassword: (NSString *) password {
	NSString *username = [settings objectForKey:@"twitterUser"];
	EMGenericKeychainItem *keychainItem = [KeyChainHandler getTwitterKeychainItemForUser:username]; 
	
	if (!keychainItem) {
		// Add to keychain
		[[EMKeychainProxy sharedProxy]
		 addGenericKeychainItemForService:@"WLoggerTwitter"
		 withUsername:username password:password];
	} else {
		// Update
		[keychainItem setPassword:password];
	}
}


- (NSString *) couchDBPassword {
	return @"dummy";
}


- (void) setCouchDBPassword: (NSString *) password {
	NSString *username = [settings objectForKey:@"couchDBUser"];
	EMGenericKeychainItem *keychainItem = [KeyChainHandler getCouchDBKeychainItemForUser:username];
	if (!keychainItem) {
		// Add to keychain
		[[EMKeychainProxy sharedProxy]
		 addGenericKeychainItemForService:@"WLoggerCouchDB"
		 withUsername:username password:password];
	} else {
		// Update
		[keychainItem setPassword:password];
	}
}
*/

@end
