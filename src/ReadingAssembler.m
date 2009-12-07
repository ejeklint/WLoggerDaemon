//
//  ReadingAssembler.m
//  USBWeatherStationReader
//
//  Created by Per Ejeklint on 2009-04-28.
//  Copyright 2009 Heimore Group AB. All rights reserved.
//

#import "ReadingAssembler.h"
#import "AppDelegate.h"
#import "DataKeys.h"
#import "RemoteProtocol.h"
#import <math.h>
//#import <Growl/GrowlApplicationBridge.h>


NSString *FORECAST_STRING[] = {@"partly cloudy",@"rainy",@"cloudy",@"sunny",@"snowy", @"unknown"};	


@implementation ReadingAssembler

@synthesize interval, useComputersClock;

static int minuteCycleDone;

- (id)init {
	if (!(self = [super init]))
		return nil;

	// Default values, updated when settings are read
	interval = 1;
	useComputersClock = YES;
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	
	[nc addObserver:self
		   selector:@selector(dataEventListener:)
			   name:@"DataEvent" object:nil];
	
	return self;
}


- (void)dealloc {
	[super dealloc];
}


- (void) setUpdateInterval:(unsigned)i {
	interval = i;
}


- (void) checkBatteryReading: (uint8) reading andPostNotificationIfLowForUnit:(NSString*) unit {
	int level = (reading & 0x40) ? 1 : 2; // 1 for low battery, 2 for full
	
	NSMutableDictionary *report = [NSMutableDictionary dictionaryWithCapacity:1];
	[report setObject:[NSNumber numberWithInt:level] forKey:unit];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"StatusReport" object:self userInfo:report];

	/*	if (reading & 0x40) {
	 
	 // Post a Growl warning once a day
		NSDate *dateForPreviousWarning = [[NSUserDefaults standardUserDefaults] objectForKey:@"LatestBatteryWarningDate"];
		
		if (dateForPreviousWarning == nil || [[NSDate date] timeIntervalSinceDate:dateForPreviousWarning] > 86400) {
			[GrowlApplicationBridge
			 notifyWithTitle:@"Battery warning"
			 description:[NSString stringWithFormat:@"Battery is low in %@. Change batteries now to avoid data loss.", unit]
			 notificationName:@"Battery warning"
			 iconData:nil
			 priority:1
			 isSticky:NO
			 clickContext:nil];
			[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"LatestBatteryWarningDate"];
		}
	} */
}

- (double) roundedDoubleFromHighByte:(UInt8)high lowByte:(UInt8)low conversionFactor:(double)factor {
	double result = (high * 256 + low) * factor;
	result = round(result * 10.0) / 10.0;
	return result;
}

- (void) sendReadings: (NSDictionary*) readings ofType: (NSString*) type {
	NSMutableDictionary *report = [NSMutableDictionary dictionaryWithCapacity:2];
	[report setObject:type forKey:KEY_READING_TYPE];
	[report setObject:readings forKey:KEY_READINGS];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"Reading" object:self userInfo:report];
}


