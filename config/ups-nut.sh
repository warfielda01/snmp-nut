#!/bin/sh
################################################################
# Instructions:                                                #
# 1. copy this script to /etc/snmp/ and make it executable:    #
#    chmod +x ups-nut.sh                                       #
# 2. make sure UPS_NAME below matches the name of your UPS     #
# 3. edit your snmpd.conf to include this line:                #
#    extend ups-nut /etc/snmp/ups-nut.sh                       #
# 4. restart snmpd on the host                                 #
################################################################

UPS_NAME="ups"

PATH=$PATH:/usr/bin:/bin
TMP=$(upsc $UPS_NAME 2>/dev/null)

for value in "battery\.capacity: [0-9.]+" "battery\.charge: [0-9]+" "battery\.charge\.low: [0-9]+" "battery\.charge\.restart: [0-9]+" "battery\.charger\.status: [a-zA-Z]+" "battery\.energysave: [a-zA-Z]+" "battery\.energysave\.delay: [0-9]+" "battery\.energysave\.load: [0-9]+" "battery\.protection: [a-zA-Z]+" "battery\.runtime: [0-9]+" "battery\.type: [a-zA-Z]+" "battery\.voltage: [0-9.]+" "battery\.voltage\.nominal: [0-9]+" "device\.mfr: [a-zA-Z0-9]+" "device\.model: [a-zA-Z0-9 ]+" "device\.serial: [a-zA-Z0-9]+" "device\.type: [a-zA-Z0-9]+" "driver\.name: [a-zA-Z0-9\-]+" "driver\.parameter\.pollfreq: [0-9]+" "driver\.parameter\.pollinterval: [0-9]+" "driver\.parameter\.port: [a-zA-Z0-9]+" "driver\.parameter\.synchronous: [a-zA-Z]+" "driver\.version: [a-zA-Z0-9. ]+" "driver\.version\.data: [a-zA-Z0-9. ]+" "driver\.version\.internal: [a-zA-Z0-9. ]+" "input\.current: [0-9.]+" "input\.frequency: [0-9.]+" "input\.frequency\.extended: [a-zA-Z]+" "input\.frequency\.nominal: [0-9.]+" "input\.sensitivity: [a-zA-Z]+" "input\.transfer\.boost\.low: [0-9]+" "input\.transfer\.high: [0-9]+" "input\.transfer\.low: [0-9]+" "input\.transfer\.trim\.high: [0-9]+" "input\.voltage: [0-9.]+" "input\.voltage\.extended: [a-zA-Z]+" "input\.voltage\.nominal: [0-9.]+" "outlet\.1\.autoswitch\.charge\.low: [0-9]+" "outlet\.1\.delay\.shutdown: [0-9]+" "outlet\.1\.delay\.start: [0-9]+" "outlet\.1\.desc: [a-zA-Z0-9 ]+" "outlet\.1\.id: [0-9]+" "outlet\.1\.status: [a-zA-Z]+" "outlet\.1\.switchable: [a-zA-Z]+" "outlet\.2\.autoswitch\.charge\.low: [0-9]+" "outlet\.2\.delay\.shutdown: [0-9]+" "outlet\.2\.delay\.start: [0-9]+" "outlet\.2\.desc: [a-zA-Z0-9 ]+" "outlet\.2\.id: [0-9]+" "outlet\.2\.status: [a-zA-Z]+" "outlet\.2\.switchable: [a-zA-Z]+" "outlet\.desc: [a-zA-Z0-9 ]+" "outlet\.id: [0-9]+" "outlet\.switchable: [a-zA-Z]+" "output\.current: [0-9.]+" "output\.frequency: [0-9.]+" "output\.frequency\.nominal: [0-9.]+" "output\.powerfactor: [0-9.]+" "output\.voltage: [0-9.]+" "output\.voltage\.nominal: [0-9.]+" "ups\.beeper\.status: [a-zA-Z]+" "ups\.delay\.shutdown: [0-9]+" "ups\.delay\.start: [0-9]+" "ups\.efficiency: [0-9]+" "ups\.firmware: [a-zA-Z0-9. ]+" "ups\.load: [0-9.]+" "ups\.load\.high: [0-9]+" "ups\.mfr: [a-zA-Z0-9]+" "ups\.model: [a-zA-Z0-9 ]+" "ups\.power: [0-9.]+" "ups\.power\.nominal: [0-9.]+" "ups\.productid: [a-zA-Z0-9]+"
do
    OUT=$(echo "$TMP" | grep -Eo "$value" | awk '{print $2}' | LANG=C sort | head -n 1)
    if [ -n "$OUT" ]; then
        echo "$OUT"
    else
        echo "Unknown"
    fi
done
