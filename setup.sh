#!/bin/bash

# Function to generate a random password
generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 15 ; echo ''
}

# Function to install required packages from requirements.txt
install_requirements() {
    if [ -f "requirements.txt" ]; then
        sudo apt update
        sudo apt install $(cat requirements.txt)
    else
        echo "Error: requirements.txt not found."
        exit 1
    fi
}

# Function to edit /etc/nut/ups.conf
edit_ups_conf() {
    sudo tee -a /etc/nut/ups.conf > /dev/null <<EOT
[ups]
    driver = "usbhid-ups"
    port = "auto"
    product = "Eaton 5E"
EOT
}

# Function to replace or create a file with a provided one
replace_or_create_file() {
    if [ -f "$2" ]; then
        echo "Replacing $2 with provided file..."
        sudo cp "$1" "$2"
    else
        echo "Creating $2 with provided file..."
        sudo cp "$1" "$2"
    fi
}

# Function to make a script executable
make_executable() {
    if [ -f "$1" ]; then
        echo "Making $1 executable..."
        sudo chmod +x "$1"
    else
        echo "Error: $1 not found."
        exit 1
    fi
}

# Function to create /etc/snmp/snmpd.conf
create_snmpd_conf() {
    echo "Creating /etc/snmp/snmpd.conf..."
    echo "Please enter the sysLocation:"
    read sysLocation

    sudo tee /etc/snmp/snmpd.conf > /dev/null <<EOT
sysContact <Your Contact Information>
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

    # Add extend directive for ups-status.sh
    echo "Adding extend directive for ups-status.sh..."
    sudo upsc ups@localhost | sed 's/^\(.*\): .*$/extend \1 \/usr\/local\/bin\/ups-status.sh \1/' >> /etc/snmp/snmpd.conf
}

# Function to push ups_status.sh to /usr/local/bin/ups-status.sh
push_ups_status() {
    echo "Pushing ups_status.sh to /usr/local/bin/ups-status.sh..."
    sudo cp "ups_status.sh" "/usr/local/bin/ups-status.sh"
}

# Function to start and enable nut-server service
start_and_enable_services() {
    echo "Starting nut-server service..."
    sudo service nut-server start

    echo "Starting snmpd service..."
    sudo service snmpd start

    echo "Enabling nut-server and snmpd services to start on boot..."
    sudo systemctl enable nut-server.service
    sudo systemctl enable snmpd.service
}

# Create a user called localadmin with a random password
echo "Creating user 'localadmin'..."
password=$(generate_password)
sudo useradd -m -s /bin/bash localadmin
echo "Setting password for 'localadmin' to: $password"
echo "localadmin:$password" | sudo chpasswd

# Add 'localadmin' to the sudo group
echo "Adding 'localadmin' to the sudo group..."
sudo usermod -aG sudo localadmin

# Install required services from requirements.txt
echo "Installing required services..."
install_requirements

# Edit /etc/nut/ups.conf
echo "Editing /etc/nut/ups.conf..."
edit_ups_conf

# Replace or create other files with provided ones
replace_or_create_file "config/upsmon.conf" "/etc/nut/upsmon.conf"
replace_or_create_file "config/upsd.conf" "/etc/nut/upsd.conf"
replace_or_create_file "config/nut.conf" "/etc/nut/nut.conf"
replace_or_create_file "config/upsd.users" "/etc/nut/upsd.users"
replace_or_create_file "config/ups-nut.sh" "/etc/snmp/ups-nut.sh"
replace_or_create_file "config/ups-status.sh" "/usr/local/bin/ups-nut.sh"

# Make sh executable
make_executable "/etc/snmp/ups-nut.sh"
make_executable "/usr/local/bin/ups-status.sh"

# Push ups_status.sh to /usr/local/bin/ups-status.sh
push_ups_status

# Create /etc/snmp/snmpd.conf and add extend directive
create_snmpd_conf

# Start and enable nut-server service
start_and_enable_services

echo "Setup completed successfully."
