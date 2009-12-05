//
//  WMR100NDeviceController.h
//  USBWeatherStationReader
//
//  Created by Per Ejeklint on 2009-05-13.
//  Copyright 2009 Heimore Group AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDManager.h>


@interface WMR100NDeviceController : NSObject {
	void *  report;
	IOHIDManagerRef gHIDManager;
	IOHIDDeviceRef gHidDeviceRef;
	NSMutableData *buffer;
}

- (void) openAndInitDevice:(IOReturn)inResult sender:(void *)inSender device:(IOHIDDeviceRef)inIOHIDDeviceRef;
- (void) closeAndReleaseDevice: (IOHIDDeviceRef) hidDeviceRef;
- (void) inputReport:(IOReturn)inResult sender:(void *)inSender type:(IOHIDReportType)inType reportID:(uint32_t)inReportID report:(uint8_t*)inReport length:(CFIndex)inReportLength;

@end
