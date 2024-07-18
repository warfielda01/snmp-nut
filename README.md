# snmp-nut
This is an auto installer for nut and snmp. It should create a new admin user, and then update all the relevant files to make it work

#### THIS IS ONLY TESTED ON ORANGE PI ZERO 3 with eaton USB UPS ####

Setup instructions:

git clone https://github.com/warfielda01/snmp-nut.git

cd snmp-nut

cp nut_zabbix.config.example nut_zabbix.config
#### Modify the nut_zabbix.config now

sudo ./setup.sh

Reboot at the end to test. 
You can modify passwords in config files. 
