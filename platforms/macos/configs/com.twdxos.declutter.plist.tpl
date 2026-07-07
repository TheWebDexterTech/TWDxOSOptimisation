<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.twdxos.declutter</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>__SCRIPT_PATH__</string>
        <string>--cron</string>
        __EXTRA_ARG_ELEMENT__
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>__WEEKDAY__</integer>
        <key>Hour</key>
        <integer>__HOUR__</integer>
        <key>Minute</key>
        <integer>__MINUTE__</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/twdxos-declutter.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/twdxos-declutter.err</string>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
