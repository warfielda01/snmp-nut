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
    echo -e "${RED}Configuration file $CONFIG_FILE not found!${NC}"
    cp nut_zabbix.config.example nut_zabbix.config
    echo -e "${YELLOW}Copied the example file. Please modify nut_zabbix.conf${NC}"
    exit 1
fi

# Source the configuration file
source "$CONFIG_FILE"

echo -e "${BLUE}Updating and upgrading the system...${NC}"
# Update and upgrade the system
sudo apt update
sudo apt --fix-broken install
sudo apt upgrade -y

echo -e "${BLUE}Installing NUT and its dependencies...${NC}"
# Install NUT and its dependencies
sudo apt install -y nut

echo -e "${BLUE}Installing Zabbix agent...${NC}"
# Install Zabbix agent
sudo apt install -y zabbix-agent

echo -e "${BLUE}Installing SNMP...${NC}"
# Install SNMP
sudo apt install -y snmp snmpd

echo -e "${BLUE}Configuring NUT...${NC}"
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

echo -e "${BLUE}Setting correct permissions...${NC}"
# Set correct permissions
sudo chmod 640 /etc/nut/*.conf
sudo chown root:nut /etc/nut/*.conf

echo -e "${BLUE}Starting NUT services...${NC}"
# Start NUT services
sudo systemctl enable nut-server nut-monitor
sudo systemctl start nut-server nut-monitor

echo -e "${BLUE}Configuring Zabbix agent...${NC}"
# Configure Zabbix agent
sudo sed -i "s/^Hostname=.*/Hostname=$HOSTNAME/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^Server=.*/Server=$ZABBIX_SERVER_IP/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^ServerActive=.*/ServerActive=$ZABBIX_SERVER_ACTIVE/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^ListenPort=.*/ListenPort=$ZABBIX_LISTEN_PORT/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^ListenIP=.*/ListenIP=$ZABBIX_LISTEN_IP/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^# HostMetadata=.*/HostMetadata=$ZABBIX_META_DATA/" $ZABBIX_AGENT_CONF

echo -e "${BLUE}Configuring TLS settings if provided...${NC}"
# Configure TLS settings if provided
if [ ! -z "$ZABBIX_TLS_CONNECT" ]; then
    sudo sed -i "s/^# TLSConnect=.*/TLSConnect=$ZABBIX_TLS_CONNECT/" $ZABBIX_AGENT_CONF
    sudo sed -i "s/^# TLSAccept=.*/TLSAccept=$ZABBIX_TLS_ACCEPT/" $ZABBIX_AGENT_CONF
    sudo sed -i "s/^# TLSPSKIdentity=.*/TLSPSKIdentity=$ZABBIX_TLS_PSK_IDENTITY/" $ZABBIX_AGENT_CONF
    sudo sed -i "s|^# TLSPSKFile=.*|TLSPSKFile=$ZABBIX_TLS_PSK_FILE|" $ZABBIX_AGENT_CONF
fi

echo -e "${BLUE}Configuring Zabbix agent for NUT monitoring...${NC}"
# Configure Zabbix agent for NUT monitoring
echo "" | sudo tee -a $ZABBIX_AGENT_CONF > /dev/null
echo "# NUT monitoring" | sudo tee -a $ZABBIX_AGENT_CONF > /dev/null
for param in "${UPS_PARAMS[@]}"; do
    echo "UserParameter=$param,/bin/upsc $UPS_NAME@localhost $param" | sudo tee -a $ZABBIX_AGENT_CONF > /dev/null
done

echo -e "${BLUE}Configuring SNMP...${NC}"
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

echo -e "${BLUE}Creating new admin user if specified...${NC}"
# Create new admin user if specified
if [ "$CREATE_ADMIN_USER" = "true" ]; then
    echo -e "${YELLOW}Creating new admin user: $NEW_ADMIN_USERNAME${NC}"
    sudo useradd -m -s /bin/bash $NEW_ADMIN_USERNAME
    echo "$NEW_ADMIN_USERNAME:$NEW_ADMIN_PASSWORD" | sudo chpasswd
    sudo usermod -aG sudo $NEW_ADMIN_USERNAME
fi

echo -e "${BLUE}Resetting Pi user password if specified...${NC}"
# Reset Pi user password if specified
if [ "$RESET_PI_PASSWORD" = "true" ]; then
    echo -e "${YELLOW}Resetting password for $PI_USER user${NC}"
    echo "$PI_USER:$NEW_ADMIN_PASSWORD" | sudo chpasswd
fi

echo -e "${BLUE}Restarting services...${NC}"
# Restart services
sudo systemctl restart zabbix-agent
sudo systemctl restart snmpd

# Wait for SNMP to start
sleep 5

echo -e "${BLUE}Testing SNMP configuration...${NC}"
# Test SNMP configuration
snmpwalk -v2c -c $SNMP_COMMUNITY localhost > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SNMP is working locally.${NC}"
else
    echo -e "${RED}Error: SNMP is not working locally. Check the configuration and logs.${NC}"
fi

echo -e "${BLUE}Checking if SNMP is listening on all interfaces...${NC}"
# Check if SNMP is listening on all interfaces
netstat -ulnp | grep snmpd

# Display SNMP logs
echo -e "${BLUE}Recent SNMP logs:${NC}"
sudo tail -n 20 /var/log/syslog | grep snmpd

echo -e "${BLUE}Setting the hostname...${NC}"
# Set the hostname
sudo hostnamectl set-hostname $HOSTNAME

echo -e "${INDIGO}NUT, Zabbix agent, and SNMP have been installed and configured.${NC}"
echo -e "${VIOLET}Hostname set to: $HOSTNAME${NC}"
echo -e "${RED}NUT username set to: $NUT_USERNAME${NC}"
echo -e "${ORANGE}Zabbix agent configured to connect to server at: $ZABBIX_SERVER_IP${NC}"
echo -e "${YELLOW}SNMP community string set to: $SNMP_COMMUNITY${NC}"
if [ "$CREATE_ADMIN_USER" = "true" ]; then
    echo -e "${GREEN}New admin user created: $NEW_ADMIN_USERNAME${NC}"
fi
if [ "$RESET_PI_PASSWORD" = "true" ]; then
    echo -e "${BLUE}Password reset for $PI_USER user${NC}"
fi
echo -e "${VIOLET}Please update the Zabbix server and your SNMP monitoring system to start monitoring your UPS.${NC}"
echo -e "${INDIGO}If you're still having issues, please check the logs and ensure your firewall allows incoming connections on UDP port 161.${NC}"
