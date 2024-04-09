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

# Function to replace a file with a provided one
replace_file() {
    if [ -f "$1" ]; then
        echo "Replacing $2 with provided file..."
        sudo cp "$1" "$2"
    else
        echo "Error: Provided $2 file not found."
        exit 1
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

# Replace other files with provided ones
replace_file "/config/upsmon.conf" "/etc/nut/upsmon.conf"
replace_file "/config/upsd.conf" "/etc/nut/upsd.conf"
replace_file "/config/nut.conf" "/etc/nut/nut.conf"
replace_file "/config/upsd.users" "/etc/nut/upsd.users"
replace_file "/config/ups-nut.sh" "/etc/snmp/ups-nut.sh"

# Make ups-nut.sh executable
make_executable "/etc/snmp/ups-nut.sh"

# Create /etc/snmp/snmpd.conf
create_snmpd_conf

echo "Setup completed successfully."
