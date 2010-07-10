//
//  WMR100NDeviceController.m
//  USBWeatherStationReader
//
//  Created by Per Ejeklint on 2009-05-13.
//  Copyright 2009 Heimore Group AB. All rights reserved.
//  
//  Code for proper USB report handling by George Warner, Apple
//

#import "WMR100NDeviceController.h"
#import "AppDelegate.h"
#import "DataKeys.h"




static Boolean IOHIDDevice_GetLongProperty(IOHIDDeviceRef inIOHIDDeviceRef, CFStringRef inKey, long *outValue) {
	Boolean result = FALSE;
	if ( inIOHIDDeviceRef ) {
		assert( IOHIDDeviceGetTypeID() == CFGetTypeID(inIOHIDDeviceRef) );
		
		CFTypeRef tCFTypeRef = IOHIDDeviceGetProperty(inIOHIDDeviceRef, inKey);
		if ( tCFTypeRef ) {
			// if this is a number
			if ( CFNumberGetTypeID() == CFGetTypeID(tCFTypeRef) ) {
				// get it's value
				result = CFNumberGetValue( (CFNumberRef) tCFTypeRef, kCFNumberSInt32Type, outValue );
			}
		}
	}
	
	return (result);
}


//
// Static callbacks from HID Manager
//

static void Handle_DeviceRemovalCallback(void * inContext, IOReturn inResult, void * inSender, IOHIDDeviceRef inIOHIDDeviceRef)
{
	if (inResult != kIOReturnSuccess) {
		fprintf(stderr, "%s( context: %p, result: %p, sender: %p ).\n", 
				__PRETTY_FUNCTION__, inContext, ( void * ) inResult, inSender);
		return;
	}
	WMR100NDeviceController *self = (WMR100NDeviceController *) inContext;
	[self closeAndReleaseDevice: inIOHIDDeviceRef];
}	


static void Handle_DeviceMatchingCallback(void *         inContext,             // context from IOHIDManagerRegisterDeviceMatchingCallback
                                          IOReturn       inResult,              // the result of the matching operation
                                          void *         inSender,              // the IOHIDManagerRef for the new device
                                          IOHIDDeviceRef inIOHIDDeviceRef) {    // the new HID device
	WMR100NDeviceController *controller = (WMR100NDeviceController *) inContext;
	[controller openAndInitDevice:inResult sender:inSender device:inIOHIDDeviceRef];
}


static void Handle_IOHIDDeviceInputReportCallback(void *          inContext,		// context from IOHIDDeviceRegisterInputReportCallback
                                                  IOReturn        inResult,         // completion result for the input report operation
                                                  void *          inSender,         // IOHIDDeviceRef of the device this report is from
                                                  IOHIDReportType inType,           // the report type
                                                  uint32_t        inReportID,       // the report ID
                                                  uint8_t *       inReport,         // pointer to the report data
                                                  CFIndex         inReportLength)   // the actual size of the input report
{
	WMR100NDeviceController *self = (WMR100NDeviceController *) inContext;
	[self inputReport:inResult sender:inSender type:inType reportID:inReportID report:inReport length:inReportLength];
} 


@implementation WMR100NDeviceController