- (void)dataEventListener:(NSNotification *)notification {
	
	NSDictionary *userInfo = [notification userInfo];
	NSMutableData *data = [userInfo valueForKey:@"data"];
	
//	if (DEBUGALOT)
//		NSLog(@"Reading received: %@", data);
	
	UInt8* rb = (UInt8*) [data bytes];
	
	switch (rb[1]) {
			//
			// Rain report
			//
		case 0x41: {
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:4];

			// Comes in inches... * 0.254 makes mm.
			double totalRain = [self roundedDoubleFromHighByte:rb[9] lowByte:rb[8] conversionFactor:0.254];
			[userInfo setObject:[NSNumber numberWithDouble:totalRain] forKey:KEY_RAIN_TOTAL];
			
			double rainRate = [self roundedDoubleFromHighByte:rb[3] lowByte:rb[2] conversionFactor:0.254];				
			[userInfo setObject:[NSNumber numberWithDouble:rainRate] forKey:KEY_RAIN_RATE];				
			
			double rain1hour = [self roundedDoubleFromHighByte:rb[5] lowByte:rb[4] conversionFactor:0.254];
			[userInfo setObject:[NSNumber numberWithDouble:rain1hour] forKey:KEY_RAIN_1H];				
			
			double rain24hour = [self roundedDoubleFromHighByte:rb[7] lowByte:rb[6] conversionFactor:0.254];
			[userInfo setObject:[NSNumber numberWithDouble:rain24hour] forKey:KEY_RAIN_24H];				
						
			[self sendReadings:userInfo ofType:KEY_RAIN_READING];
			
			if (DEBUGALOT)
				NSLog(@"Rain report: %@", userInfo);
				
			[self checkBatteryReading:rb[0]	andPostNotificationIfLowForUnit:KEY_LEVEL_RAIN];
			
			NSTimeZone *zone = [NSTimeZone systemTimeZone];
			NSCalendarDate *rainTotalSince = [NSCalendarDate dateWithYear:rb[14] + 2000 month:rb[13] day:rb[12] hour:rb[11] minute:rb[10] second:0 timeZone:zone];
			
			NSMutableDictionary *report = [NSMutableDictionary dictionaryWithCapacity:1];
			[report setObject:rainTotalSince forKey:KEY_RAIN_TOTAL_RESET_TIME];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"StatusReport" object:self userInfo:report];

			if (DEBUGALOT)
				NSLog(@"Rain reset date report: %@", report);
			
			break;
		}
			//
			// Temperature & humidity report
			//
		case 0x42: {
			UInt8 sensor = rb[2] & 0x0f;

			[self checkBatteryReading:rb[0]	andPostNotificationIfLowForUnit:[NSString stringWithFormat:@"%@%d", KEY_LEVEL_SENSOR_, sensor] ];

			double temp = [self roundedDoubleFromHighByte:(rb[4] & 0x0f) lowByte:rb[3] conversionFactor:0.1];
			if (rb[4] & 0x80)
				temp *= -1.0;
			
			unsigned uncalibratedHumidity = rb[5];
			unsigned humidity = uncalibratedHumidity;
			double reportedDewPoint = [self roundedDoubleFromHighByte:(rb[7] & 0x0f) lowByte:rb[6] conversionFactor:0.1];
			if (rb[7] & 0x80)
				reportedDewPoint *= -1.0;
			
			if (uncalibratedHumidity > 80.0)
			{
				double RHmax = 100.0;
				double calibratedHumidity = 20.0 * ((uncalibratedHumidity - 80.0) / (RHmax - 80.0)) + 80.0;
				calibratedHumidity = round(calibratedHumidity);
				humidity = (unsigned) (calibratedHumidity < 100.0 ? calibratedHumidity : 100.0);
			}
			
			// Calculate own dewpoint since inbuilt seems to be whole degress only
			double h = (log10(humidity)-2) / 0.4343 + (17.62 * temp) / (243.12 + temp);
			double dewPoint = 243.12 * h / (17.62 - h);
			dewPoint = round(dewPoint * 10) / 10.0; // Round to 1 decimal
			
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:3];

			// Senson 1 might report Heat Index. This seems to differ between WMR100N and WMRS200. WMRS200: rb[7] == 1 indicates Heat Index present
			if (rb[8] > 0 /*rb[7] & 0x01*/) {
				// TODO: Check if this is true! For WMRS200, heat index is in "Celius"
				double heatIndex;
				if (1 /* It's WMRS200 */) {
					heatIndex = [self roundedDoubleFromHighByte:(rb[7] & 0x0f) lowByte:rb[8] conversionFactor:0.1]; // WMRS200 uses Celsius
				} else {
					heatIndex = ([self roundedDoubleFromHighByte:(rb[9] & 0x0f) lowByte:rb[8] conversionFactor:0.1] - 32) / 1.8; // WMR100 uses Fahrenheit
					heatIndex = round(heatIndex * 10.0) / 10.0;
				}
				[userInfo setObject:[NSNumber numberWithDouble:heatIndex] forKey:KEY_HEAT_INDEX];
			}

			if (sensor == 0) {
				[userInfo setObject:[NSNumber numberWithDouble:temp] forKey:KEY_TEMP_INDOOR];				
				[userInfo setObject:[NSNumber numberWithUnsignedInt:humidity] forKey:KEY_HUMIDITY_INDOOR];			
			} else if (sensor == 1) {
				[userInfo setObject:[NSNumber numberWithDouble:temp] forKey:KEY_TEMP_OUTDOOR];				
				[userInfo setObject:[NSNumber numberWithUnsignedInt:humidity] forKey:KEY_HUMIDITY_OUTDOOR];
				[userInfo setObject:[NSNumber numberWithDouble:dewPoint] forKey:KEY_TEMP_DEWPOINT_CALCULATED];		
//				[userInfo setObject:[NSNumber numberWithDouble:reportedDewPoint] forKey:KEY_TEMP_DEWPOINT_REPORTED];
			} else if (sensor >= 2) {
				NSString *keyForTemp = [NSString stringWithFormat:@"%@%d", KEY_TEMP_SENSOR_X, sensor];
				NSString *keyForHumidity = [NSString stringWithFormat:@"%@%d", KEY_HUMIDITY_SENSOR_X, sensor];
				[userInfo setObject:[NSNumber numberWithDouble:temp] forKey:keyForTemp];				
				[userInfo setObject:[NSNumber numberWithUnsignedInt:humidity] forKey:keyForHumidity];				
			}

			NSString *key = [NSString stringWithFormat:@"%@%d", KEY_TEMP_AND_HUM_READING_SENSOR_, sensor];

			[self sendReadings:userInfo ofType:key];

			if (DEBUGALOT)
				NSLog(@"Temp/humidity report: %@", userInfo);				
			
			break;
		}
			//
			// Barometer report
			//
		case 0x46: {
			unsigned relativePressure = (rb[4] + (rb[5] & 0x0f) * 256);
			unsigned absolutePressure = (rb[2] + (rb[3] & 0x0f) * 256);
			unsigned absolutePressureForecast = (rb[3] >> 4);
			unsigned relativePressureForecast = (rb[5] >> 4);
			
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:1];
			[userInfo setObject:[NSNumber numberWithUnsignedInt:absolutePressure] forKey:KEY_BAROMETER_ABSOLUTE];				
			[userInfo setObject:[NSNumber numberWithUnsignedInt:relativePressure] forKey:KEY_BAROMETER_RELATIVE];				
			[userInfo setObject:[NSNumber numberWithUnsignedInt:absolutePressureForecast] forKey:KEY_BAROMETER_ABSOLUTE_FORECAST];
			[userInfo setObject:[NSNumber numberWithUnsignedInt:relativePressureForecast] forKey:KEY_BAROMETER_RELATIVE_FORECAST]; // Does this ever change?
			[userInfo setObject:FORECAST_STRING[(absolutePressureForecast > 5) ? 5 : absolutePressureForecast] forKey:KEY_BAROMETER_ABSOLUTE_FORECAST_STRING]; // Code is 1-5, subtract 1

			[self sendReadings:userInfo ofType:KEY_BAROMETER_READING];
			
			if (DEBUGALOT)
				NSLog(@"Pressure report: %@", userInfo);				
			
			break;
		}
			//
			// UV report
			//
		case 0x47: {
			unsigned uvIndex = rb[3];

			[self checkBatteryReading:rb[0] andPostNotificationIfLowForUnit:KEY_LEVEL_UV];

			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:uvIndex] forKey:KEY_UV_INDEX];
			[self sendReadings:userInfo ofType:KEY_UV_READING];

			if (DEBUGALOT)
				NSLog(@"UV report: %@", userInfo);				
			
			break;
		}
			//
			// Anemometer report
			//
		case 0x48: {
			[self checkBatteryReading:rb[0] andPostNotificationIfLowForUnit:KEY_LEVEL_WIND];

			double windGust = [self roundedDoubleFromHighByte:(rb[5] & 0x0f) lowByte:rb[4] conversionFactor:0.1];
			
			double windAverage = (((double)rb[6]*16 + (rb[5] >> 4)) / 10);
			windAverage = round(windAverage * 10) / 10.0;
			
			int windDirection = ((int)(rb[2] & 0x0f)) ; // * 360 / 16;
			
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:3];
			[userInfo setObject:[NSNumber numberWithDouble:windGust] forKey:KEY_WIND_GUST];
			[userInfo setObject:[NSNumber numberWithDouble:windAverage] forKey:KEY_WIND_AVERAGE];
			[userInfo setObject:[NSNumber numberWithDouble:windDirection * 360 / 16] forKey:KEY_WIND_DIRECTION];

			if (rb[8] != 0x20) {
				double windChill = ([self roundedDoubleFromHighByte:(rb[8] & 0x0f) lowByte:rb[7] conversionFactor:0.1] - 32) / 1.8;
				windChill = round(windChill * 10.0) / 10.0;
				[userInfo setObject:[NSNumber numberWithDouble:windChill] forKey:KEY_WIND_CHILL];
			}
			
			[self sendReadings:userInfo ofType:KEY_WIND_READING];
			
			if (DEBUGALOT)
				NSLog(@"Wind report: %@", userInfo);
				
			break;
		}
			//
			// Clock and radio report
			//
		case 0x60: {
			// This is sent once a minute. Used to wrap upp a once-every-two minutes report.
			// We need to register twice to be certain all essential data is got.
			if (minuteCycleDone < 2) {
				minuteCycleDone++;
				break;
			}

			NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
			[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];

			// Get the time from the base station
			short int GMTZone = rb[9];
			if (GMTZone > 128)
				GMTZone = (128 - GMTZone);
			
			NSTimeZone *zone = [NSTimeZone timeZoneForSecondsFromGMT:GMTZone * 3600];
			NSDateComponents *comps = [[NSDateComponents alloc] init];
			[comps setYear:rb[8] + 2000];
			[comps setMonth:rb[7]];
			[comps setDay:rb[6]];
			[comps setHour:rb[5]];
			[comps setMinute:rb[4]];
			[comps setSecond:0];
			
			NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
			NSDate *baseStationTime = [gregorian dateFromComponents:comps];
			
			NSDate *time;
			NSInteger minute;
			if (useComputersClock == YES) {
				time = [NSDate date];
				NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
				NSDateComponents *minuteComponents = [gregorian components:(NSMinuteCalendarUnit) fromDate:time];
				minute = [minuteComponents minute];
			} else {
				time = baseStationTime;
				minute = [comps minute];
			}
			
			if (minute % interval) {
				break;
			}
			
			BOOL noPower = rb[0] & 0x80;
			BOOL syncedWithRF = rb[0] & 0x20;
			BOOL strongRFSignal = rb[0] & 0x10;
			
			NSMutableDictionary *report = [NSMutableDictionary dictionaryWithCapacity:3];
			[report setObject:[NSNumber numberWithBool:noPower] forKey:KEY_POWER_BASE];
			[report setObject:[NSNumber numberWithBool:syncedWithRF] forKey:KEY_RADIO_CLOCK_SYNC];
			[report setObject:[NSNumber numberWithBool:strongRFSignal] forKey:KEY_RADIO_CLOCK_LEVEL];
			[report setObject:[dateFormatter stringFromDate:baseStationTime] forKey:KEY_BASE_STATION_TIME];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"StatusReport" object:self userInfo:report];
			
			if (DEBUGALOT)
				NSLog(@"Base station status report: %@", report);
			
			if (noPower) {
				// Not good! Alert user once every hour
				// Not much meaning if computer also lost power, but some people do have UPS
				NSDate *dateForPreviousWarning = [[NSUserDefaults standardUserDefaults] objectForKey:@"LatestNoPowerWarningDate"];
/*				
				if (dateForPreviousWarning == nil || [[NSDate date] timeIntervalSinceDate:dateForPreviousWarning] > 3600) {
					NSLog(@"Main unit without external power");
					[GrowlApplicationBridge
					 notifyWithTitle:@"Power loss"
					 description:@"Base unit without external power. Will continue to operate on batteries until power is restored."
					 notificationName:@"Power loss"
					 iconData:nil
					 priority:2
					 isSticky:NO
					 clickContext:nil];
					[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"LatestNoPowerWarningDate"];
				} */
			}
			
			// TODO: Check if this is useful or if it comes from temp sensor 0
			[self checkBatteryReading:rb[0] andPostNotificationIfLowForUnit:KEY_LEVEL_BASE];
												
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:2];
			[userInfo setObject: [dateFormatter stringFromDate:time] forKey:KEY_COUCH_ID];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"MinuteReport" object:self userInfo:userInfo];

			if (DEBUGALOT)
				NSLog(@"Minute report: %@", userInfo);				
				
			break;
		}
	}
}
	

@end
