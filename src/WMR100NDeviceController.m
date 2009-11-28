//
//  WMR100NDeviceController.m
//  USBWeatherStationReader
//
//  Created by Per Ejeklint on 2009-05-13.
//  Copyright 2009 Heimore Group AB. All rights reserved.
//

#import "WMR100NDeviceController.h"
#import "AppDelegate.h"
#import "DataKeys.h"

@implementation WMR100NDeviceController

// Need to hold some state between input reports
static BOOL shortSeparatorFound;

// While debugging
#ifdef DEBUG
int usbReportIndex;
NSData *previousReports[10];
#endif

//
// Our "private" methods and callbacks
//

- (BOOL) validateChecksum {
	unsigned sum = 0;
	int i = 0;
	UInt8 *data = (UInt8*) [reading bytes];
	unsigned last = [reading length] - 2;
	
	for (i = 0; i < last; i++)
		sum += data[i];
	
	if (sum != (data[[reading length]-1] * 256 + data[[reading length]-2])) {
		return NO;
	} else {
		return YES;
	}
}


- (void) postReadingAndPrepareForNew {
	// Check expected length and adjust if needed
	if ([reading length] < 5) {
		[reading setLength:0];
		return;
	}

	int expectedReadingLength = 0;
	uint8_t *bytes = (uint8_t*) [reading bytes];
	switch (bytes[1]) {
		case 0x41: // Rain has varying expected lengths
			switch ([reading length]) {
				case 10:
				case 11:
					expectedReadingLength = 11;
					break;
				case 12:
				case 13:
					expectedReadingLength = 13;
					break;
				case 14:
				case 15:
					expectedReadingLength = 15;
					break;
				case 16:
				case 17:
					expectedReadingLength = 17;
					break;
				default:
					expectedReadingLength = 17;
					break;
			}
			break;
		case 0x42: // Temp & humidity
			expectedReadingLength = 12;
			break;
		case 0x46: // Pressure
			expectedReadingLength = 8;
			break;
		case 0x47: // UV reader
			expectedReadingLength = 6;
			break;
		case 0x48: // Wind
			expectedReadingLength = 11;
			break;
		case 0x60: // Date and time
			expectedReadingLength = 12;
			break;
	}
	if ([reading length] != expectedReadingLength || [self validateChecksum] == NO) {
		if (DEBUGALOT)
			NSLog(@"Discarding reading with wrong length or wrong checksum: %@", reading);

		// Empty buffer
		[reading setLength:0];
		return;
	}
	
		// Toss the completed reading up in the nutritional chain
	NSData *theData = [NSData dataWithData:reading];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:theData forKey:@"data"];				
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DataEvent" object:self userInfo:userInfo];
	// Empty buffer
	[reading setLength:0];
}


- (void) handleReport:(IOHIDValueRef) inIOHIDValueRef {
	CFIndex length = IOHIDValueGetLength(inIOHIDValueRef); // Get report length
	if (length != WMR100N_REPORT_SIZE)
		return; // We only care about 8 byte reports
	
	const uint8_t *reportbuf = IOHIDValueGetBytePtr(inIOHIDValueRef); // Pointer to report
	
	unsigned int actualReportLength = reportbuf[0]; // Get number of bytes that matters in this report

	if (actualReportLength == 1 && reportbuf[1] == 0xff) {
		// Short frame separator (ff)
		shortSeparatorFound = YES;
		[self postReadingAndPrepareForNew];
	} else if (actualReportLength == 2 && reportbuf[1] == 0xff && reportbuf[2] == 0xff) {
		// Long frame separator (ffff)
		shortSeparatorFound = NO;
		[self postReadingAndPrepareForNew];
	} else if (shortSeparatorFound == YES && actualReportLength > 1 && reportbuf[1] == 0xff) {
		// Another long frame separator, but split in two reports. Keep rest.
		shortSeparatorFound = NO;
		[reading appendBytes:&reportbuf[2] length:actualReportLength - 1];	
	} else {
		shortSeparatorFound = NO;
		[reading appendBytes:&reportbuf[1] length:actualReportLength];
	}	
}


// Callback for input value changes from WMR100N
static void Handle_IOHIDInputValueCallback(void * inContext, IOReturn inResult, void * inSender, IOHIDValueRef inIOHIDValueRef) {
	if (inResult != kIOReturnSuccess) {
		fprintf(stderr, "%s( context: %p, result: %p, sender: %p ).\n", 
				__PRETTY_FUNCTION__, inContext, ( void * ) inResult, inSender);
		return;
	}
	WMR100NDeviceController* self = (WMR100NDeviceController*) inContext;
	[self handleReport: inIOHIDValueRef];
}


