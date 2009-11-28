#!/bin/sh

/bin/launchctl load -w /Library/LaunchDaemons/se.ejeklint.WLoggerDaemon.plist
/bin/launchctl start se.ejeklint.WLoggerDaemon
exit 0
