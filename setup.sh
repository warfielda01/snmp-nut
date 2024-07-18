#!/bin/bash

# Colors
RED='\033[0;31m'
ORANGE='\033[0;33m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
INDIGO='\033[0;35m'
VIOLET='\033[0;35m'
NC='\033[0m' # No Color

# Check if config file exists
CONFIG_FILE="nut_zabbix.config"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}C${ORANGE}o${YELLOW}n${GREEN}f${BLUE}i${INDIGO}g${VIOLET}u${RED}r${ORANGE}a${YELLOW}t${GREEN}i${BLUE}o${INDIGO}n${VIOLET} file $CONFIG_FILE not found!${NC}"
    cp nut_zabbix.config.example nut_zabbix.config
    echo -e "${YELLOW}C${GREEN}o${BLUE}p${INDIGO}i${VIOLET}e${RED}d the example file. Please modify nut_zabbix.conf${NC}"
    exit 1
fi

# Source the configuration file
source "$CONFIG_FILE"

echo -e "${BLUE}U${INDIGO}p${VIOLET}d${RED}a${ORANGE}t${YELLOW}i${GREEN}n${BLUE}g and upgrading the system...${NC}"
# Update and upgrade the system
sudo apt update
sudo apt --fix-broken install
sudo apt upgrade -y

echo -e "${BLUE}I${INDIGO}n${VIOLET}s${RED}t${ORANGE}a${YELLOW}l${GREEN}l${BLUE}i${INDIGO}n${VIOLET}g NUT and its dependencies...${NC}"
# Install NUT and its dependencies
sudo apt install -y nut

echo -e "${BLUE}I${INDIGO}n${VIOLET}s${RED}t${ORANGE}a${YELLOW}l${GREEN}l${BLUE}i${INDIGO}n${VIOLET}g Zabbix agent...${NC}"
# Install Zabbix agent
sudo apt install -y zabbix-agent

echo -e "${BLUE}I${INDIGO}n${VIOLET}s${RED}t${ORANGE}a${YELLOW}l${GREEN}l${BLUE}i${INDIGO}n${VIOLET}g SNMP...${NC}"
# Install SNMP
sudo apt install -y snmp snmpd

echo -e "${BLUE}C${INDIGO}o${VIOLET}n${RED}f${ORANGE}i${YELLOW}g${GREEN}u${BLUE}r${INDIGO}i${VIOLET}n${RED}g NUT...${NC}"
# Configure NUT
sudo tee /etc/nut/nut.conf > /dev/null << EOL
MODE=standalone
EOL

sudo tee /etc/nut/ups.conf > /dev/null << EOL
[$UPS_NAME]
    driver = $UPS_DRIVER
    port = $UPS_PORT
    desc = "$UPS_DESC"
EOL

sudo tee /etc/nut/upsd.conf > /dev/null << EOL
LISTEN 127.0.0.1 3493
EOL

sudo tee /etc/nut/upsd.users > /dev/null << EOL
[$NUT_USERNAME]
    password = $NUT_PASSWORD
    upsmon master
EOL

sudo tee /etc/nut/upsmon.conf > /dev/null << EOL
MONITOR $UPS_NAME@localhost 1 $NUT_USERNAME $NUT_PASSWORD master
EOL

echo -e "${BLUE}S${INDIGO}e${VIOLET}t${RED}t${ORANGE}i${YELLOW}n${GREEN}g correct permissions...${NC}"
# Set correct permissions
sudo chmod 640 /etc/nut/*.conf
sudo chown root:nut /etc/nut/*.conf

echo -e "${BLUE}S${INDIGO}t${VIOLET}a${RED}r${ORANGE}t${YELLOW}i${GREEN}n${BLUE}g NUT services...${NC}"
# Start NUT services
sudo systemctl enable nut-server nut-monitor
sudo systemctl start nut-server nut-monitor

echo -e "${BLUE}C${INDIGO}o${VIOLET}n${RED}f${ORANGE}i${YELLOW}g${GREEN}u${BLUE}r${INDIGO}i${VIOLET}n${RED}g Zabbix agent...${NC}"
# Configure Zabbix agent
sudo sed -i "s/^Hostname=.*/Hostname=$HOSTNAME/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^Server=.*/Server=$ZABBIX_SERVER_IP/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^ServerActive=.*/ServerActive=$ZABBIX_SERVER_ACTIVE/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^ListenPort=.*/ListenPort=$ZABBIX_LISTEN_PORT/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^ListenIP=.*/ListenIP=$ZABBIX_LISTEN_IP/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^# HostMetadata=.*/HostMetadata=$ZABBIX_META_DATA/" $ZABBIX_AGENT_CONF