- (void) openAndSetupDevice: (IOHIDDeviceRef) hidDeviceRef {
	gHidDeviceRef = hidDeviceRef;
	IOReturn  ioReturnValue = IOHIDDeviceOpen(hidDeviceRef, kIOHIDOptionsTypeNone);
	if (ioReturnValue != kIOReturnSuccess) {
		NSLog(@"Failed to open communication to weather station");
		return;
	}
	
	// Send trigger string so it will start reporting. Only needed once after power failure, reset or boot of WMR100, but you never know, do you, and it doesn't make any harm to send at each device discovery
	unsigned char initString[] = { 0x20, 0x00, 0x08, 0x01, 0x00, 0x00, 0x00, 0x00 };
	ioReturnValue = IOHIDDeviceSetReport(hidDeviceRef, kIOHIDReportTypeOutput, 0, initString, 8);
	if (ioReturnValue != kIOReturnSuccess) {
		NSLog(@"Failed to send init string with setReport");
		return;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DeviceAdded" object:self userInfo:nil];
}


- (void) closeAndReleaseDevice: (IOHIDDeviceRef) hidDeviceRef {
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DeviceRemoved" object:self userInfo:nil];
}


//
// Static callbacks for device plugin and removal
//

static void Handle_DeviceMatchingCallback(void * inContext, IOReturn inResult, void * inSender, IOHIDDeviceRef inIOHIDDeviceRef)
{
	if (inResult != kIOReturnSuccess) {
		fprintf(stderr, "%s( context: %p, result: %p, sender: %p ).\n", 
				__PRETTY_FUNCTION__, inContext, ( void * ) inResult, inSender);
		return;
	}
	WMR100NDeviceController* self = (WMR100NDeviceController*) inContext;
	[self openAndSetupDevice: inIOHIDDeviceRef];
}	

static void Handle_DeviceRemovalCallback(void * inContext, IOReturn inResult, void * inSender, IOHIDDeviceRef inIOHIDDeviceRef)
{
	if (inResult != kIOReturnSuccess) {
		fprintf(stderr, "%s( context: %p, result: %p, sender: %p ).\n", 
				__PRETTY_FUNCTION__, inContext, ( void * ) inResult, inSender);
		return;
	}
	WMR100NDeviceController* self = (WMR100NDeviceController*) inContext;
	[self closeAndReleaseDevice: inIOHIDDeviceRef];
}	


- (IOHIDManagerRef) setupHidManagerAndCallbacks {
	SInt32 usbVendor = 4062;		// Oregon Scientific
	SInt32 usbProduct = 51713;		// WMR100 or WMRS200
	SInt32 usbUsagePage = 0xff00;	// Vendor page is our point of interest
	
	NSMutableDictionary *matchDict = [[NSMutableDictionary alloc] init];
	[matchDict setObject:[NSNumber numberWithInt:usbVendor] forKey:[NSString stringWithUTF8String:kIOHIDVendorIDKey]];
	[matchDict setObject:[NSNumber numberWithInt:usbProduct] forKey:[NSString stringWithUTF8String:kIOHIDProductIDKey]];
	[matchDict setObject:[NSNumber numberWithInt:usbUsagePage] forKey:[NSString stringWithUTF8String:kIOHIDPrimaryUsagePageKey]];
	
	IOHIDManagerRef aHIDManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
	if (!aHIDManager) {
		NSLog(@"Failed creating a HID Manager");
		return NULL;
	}
	
	IOHIDManagerSetDeviceMatching(aHIDManager, (CFDictionaryRef) matchDict);
	
	IOReturn ioRet = IOHIDManagerOpen(aHIDManager, kIOHIDOptionsTypeNone);
	if (ioRet != kIOReturnSuccess) {
		CFRelease(aHIDManager);
		NSLog(@"Failed to open the HID Manager");
		return NULL;
	}
	
	// Callbacks for device plugin/removal
	IOHIDManagerRegisterDeviceMatchingCallback(aHIDManager, Handle_DeviceMatchingCallback, self);
	IOHIDManagerRegisterDeviceRemovalCallback(aHIDManager, Handle_DeviceRemovalCallback, self);
	
	// Callback for input value reporting
	IOHIDManagerRegisterInputValueCallback(aHIDManager, Handle_IOHIDInputValueCallback, self);
	
	// Schedule with the run loop
	IOHIDManagerScheduleWithRunLoop(aHIDManager, CFRunLoopGetCurrent( ), kCFRunLoopDefaultMode);
	
	return aHIDManager;
}



//
// Our public methods
//

- (id)init {
	if (!(self = [super init]))
		return nil;

	reading = [[NSMutableData alloc] init];

	gHIDManager = [self setupHidManagerAndCallbacks];
	
	return self;
}

- (void)dealloc {
	CFRelease(gHIDManager); // Should release our manager
	[reading release];
	[super dealloc];
}


@end
