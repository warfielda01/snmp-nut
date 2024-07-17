#!/bin/bash

# Check if config file exists
CONFIG_FILE="nut_zabbix.config"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file $CONFIG_FILE not found!"
    cp nut_zabbix.config.example nut_zabbix.config
    echo "Copied the example file. Please modify nut_zabbix.conf"
    exit 1
fi

# Source the configuration file
source "$CONFIG_FILE"

# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Install NUT and its dependencies
sudo apt install -y nut

# Install Zabbix agent
sudo apt install -y zabbix-agent

# Install SNMP
sudo apt install -y snmp snmpd

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

# Set correct permissions
sudo chmod 640 /etc/nut/*.conf
sudo chown root:nut /etc/nut/*.conf

# Start NUT services
sudo systemctl enable nut-server nut-monitor
sudo systemctl start nut-server nut-monitor

# Configure Zabbix agent
sudo sed -i "s/^Hostname=.*/Hostname=$HOSTNAME/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^Server=.*/Server=$ZABBIX_SERVER_IP/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^ServerActive=.*/ServerActive=$ZABBIX_SERVER_ACTIVE/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^ListenPort=.*/ListenPort=$ZABBIX_LISTEN_PORT/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^ListenIP=.*/ListenIP=$ZABBIX_LISTEN_IP/" $ZABBIX_AGENT_CONF
sudo sed -i "s/^# HostMetadata=.*/HostMetadata=$ZABBIX_META_DATA/" $ZABBIX_AGENT_CONF

# Configure TLS settings if provided
if [ ! -z "$ZABBIX_TLS_CONNECT" ]; then
    sudo sed -i "s/^# TLSConnect=.*/TLSConnect=$ZABBIX_TLS_CONNECT/" $ZABBIX_AGENT_CONF
    sudo sed -i "s/^# TLSAccept=.*/TLSAccept=$ZABBIX_TLS_ACCEPT/" $ZABBIX_AGENT_CONF
    sudo sed -i "s/^# TLSPSKIdentity=.*/TLSPSKIdentity=$ZABBIX_TLS_PSK_IDENTITY/" $ZABBIX_AGENT_CONF
    sudo sed -i "s|^# TLSPSKFile=.*|TLSPSKFile=$ZABBIX_TLS_PSK_FILE|" $ZABBIX_AGENT_CONF
fi

# Configure Zabbix agent for NUT monitoring
echo "" | sudo tee -a $ZABBIX_AGENT_CONF > /dev/null
echo "# NUT monitoring" | sudo tee -a $ZABBIX_AGENT_CONF > /dev/null
for param in "${UPS_PARAMS[@]}"; do
    echo "UserParameter=$param,/bin/upsc $UPS_NAME@localhost $param" | sudo tee -a $ZABBIX_AGENT_CONF > /dev/null
done

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

# Create new admin user if specified
if [ "$CREATE_ADMIN_USER" = "true" ]; then
    echo "Creating new admin user: $NEW_ADMIN_USERNAME"
    sudo useradd -m -s /bin/bash $NEW_ADMIN_USERNAME
    echo "$NEW_ADMIN_USERNAME:$NEW_ADMIN_PASSWORD" | sudo chpasswd
    sudo usermod -aG sudo $NEW_ADMIN_USERNAME
fi

# Reset Pi user password if specified
if [ "$RESET_PI_PASSWORD" = "true" ]; then
    echo "Resetting password for $PI_USER user"
    echo "$PI_USER:$NEW_ADMIN_PASSWORD" | sudo chpasswd
fi

# Restart services
sudo systemctl restart zabbix-agent
sudo systemctl restart snmpd

# Wait for SNMP to start
sleep 5

# Test SNMP configuration
echo "Testing SNMP configuration..."
snmpwalk -v2c -c $SNMP_COMMUNITY localhost > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "SNMP is working locally."
else
    echo "Error: SNMP is not working locally. Check the configuration and logs."
fi

# Check if SNMP is listening on all interfaces
netstat -ulnp | grep snmpd

# Display SNMP logs
echo "Recent SNMP logs:"
sudo tail -n 20 /var/log/syslog | grep snmpd

echo "NUT, Zabbix agent, and SNMP have been installed and configured."
echo "Hostname set to: $HOSTNAME"
echo "NUT username set to: $NUT_USERNAME"
echo "Zabbix agent configured to connect to server at: $ZABBIX_SERVER_IP"
echo "SNMP community string set to: $SNMP_COMMUNITY"
if [ "$CREATE_ADMIN_USER" = "true" ]; then
    echo "New admin user created: $NEW_ADMIN_USERNAME"
fi
if [ "$RESET_PI_PASSWORD" = "true" ]; then
    echo "Password reset for $PI_USER user"
fi
echo "Please update the Zabbix server and your SNMP monitoring system to start monitoring your UPS."
echo "If you're still having issues, please check the logs and ensure your firewall allows incoming connections on UDP port 161."