- (BOOL) validateChecksum: (NSData*) reading  {
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


- (void) postReadingAndPrepareForNew: (NSData*) reading {
	if ([reading length] < 2) {
		return;
	}

	int expectedReadingLength = 0;
	uint8_t *bytes = (uint8_t*) [reading bytes];
	switch (bytes[1]) {
		case 0x41: // Rain has varying expected lengths
			expectedReadingLength = 17;
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
	if ([reading length] != expectedReadingLength || [self validateChecksum:reading] == NO) {
		if (DEBUGALOT)
			NSLog(@"Discarding reading with wrong length or wrong checksum: %@", reading);
		return;
	}
	
	// Toss the completed reading up in the nutritional chain
	NSData *theData = [NSData dataWithData:reading];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:theData forKey:@"data"];				
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DataEvent" object:self userInfo:userInfo];
}


-(void) inputReport:(IOReturn) inResult sender:(void *) inSender type:(IOHIDReportType) inType reportID:(uint32_t) inReportID
				   report:(uint8_t *) inReport length:(CFIndex) inReportLength {
	unsigned int noOfValidBytes = inReport[0]; // Get number of bytes that matters in this report
	
	[buffer appendBytes:&inReport[1] length:noOfValidBytes];
	
	// Find 0xffff - all before that is a reading
	int len = [buffer length];
	if (len > 1) {
		for (int i = 0; i < len - 1; i++) {
			uint8_t *bytes = (uint8_t*) [buffer bytes];
			if (bytes[i] == 0xff && bytes[i+1] == 0xff) {
				NSData *new = [NSData dataWithBytes:[buffer bytes] length:i];
				[self postReadingAndPrepareForNew: new];
				// Patch from kglueck. Thanks!
				if ((i + 2) < len) { // if data exists after the 0xFF 0xFF marker
					char *bufferData=[buffer mutableBytes];
					memmove(bufferData,(bufferData + i + 2),(len - i - 2));
				}
				[buffer setLength:(len - i - 2)];
				break;
			}
		}
	}
}


- (void) closeAndReleaseDevice: (IOHIDDeviceRef) hidDeviceRef {
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DeviceRemoved" object:self userInfo:nil];
}


-(void) openAndInitDevice:(IOReturn) inResult sender:(void *) inSender device:(IOHIDDeviceRef) inIOHIDDeviceRef {
	gHidDeviceRef= inIOHIDDeviceRef;
	long reportSize = 0;
	(void) IOHIDDevice_GetLongProperty(inIOHIDDeviceRef, CFSTR(kIOHIDMaxInputReportSizeKey), &reportSize);

	if (reportSize) {
		report = calloc(1, reportSize);
		if (report) {
			IOHIDDeviceRegisterInputReportCallback(inIOHIDDeviceRef,						// IOHIDDeviceRef for the HID device
												   report,									// pointer to the report data (uint8_t's)
												   reportSize,								// number of bytes in the report (CFIndex)
												   Handle_IOHIDDeviceInputReportCallback,	// the callback routine
												   self);									// context passed to callback

			uint8_t triggerReport[]     = {0x20, 0x00, 0x08, 0x01, 0x00, 0x00, 0x00, 0x00};
			CFIndex reportLength = sizeof(triggerReport);
			
			// synchronous
			IOReturn ioReturn = IOHIDDeviceSetReport(inIOHIDDeviceRef,                      // IOHIDDeviceRef for the HID device
													 kIOHIDReportTypeOutput,                // IOHIDReportType for the report
													 0,                                     // CFIndex for the report ID
													 triggerReport,                         // address of report buffer
													 reportLength);                         // length of the report
			if (kIOReturnSuccess != ioReturn)
				NSLog(@"%s, IOHIDDeviceSetReport error: %ld (0x%08lX)", __PRETTY_FUNCTION__, ioReturn, ioReturn);
		}
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DeviceAdded" object:self userInfo:nil];
}


- (void) setupHidManagerAndCallbacks {
	gHIDManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
	if (gHIDManager) {
		NSDictionary * matchDict = [NSDictionary dictionaryWithObjectsAndKeys:
		                               [NSNumber numberWithInt:0x0FDE], @kIOHIDVendorIDKey,
		                               [NSNumber numberWithInt:0xCA01], @kIOHIDProductIDKey,
		                               nil];
		
		IOHIDManagerSetDeviceMatching(gHIDManager, (CFDictionaryRef) matchDict);
		
		// Callbacks for device plugin/removal
		IOHIDManagerRegisterDeviceMatchingCallback(gHIDManager, Handle_DeviceMatchingCallback, self);
		IOHIDManagerRegisterDeviceRemovalCallback(gHIDManager, Handle_DeviceRemovalCallback, self);
		
		// Schedule with the run loop
		IOHIDManagerScheduleWithRunLoop(gHIDManager, CFRunLoopGetCurrent( ), kCFRunLoopDefaultMode);
		
		IOReturn ioRet = IOHIDManagerOpen(gHIDManager, kIOHIDOptionsTypeNone);
		if (ioRet != kIOReturnSuccess) {
			CFRelease(gHIDManager);
			gHIDManager = NULL;
			NSLog(@"Failed to open the HID Manager");
		}
	}
}


- (id)init {
	if (!(self = [super init]))
		return nil;

	buffer = [[NSMutableData alloc] initWithCapacity:20];

	[self setupHidManagerAndCallbacks];
	
	return self;
}


- (void)dealloc {
	if (gHIDManager) {
		CFRelease(gHIDManager); // Should release our manager
		gHIDManager = NULL;
	}

	[super dealloc];
}


@end
