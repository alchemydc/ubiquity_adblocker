#!/bin/sh
# Block ads, malware, etc..

TEMP=`mktemp /config/user-data/adblock/tmp.XXXXXX`
TEMP_SORTED=`mktemp /config/user-data/adblock/tmp_sorted.XXXXXX`
DNSMASQ_WHITELIST="/config/user-data/adblock/white.list"
DNSMASQ_BLACKLIST="/config/user-data/adblock/black.list"
DNSMASQ_BLOCKHOSTS="/etc/dnsmasq.d/dnsmasq.adlist.conf"
BLOCKLIST_URLS=`cat /config/user-data/adblock/adblock_lists.txt`

#Delete the old block.hosts to make room for the updates
rm -f $DNSMASQ_BLOCKHOSTS

echo 'Downloading hosts lists...'
#Download and process the files needed to make the lists (enable/add more, if you want)
for url in $BLOCKLIST_URLS; do
  curl $url | grep -Ev "(localhost)" | grep -Ew "(0.0.0.0|127.0.0.1)" | awk '{sub(/\r$/,"");print $2}'  >> "$TEMP"
  #wget --timeout=2 --tries=3 -qO- "$url" | grep -Ev "(localhost)" | grep -Ew "(0.0.0.0|127.0.0.1)" | awk '{sub(/\r$/,"");print $2}'  >> "$TEMP"
done

#Add black list, if non-empty
if [ -s "$DNSMASQ_BLACKLIST" ]
then
    echo 'Adding blacklist...'
    cat $DNSMASQ_BLACKLIST >> "$TEMP"
fi

#Sort the download/black lists
echo "Sorting the lists"
awk '/^[^#]/ { print "local=/" $1 "/" }' "$TEMP" | sort -u > "$TEMP_SORTED"

#Filter (if applicable)
if [ -s "$DNSMASQ_WHITELIST" ]
then
    #Filter the blacklist, suppressing whitelist matches
    #  This is relatively slow =-(
    echo 'Filtering white list...'
    #probably won't work
    sudo egrep -v "^[[:space:]]*$" $DNSMASQ_WHITELIST | awk '/^[^#]/ {sub(/\r$/,"");print $1}' | grep -vf - "$TEMP_SORTED" > $DNSMASQ_BLOCKHOSTS
else
    sudo cp "$TEMP_SORTED" $DNSMASQ_BLOCKHOSTS
    sudo chmod 644 $DNSMASQ_BLOCKHOSTS
fi

#service dnsmasq restart
sudo /etc/init.d/dnsmasq force-reload

echo "Removing temp files"
rm -f $TEMP
rm -f $TEMP_SORTED

exit 0