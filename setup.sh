#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to generate a random password
generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 15 ; echo ''
}

# Function to install required packages from requirements.txt
install_requirements() {
    if [ -f "requirements.txt" ]; then
        echo -e "${YELLOW}Installing required packages...${NC}"
        sudo apt install $(cat requirements.txt)
    else
        echo -e "${RED}Error: requirements.txt not found.${NC}"
        exit 1
    fi
}

# Function to replace or create a file with a provided one
replace_or_create_file() {
    if [ -f "$2" ]; then
        echo -e "${YELLOW}Replacing $2 with provided file...${NC}"
        sudo cp "$1" "$2"
    else
        echo -e "${YELLOW}Creating $2 with provided file...${NC}"
        sudo cp "$1" "$2"
    fi
}

# Function to make a script executable
make_executable() {
    if [ -f "$1" ]; then
        echo -e "${YELLOW}Making $1 executable...${NC}"
        sudo chmod +x "$1"
    else
        echo -e "${RED}Error: $1 not found.${NC}"
        exit 1
    fi
}

# Function to create /etc/snmp/snmpd.conf
create_snmpd_conf() {
    echo -e "${YELLOW}Creating /etc/snmp/snmpd.conf...${NC}"
    echo -e "${YELLOW}Please enter the sysLocation:${NC}"
    read sysLocation
    echo -e "${YELLOW}Please enter the email:${NC}"
    read sysContact

    # Set the system name (hostname)
    echo -e "${YELLOW}Please enter the computer name:${NC}"
    read computerName
    sudo hostnamectl set-hostname "$computerName"

    # Create snmpd.conf in the config directory
    sudo tee "config/snmpd.conf" > /dev/null <<EOT
sysContact $sysContact
sysLocation $sysLocation
sysServices 72
master agentx
view systemonly included .1.3.6.1.2.1.1
view systemonly included .1.3.6.1.2.1.25.1
rocommunity public
extend ups-nut /etc/snmp/ups-nut.sh
rouser authPrivUser authpriv -V systemonly
includeDir /etc/snmp/snmp.conf.d
EOT

    # Move snmpd.conf to /etc/snmp directory
    sudo mv "config/snmpd.conf" "/etc/snmp/" || { echo -e "${RED}Failed to move snmpd.conf to /etc/snmp/${NC}"; exit 1; }

    # Add extend directive for ups-status.sh
    #echo -e "${YELLOW}Adding extend directive for ups-status.sh...${NC}"
    #sudo upsc ups@localhost | sed 's/^\(.*\): .*$/extend \1 \/usr\/local\/bin\/ups-status.sh \1/' >> "/etc/snmp/snmpd.conf"
}

# Function to start and enable nut-server service
start_and_enable_services() {
    echo -e "${YELLOW}Starting nut-server service...${NC}"
    sudo service nut-server start
    sudo systemctl enable nut-server

    echo -e "${YELLOW}Starting snmpd service...${NC}"
    sudo service snmpd start
    sudo systemctl enable snmpd

    echo -e "${GREEN}Services enabled to start on boot.${NC}"
}

# Create a user called localadmin with a random password
echo -e "${YELLOW}Creating user 'localadmin'...${NC}"
password=$(generate_password)
sudo useradd -m -s /bin/bash localadmin
echo -e "${YELLOW}Setting password for 'localadmin' to: $password${NC}"
echo "localadmin:$password" | sudo chpasswd

# Add 'localadmin' to the sudo group
echo -e "${YELLOW}Adding 'localadmin' to the sudo group...${NC}"
sudo usermod -aG sudo localadmin

# Install required services from requirements.txt
install_requirements

# Create /etc/snmp/snmpd.conf and add extend directive
create_snmpd_conf

# Replace or create other files with provided ones
replace_or_create_file "config/upsmon.conf" "/etc/nut/upsmon.conf"
replace_or_create_file "config/upsd.conf" "/etc/nut/upsd.conf"
replace_or_create_file "config/nut.conf" "/etc/nut/nut.conf"
replace_or_create_file "config/upsd.users" "/etc/nut/upsd.users"
replace_or_create_file "config/ups-nut.sh" "/etc/snmp/ups-nut.sh"
replace_or_create_file "config/ups-status.sh" "/usr/local/bin/ups-nut.sh"
replace_or_create_file "config/snmpd.conf" "/etc/snmp/snmpd.conf"
replace_or_create_file "config/ups-status.sh" "/usr/local/bin/ups-status.sh"

# Make sh executable
make_executable "/etc/snmp/ups-nut.sh"
make_executable "/usr/local/bin/ups-status.sh"

# Push ups_status.sh to /usr/local/bin/ups-status.sh
push_ups_status

# Start and enable nut-server service
start_and_enable_services

echo -e "${GREEN}Setup completed successfully.${NC}"

