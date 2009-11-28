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
		appID = CFSTR("se.ejeklint.WLoggerDaemon");
		
		[debug setState:NO];

		// Set connection to daemon and get its settings
		proxy = [NSConnection rootProxyForConnectionWithRegisteredName:@"se.ejeklint.WLoggerDaemonConnection" host:nil];
		[proxy setProtocolForProxy:@protocol(RemoteProtocol)];
		settings = [proxy getSettings];
	}
	return self;
}
				 
- (void) mainViewDidLoad
{
}

- (void) didSelect {
	if (!proxy) {
		// No connection to daemon, inform user
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:@"No connection"];
		[alert setInformativeText:@"Make sure that the WLoggerDaemon is installed and running."];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert beginSheetModalForWindow:[[NSApplication sharedApplication] keyWindow] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
}

- (void) alertDidEnd: (NSAlert*) alert returnCode: (NSInteger) returnCode contextInfo: (void*) contextInfo {
	//
}


- (IBAction)debugClicked:(id)sender {
	// Immediatey change log settings
    [proxy setDebug:[NSNumber numberWithBool:[sender state]]];
}


- (void) doValidate: (NSTimer*) timer {
    if ([proxy setupCouchDB:settings] == NO) {
		// Bad values
	} else {
		// OK
	}
}
					  
- (IBAction)validateClicked:(id)sender {
	// Smart hack to make  latest First Responer text field save it's values in case user didn't tab out from it
	[[sender window] makeFirstResponder:nil];
	// Must let go for a while to let updates from gui pour in
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(doValidate:) userInfo:nil repeats:NO];		
}


- (void) didUnselect {
	[proxy saveSettings:settings];
}


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


@end