echo -e "${BLUE}C${INDIGO}o${VIOLET}n${RED}f${ORANGE}i${YELLOW}g${GREEN}u${BLUE}r${INDIGO}i${VIOLET}n${RED}g TLS settings if provided...${NC}"
# Configure TLS settings if provided
if [ ! -z "$ZABBIX_TLS_CONNECT" ]; then
    sudo sed -i "s/^# TLSConnect=.*/TLSConnect=$ZABBIX_TLS_CONNECT/" $ZABBIX_AGENT_CONF
    sudo sed -i "s/^# TLSAccept=.*/TLSAccept=$ZABBIX_TLS_ACCEPT/" $ZABBIX_AGENT_CONF
    sudo sed -i "s/^# TLSPSKIdentity=.*/TLSPSKIdentity=$ZABBIX_TLS_PSK_IDENTITY/" $ZABBIX_AGENT_CONF
    sudo sed -i "s|^# TLSPSKFile=.*|TLSPSKFile=$ZABBIX_TLS_PSK_FILE|" $ZABBIX_AGENT_CONF
fi

echo -e "${BLUE}C${INDIGO}o${VIOLET}n${RED}f${ORANGE}i${YELLOW}g${GREEN}u${BLUE}r${INDIGO}i${VIOLET}n${RED}g Zabbix agent for NUT monitoring...${NC}"
# Configure Zabbix agent for NUT monitoring
echo "" | sudo tee -a $ZABBIX_AGENT_CONF > /dev/null
echo "# NUT monitoring" | sudo tee -a $ZABBIX_AGENT_CONF > /dev/null
for param in "${UPS_PARAMS[@]}"; do
    echo "UserParameter=$param,/bin/upsc $UPS_NAME@localhost $param" | sudo tee -a $ZABBIX_AGENT_CONF > /dev/null
done

echo -e "${BLUE}C${INDIGO}o${VIOLET}n${RED}f${ORANGE}i${YELLOW}g${GREEN}u${BLUE}r${INDIGO}i${VIOLET}n${RED}g SNMP...${NC}"
# Configure SNMP
sudo cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.bak
sudo tee /etc/snmp/snmpd.conf > /dev/null << EOL
# Listen on all interfaces
agentAddress udp:161,udp6:[::1]:161

# Configure access control
rocommunity $SNMP_COMMUNITY default
rocommunity6 $SNMP_COMMUNITY default

# System information
sysLocation $SNMP_LOCATION
sysContact $SNMP_CONTACT
sysServices 72

# Include additional configurations
includeDir /etc/snmp/snmpd.conf.d

# Enable verbose logging for debugging
verbose
log_daemon
logging enabled

# NUT monitoring
EOL

# Add NUT monitoring to SNMP (preventing duplicates)
for param in "${UPS_PARAMS[@]}"; do
    if ! grep -q "extend $param" /etc/snmp/snmpd.conf; then
        echo "extend $param /bin/bash -c '/bin/upsc $UPS_NAME@localhost $param'" | sudo tee -a /etc/snmp/snmpd.conf > /dev/null
    fi
done

echo -e "${BLUE}C${INDIGO}r${VIOLET}e${RED}a${ORANGE}t${YELLOW}i${GREEN}n${BLUE}g new admin user if specified...${NC}"
# Create new admin user if specified
if [ "$CREATE_ADMIN_USER" = "true" ]; then
    echo -e "${YELLOW}C${GREEN}r${BLUE}e${INDIGO}a${VIOLET}t${RED}i${ORANGE}n${YELLOW}g new admin user: $NEW_ADMIN_USERNAME${NC}"
    sudo useradd -m -s /bin/bash $NEW_ADMIN_USERNAME
    echo "$NEW_ADMIN_USERNAME:$NEW_ADMIN_PASSWORD" | sudo chpasswd
    sudo usermod -aG sudo $NEW_ADMIN_USERNAME
