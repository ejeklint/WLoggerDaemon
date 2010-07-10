<br>
_PLEASE NOTE: this is preliminary, changes will surely be made. If you have information to contribute with, please contact me!_

[This thread](http://aguilmard.com/phpBB3/viewtopic.php?f=2&t=508&st=0&sk=t&sd=a&hilit=wmr100) on [a forum for GraphWeather](http://aguilmard.com/) was very helpful. I managed to read it all in spite of my lousy french. Thank's guys!

And big thanks to Kustaa Nyholm, George Warner and Fernando Urbina for your help!

There are a number of weather stations from Oregon Scientific that uses this protocol. I know that WMR100N, WMRS200, RMS300 and RMS600 share the same protocol and work with my software. All of them are low speed USB 1.1 Human Interface Devices, but with a completely closed, vendor-specific application level protocol. I've tried to contact Oregon Scientific about the possibility to get access to the protocol but they haven't even answered my letters.

The nice thing about them being a HID is that it makes it quite easy to communicate with it, and using the HID Manager that came with Mac OS X 10.5 enabled me to get a very simple and robust way of speaking with them. At first I wasn't using the proper callback function so occasionally I got data losses. But with excellent help from Fernano Urbina and George Warner at Apple I understood what was going on, and with George's example code I finally got it stable. Setting up the USB handling and register callbacks for data and device plugin/remove is not even 10 lines of code, excluding error control. But then to actually understand the data from the station requires much more of coding. 

###Initialization
<br>
To kick-start the station the following initialization string (hex code) must be sent once, at least for WMR100N:

    20 00 08 01 00 00 00 00

It is only needed after a reset (or power failure) of the station.

###Report layout
<br>
The station sends 8 bytes long _USB reports_. Of the 8-byte reports, only a few bytes are of interest, and to put together a complete weather measurement, data must be extracted from several 8 byte long USB reports.

A typical 8-byte report looks like this

    02 00 47 30 01 0c 01 00

The first byte tell us how many of the directly following bytes are part of a measurement. In the example above there are 2 bytes, so `00 47` is valid parts of a weather measurement. Keep on assembling USB reports like this and you will create a stream of bytes containing weather measurements. Most USB reports contain only one or two relevant bytes, but I have recently found occasional, rare reports with up to 7 bytes of real data, so make sure that you don't assume only one or two bytes.

All measurements are separated by `0xffff`. Earlier, I thought that there was a singe `0xff` between measurements, but that was wrong. I was lead to believe that by my USB handling bug that caused some data to go lost now and then.

Now, the **type** of a measurement (like rain or wind) is determined in the second byte of the measurement. And the last two bytes of a measurement is a checksum, it should be the same as the sum of all preceding bytes in the measurement. The checksum comes low byte first, then high byte.

***An example:***

If you have this byte sequence filtered out from the USB reports

    ... 05 ca 00 ff ff 00 47 08 4f 00 ff ff 00 42 ...

then you can find the 5 byte long measurement `00 47 08 4f 00` in it, where the second byte (`47`) indicates an UV Index measurement, third byte is the actual UV index measurement of 8 (wear sunscreen because this is very high!), and fourth and fifth byte is the checksum `004f` in reverse order. Add the first three and check for yourself. And in the first byte, the high [nibble](http://en.wikipedia.org/wiki/Nibble) contains information about the battery level in the UV device.

###Sensor readings
<br>
Following are description of the known data in the different measurements. The content of some bytes are unknown, and there might be misinterpretations as well. It's difficult to be 100% sure when the vendor has decided to be mum. But what I have written here gives readings that matches perfectly with what WMR100N says on its own screen, or what the PC software for WMRS200 reports.

####Date and time

This "measurement" is sent once a minute. Most other readings are sent within one minute but some, like the UV Index, is reported every 73 second, so if you want to be sure you have all data before reporting it or store in a db, wait at least two minute cycles.

<table>
	<tr><th>Length</th><th>12</th><th>Example: <code>00 60 00 00 14 09 1c 04 09 01 a7 00</code> </th></tr>
	<tr><th>Byte</th><th>Data</th><th>Comment</th></tr>
	<tr><td>0</td><td> <code>00</code> </td><td>Flags, see below</td></tr>
	<tr><td>1</td><td> <code>60</code> </td><td>Identifier</td></tr>
	<tr><td>2-3</td><td> <code>00 00</code> </td><td>Unknown</td></tr>
	<tr><td>4</td><td> <code>14</code> </td><td>Minutes: 20</td></tr>
	<tr><td>5</td><td> <code>09</code> </td><td>Hour: 09</td></tr>
	<tr><td>6</td><td> <code>1c</code> </td><td>Day: 28</td></tr>
	<tr><td>7</td><td> <code>04</code> </td><td>Month: 04, April</td></tr>
	<tr><td>8</td><td> <code>09</code> </td><td>Year: 2009 (add 2000)</td></tr>
	<tr><td>9</td><td> <code>01</code> </td><td>Time Zone: GMT +1 (highest bit 1 if negative)</td></tr>
	<tr><td>10-11</td><td> <code>a7 00</code> </td><td>Checksum: 0xa7</td></tr>
</table>
<br/>

<table>
	<tr><th>Flags in byte 0</th><th>Power and RF signal</th></tr>
	<tr><td>Bit 7 (MSB)</td><td>1: power unplugged, 0: power attached</td></tr>
	<tr><td>Bit 6</td><td>1: low battery level, 0: good battery level</td></tr>
	<tr><td>Bit 5</td><td>1: RF sync active, 0: RF sync inactive</td></tr>
	<tr><td>Bit 4</td><td>1: RF signal strong, 0: RF signal weak</td></tr>
	<tr><td>Bit 3</td><td>Unused</td></tr>
	<tr><td>Bit 2</td><td>Unused</td></tr>
	<tr><td>Bit 1</td><td>Unused</td></tr>
	<tr><td>Bit 0 (LSB)</td><td>Unused</td></tr>
</table>
	

####Temperature and humidity

This measurement is sent for each device connected. At least there's the outdoor device and the indoor device build into station itself, plus any extra sensors for temperature and humidity that you have added. Dew point is only reported from the outdoor unit and in whole degrees C only.

Heat index is reported if temperature climbs over 80 F, 26.7 C.

<table>
	<tr><th>Length</th><th>12</th><th>Example: <code>20 42 d1 91 00 48 64 00 00 20 90 02</code> </th></tr>
	<tr><th>Byte</th><th>Data</th><th>Comment</th></tr>
	<tr><td>0</td><td> <code>20</code> </td><td>Flags, see below</td></tr>
	<tr><td>1</td><td> <code>42</code> </td><td>Identifier</td></tr>
	<tr><td>2</td><td> <code>d1</code> </td><td>Low nibble is device channel number, high nibble: see below</td></tr>
	<tr><td>3-4</td><td> <code>91 00</code> </td><td>Temperature: (256 * byte 4 + byte 3) / 10 = 14,5 degrees</td></tr>
	<tr><td>5</td><td> <code>48</code> </td><td>Humidity: 72%</td></tr>
	<tr><td>6-7</td><td> <code>64 00</code> </td><td>Dew point: (256 * byte 7 + byte 6) / 10 = 10 degrees</td></tr>
	<tr><td>8-9</td><td> <code>00 20</code> </td><td>Heat index or wind chill, see below</td></tr>
	<tr><td>10-11</td><td> <code>90 02</code> </td><td>Checksum: 0x290</td></tr>
</table>
<br/>

<table>
	<tr><th>Flags in byte 0</th><th>Battery and temp trend</th></tr>
	<tr><td>Bit 7 (MSB)</td><td>Unused</td></tr>
	<tr><td>Bit 6</td><td>1: low battery level, 0: good battery level</td></tr>
	<tr><td>Bit 5</td><td>Unused</td></tr>
	<tr><td>Bit 4</td><td>Unused</td></tr>
	<tr><td>Bit 3</td><td>Unused</td></tr>
	<tr><td>Bit 2</td><td>Unused</td></tr>
	<tr><td>Bit 1-0 (LSB)</td><td>Temp trend. 0: stable, 1: rising, 2: falling</td></tr>
</table>
<br/>

<table>
	<tr><th>Flags in byte 2</th><th>Smileys and humidity trends</th></tr>
	<tr><td>Bit 7-6 (MSB)</td><td>Smiley. 0: no smiley, 1: :-), 2: :-(, 3: :-|</td></tr>
	<tr><td>Bit 5-4</td><td>Humidity trend. 0: stable, 1: rising, 2: falling</td></tr>
</table>
<br/>

<table>
	<tr><th>Byte 8-9</th><th>Heat Index</th></tr>
	<tr><td>Byte 9, high nibble</td><td>0: heat index, 1: ?, 2: None</td></tr>
	<tr><td>Byte 8 + 9</td><td>NB! Result in Fahrenheit: ((256*low nibble(byte 9) + byte 8) / 10</td></tr>
</table>

####Wind

Wind is measured in m/s, direction in degrees (0-360). Wind chill is only reported for lower degrees. 

_To do: figure out byte 3_

<table>
	<tr><th>Length</th><th>11</th><th>Example: <code>00 48 0a 0c 16 e0 02 00 20 76 01</code> </th></tr>
	<tr><th>Byte</th><th>Data</th><th>Comment</th></tr>
	<tr><td>0</td><td> <code>00</code> </td><td>Battery level in high nibble</td></tr>
	<tr><td>1</td><td> <code>48</code> </td><td>Identifier</td></tr>
	<tr><td>2</td><td> <code>0a</code> </td><td>Wind direction in low nibble, 10 * 360 / 16 = 225 degrees</td></tr>
	<tr><td>3</td><td> <code>0c</code> </td><td>Unknown</td></tr>
	<tr><td>4-5</td><td> <code>16 e0</code> </td><td>Wind gust, (low nibble of byte 5 * 256 + byte 4) / 10 </td></tr>
	<tr><td>5-6</td><td> <code>e0 02</code> </td><td>Wind average, (high nibble of byte 5 + byte 6 * 16) / 10 </td></tr>
	<tr><td>7</td><td> <code>00</code> </td><td>?</td></tr>
	<tr><td>8</td><td> <code>20</code> </td><td>?</td></tr>
	<tr><td>9-10</td><td> <code>76 01</code> </td><td>Checksum: 0x176</td></tr>
</table>
<br/>

<table>
	<tr><th>Byte 7-8</th><th>Wind Chill</th></tr>
	<tr><td>Byte 7, high nibble</td><td>0: ?, 1: windchill, 2: None</td></tr>
	<tr><td>Byte 7 + 8</td><td>NB! Result in Fahrenheit: ((256*low nibble(byte 8) + byte 7) / 10</td></tr>
</table>


####Pressure

Barometer reading is reported both as absolute and relative. Reading also includes a forecast indicator.

Forecast indicator is a number were 0 is Partly cloudy, 1 is Rainy, 2 is Cloudy, 3 is Sunny and 5 is Snowy.

_To do: verify all forecast indicators. Does 4 ever occur?_

<table>
	<tr><th>Length</th><th>8</th><th>Example: <code>00 46 ed 03 ed 33 56 02</code> </th></tr>
	<tr><th>Byte</th><th>Data</th><th>Comment</th></tr>
	<tr><td>0</td><td> <code>00</code> </td><td>Unused?</td></tr>
	<tr><td>1</td><td> <code>46</code> </td><td>Identifier</td></tr>
	<tr><td>2-3</td><td> <code>ed 03</code> </td><td>Absolute pressure, low nibble of byte 3 * 256 + byte 2</td></tr>
	<tr><td>3</td><td> <code>03</code> </td><td>High nibble is forecast indicator</td></tr>
	<tr><td>4-5</td><td> <code>ed 03</code> </td><td>Relative pressure, low nibble of byte 5 * 256 + byte 4</td></tr>
	<tr><td>5</td><td> <code>03</code> </td><td>High nibble unknown</td></tr>
	<tr><td>6-7</td><td> <code>56 02</code> </td><td>Checksum: 0x256</td></tr>
</table>


####Rain

Rain is reported in inches * 10, rain rate in inches/hour * 10. Divide by 10 to get proper values. Or, even better, multiply with 0.254 to get millimeters. :-)

<table>
	<tr><th>Length</th><th>17</th><th>Example: <code>00 41 ff 02 0c 00 00 00 25 00 00 0c 01 01 06 87 01</code> </th></tr>
	<tr><th>Byte</th><th>Data</th><th>Comment</th></tr>
	<tr><td>0</td><td> <code>00</code> </td><td>Battery level in high nibble</td></tr>
	<tr><td>1</td><td> <code>41</code> </td><td>Identifier</td></tr>
	<tr><td>2-3</td><td> <code>ff 02</code> </td><td>Rain rate: (byte 3 * 256 + byte 2) / 10, in inches/hour</td></tr>
	<tr><td>4-5</td><td> <code>0c 00</code> </td><td>Rain last hour: (byte 5 * 256 + byte 4) / 10, in inches</td></tr>
	<tr><td>6-7</td><td> <code>00 00</code> </td><td>Rain last 24 hours: (byte 7 * 256 + byte 6) / 10, in inches</td></tr>
	<tr><td>8-9</td><td> <code>00 25</code> </td><td>Total rain since reset date: (byte 9 * 256 + byte 8) / 10, in inches</td></tr>
	<tr><td>10</td><td> <code>00</code> </td><td>Minute of reset date</td></tr>
	<tr><td>11</td><td> <code>0c</code> </td><td>Hour of reset date</td></tr>
	<tr><td>12</td><td> <code>01</code> </td><td>Day of reset date</td></tr>
	<tr><td>13</td><td> <code>01</code> </td><td>Month of reset date</td></tr>
	<tr><td>14</td><td> <code>06</code> </td><td>Year + 2000 of reset date</td></tr>
	<tr><td>15-16</td><td> <code>87 01</code> </td><td>Checksum: 0x187</td></tr>
</table>


####UV Radiation

UV Index is reported from the UVN800 sensor. It's an dimensionless value (whole number) from 0 and upwards.

<table>
	<tr><th>Length</th><th>5</th><th>Example: <code>00 47 05 4c 00</code> </th></tr>
	<tr><th>Byte</th><th>Data</th><th>Comment</th></tr>
	<tr><td>0</td><td> <code>00</code> </td><td>Battery level in high nibble</td></tr>
	<tr><td>1</td><td> <code>47</code> </td><td>Identifier</td></tr>
	<tr><td>2</td><td> <code>05</code> </td><td>UV Index 5</td></tr>
	<tr><td>3-4</td><td> <code>4c 00</code> </td><td>Checksum: 0x4c</td></tr>
</table>