#!/bin/bash

# check in  sshpass installed
if ! command -v sshpass &> /dev/null; then
    echo "❌ sshpass not installed"
    exit 1
fi

# load vars from .env
if [[ -f .env ]]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ .env file not found"
    exit 1
fi

# log file
LOG_FILE="adopt_log.txt"

# get ip APs from mikrotik
echo "get ips from MikroTik $MIKROTIK_HOSTNAME..."

# you can cahange or add another mac-address via | (pipe)
sshpass -p "$MIKROTIK_PASS" ssh -o StrictHostKeyChecking=no "$MIKROTIK_USER@$MIKROTIK_HOSTNAME" \
"/ip dhcp-server lease print without-paging" \
| grep -iE '0C:EA:14:|28:70:4E:' \
| awk '{print $3}' > ips.txt

# print ips to cli
echo "✅ AP ips: $(cat -n < ips.txt)"

sed -i 's/\r$//' ips.txt

for ip in $(cat ips.txt); do
    [[ -z "$ip" ]] && continue
    echo "➡️ $ip — set-inform"

    sshpass -p "$UNIFI_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$UNIFI_USER@$ip" \
    "mca-cli-op set-inform $INFORM_URL" > /dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        echo "$ip - ✅ set-inform done - $(date)" | tee -a "$LOG_FILE"
    else
        echo "$ip - ❌ connection error - $(date)" | tee -a "$LOG_FILE"
    fi
done < ips.txt
