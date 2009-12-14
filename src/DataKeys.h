/*
 *  DataKeys.h
 *  USBWeatherStationReader
 *
 *  Created by Per Ejeklint on 2009-06-14.
 *  Copyright 2009 Heimore Group AB. All rights reserved.
 *
 */


#define DEBUGALOT [AppDelegate debugPrint]

#define APP_ID CFSTR("se.ejeklint.WLoggerDaemon")


#define KEY_COUCH_ID			@"_id"

#define KEY_DOC_DOCTYPE			@"doctype"
#define KEY_DOC_READINGS		@"readings"
#define KEY_DOC_STATUS			@"device_status"

#define KEY_TIMESTAMP			@"timestamp"
#define KEY_READINGS			@"readings"

#define KEY_READING_TYPE		@"reading_type"
#define KEY_TEMP_AND_HUM_READING_SENSOR_		@"temp_reading"
#define KEY_BAROMETER_READING	@"barometer_reading"
#define KEY_WIND_READING		@"wind_reading"
#define KEY_RAIN_READING		@"rain_reading"
#define KEY_UV_READING			@"uv_reading"
#define KEY_TIME_READING		@"time_reading"

#define KEY_TEMP_OUTDOOR		@"t_out"
#define KEY_TEMP_INDOOR			@"t_in"
#define KEY_TEMP_DEWPOINT_CALCULATED		@"t_dew"
#define KEY_TEMP_DEWPOINT_REPORTED		@"t_dew_reported"
#define KEY_HUMIDITY_OUTDOOR	@"h_out"
#define KEY_HUMIDITY_INDOOR		@"h_in"
#define KEY_HEAT_INDEX			@"heat_idx"

#define KEY_BAROMETER_ABSOLUTE	@"p_abs"
#define KEY_BAROMETER_RELATIVE	@"p_rel"
#define KEY_BAROMETER_ABSOLUTE_FORECAST	@"p_abs_fc"
#define KEY_BAROMETER_RELATIVE_FORECAST	@"p_rel_fc"
#define KEY_BAROMETER_ABSOLUTE_FORECAST_STRING	@"fc_str"

#define KEY_TEMP_SENSOR_X		@"t_s"
#define KEY_HUMIDITY_SENSOR_X	@"h_s"
#define KEY_HEAT_INDEX_SENSOR_X	@"heat_idx_s"

#define KEY_WIND_AVERAGE		@"w_av"
#define KEY_WIND_DIRECTION		@"w_dir"
#define KEY_WIND_GUST			@"w_gust"
#define KEY_WIND_SPEED			@"w_speed"
#define KEY_WIND_CHILL			@"w_chill"

#define KEY_RAIN_RATE			@"r_rate"
#define KEY_RAIN_24H			@"r_24h"
#define KEY_RAIN_1H				@"r_1h"
#define KEY_RAIN_TOTAL			@"r_tot"
#define KEY_RAIN_TOTAL_SINCE_RESET	@"r_tot_since"

#define KEY_UV_INDEX			@"uv_idx"

