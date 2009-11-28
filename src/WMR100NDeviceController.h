//
//  WMR100NDeviceController.h
//  USBWeatherStationReader
//
//  Created by Per Ejeklint on 2009-05-13.
//  Copyright 2009 Heimore Group AB. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDManager.h>


#define WMR100N_REPORT_SIZE 8

@interface WMR100NDeviceController : NSObject {
	uint8_t report[WMR100N_REPORT_SIZE];
	IOHIDManagerRef gHIDManager;
	IOHIDDeviceRef gHidDeviceRef;
	NSMutableData *reading;
}

@end
