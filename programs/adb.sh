if [[ $- == *i* ]]; then
    alias adb_ip="adb shell netcfg && adb shell ifconfig wlan0"
    alias adb_screencp="adb shell /system/bin/screencap -p /sdcard/screenshot.png && adb pull /sdcard/screenshot.png screenshot.png"
    alias adb_start="adb shell am start -a android.intent.action.MAIN -n"
    alias adb_top="adb shell am stop -a android.intent.action.MAIN -n"
    alias adb_lists="adb shell pm list packages -s"
    alias adb_kill="adb shell am kill"
    alias adb_install="adb shell pm install -k --user 0 "
    alias adb_uninstall="adb shell pm uninstall -k --user 0 "
fi