fi

echo -e "${BLUE}R${INDIGO}e${VIOLET}s${RED}e${ORANGE}t${YELLOW}t${GREEN}i${BLUE}n${INDIGO}g Pi user password if specified...${NC}"
# Reset Pi user password if specified
if [ "$RESET_PI_PASSWORD" = "true" ]; then
    echo -e "${YELLOW}R${GREEN}e${BLUE}s${INDIGO}e${VIOLET}t${RED}t${ORANGE}i${YELLOW}n${GREEN}g password for $PI_USER user${NC}"
    echo "$PI_USER:$NEW_ADMIN_PASSWORD" | sudo chpasswd
fi

echo -e "${BLUE}R${INDIGO}e${VIOLET}s${RED}t${ORANGE}a${YELLOW}r${GREEN}t${BLUE}i${INDIGO}n${VIOLET}g services...${NC}"
# Restart services
sudo systemctl restart zabbix-agent
sudo systemctl restart snmpd

# Wait for SNMP to start
sleep 5

echo -e "${BLUE}T${INDIGO}e${VIOLET}s${RED}t${ORANGE}i${YELLOW}n${GREEN}g SNMP configuration...${NC}"
# Test SNMP configuration
snmpwalk -v2c -c $SNMP_COMMUNITY localhost > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}S${BLUE}N${INDIGO}M${VIOLET}P is working locally.${NC}"
else
    echo -e "${RED}E${ORANGE}r${YELLOW}r${GREEN}o${BLUE}r: SNMP is not working locally. Check the configuration and logs.${NC}"
fi

echo -e "${BLUE}C${INDIGO}h${VIOLET}e${RED}c${ORANGE}k${YELLOW}i${GREEN}n${BLUE}g if SNMP is listening on all interfaces...${NC}"
# Check if SNMP is listening on all interfaces
netstat -ulnp | grep snmpd

# Display SNMP logs
echo -e "${BLUE}R${INDIGO}e${VIOLET}c${RED}e${ORANGE}n${YELLOW}t SNMP logs:${NC}"
sudo tail -n 20 /var/log/syslog | grep snmpd

echo -e "${BLUE}S${INDIGO}e${VIOLET}t${RED}t${ORANGE}i${YELLOW}n${GREEN}g the hostname...${NC}"
# Set the hostname
sudo hostnamectl set-hostname $HOSTNAME

echo -e "${INDIGO}N${VIOLET}U${RED}T, Z${ORANGE}a${YELLOW}b${GREEN}b${BLUE}i${INDIGO}x agent, and SNMP have been installed and configured.${NC}"
echo -e "${VIOLET}H${RED}o${ORANGE}s${YELLOW}t${GREEN}n${BLUE}a${INDIGO}m${VIOLET}e set to: $HOSTNAME${NC}"
echo -e "${RED}N${ORANGE}U${YELLOW}T username set to: $NUT_USERNAME${NC}"
echo -e "${ORANGE}Z${YELLOW}a${GREEN}b${BLUE}b${INDIGO}i${VIOLET}x agent configured to connect to server at: $ZABBIX_SERVER_IP${NC}"
echo -e "${YELLOW}S${GREEN}N${BLUE}M${INDIGO}P community string set to: $SNMP_COMMUNITY${NC}"
if [ "$CREATE_ADMIN_USER" = "true" ]; then
    echo -e "${GREEN}N${BLUE}e${INDIGO}w admin user created: $NEW_ADMIN_USERNAME${NC}"
fi
if [ "$RESET_PI_PASSWORD" = "true" ]; then
    echo -e "${BLUE}P${INDIGO}a${VIOLET}s${RED}s${ORANGE}w${YELLOW}o${GREEN}r${BLUE}d reset for $PI_USER user${NC}"
fi
echo -e "${VIOLET}P${RED}l${ORANGE}e${YELLOW}a${GREEN}s${BLUE}e update the Zabbix server and your SNMP monitoring system to start monitoring your UPS.${NC}"
echo -e "${INDIGO}I${VIOLET}f you're still having issues, please check the logs and ensure your firewall allows incoming connections on UDP port 161.${NC}"
