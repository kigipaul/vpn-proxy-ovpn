#!/bin/bash
###
#  General Init
###
DEV='ens4'
SCRIPT_PATH=$(dirname "$0")
ROOT_PATH=$SCRIPT_PATH/..
BIN_KEY_PATH=$ROOT_PATH/bin/easy-rsa
CONF_PATH=$ROOT_PATH/config
BASE_OVPN=$ROOT_PATH/templates/ovpn.conf
BASE_USER=$ROOT_PATH/templates/vpn-proxy.ovpn
BASE_SET=$ROOT_PATH/templates/setServer.sh
OUT_OVPN=$ROOT_PATH/o_proxy.conf
OUT_SET=$ROOT_PATH/o_setServer.sh
OUT_USER=$ROOT_PATH/o_vpn-proxy.ovpn

###
#  Get Remote VPN Info
###
REMOTE_IFs=(`ip link |grep -E "tun|tap"|awk '{print $2}'|cut -d':' -f 1`)
NUM_REMOTE=${#REMOTE_IFs[@]}
if [ $NUM_REMOTE -eq 0 ]; then
    echo "Error: NO Remote VPN Connect"
    exit 1
fi

###
#  Proxy init
###
CLIENT_NAME="client-"`uuidgen|awk -F'-' '{print $2$3}'`
SERVER_NAME="vpn-proxy"
SERVER_IP=`$ROOT_PATH/bin/randip -p 24 -t net2,net3`
SERVER_IP_MASK="255.255.255.0"
SERVER_IP_PREFIX="24"
SERVER_PORT=`python3 -c "import random; print(random.randint(35000, 40000))"`
MGMT_PORT=`python3 -c "import random; print(random.randint(30000, 34000))"`
NETs=()
NUM_TAP=(`ip link |grep "tap"|awk '{print $2}'`)
LOCAL_DEV="tap${#NUM_TAP[@]}"
LOCAL_IFs=()
ROUTE_TABLES=""
OTHERS=
for ((i=0;i<$NUM_REMOTE;i++));do
    route_table=(`route -n|grep "${REMOTE_IFs[$i]}"|awk '{print $1"_"$3}'`)
    for route in ${route_table[@]};do
        p=`echo $route|cut -d'_' -f 1`
        m=`echo $route|cut -d'_' -f 2`
        ROUTE_TABLES="${ROUTE_TABLES}push \"route $p $m\"\n"
    done
    NETs+=("$SERVER_IP\\/$SERVER_IP_PREFIX")
    LOCAL_IFs+=($LOCAL_DEV)
done

###
#  Create Keys
###
now=`pwd`
cd $BIN_KEY_PATH
source ./vars
./clean-all
./build-ca --batch
./build-key-server --batch $SERVER_NAME
./build-key --batch $CLIENT_NAME
./build-dh
cd keys
openvpn --genkey --secret ta.key
cd $now
mv $BIN_KEY_PATH/keys .
CLIENT_CA="<ca>\n`cat keys/ca.crt`\n</ca>"
CLIENT_TA="<tls-auth>\n`cat keys/ta.key`\n</tls-auth>"
CLIENT_CERT="<cert>\n`cat keys/${CLIENT_NAME}.crt`\n</cert>"
CLIENT_KEY="<key>\n`cat keys/${CLIENT_NAME}.key`\n</key>"
LOCAL_IP=`ifconfig $DEV| awk '/inet /{print $2}'`
###
#  Update File
###
cp $BASE_OVPN $OUT_OVPN
cp $BASE_USER $OUT_USER
cp $BASE_SET $OUT_SET
sed -i "s/!SERVER_IP!/$SERVER_IP/g" $OUT_OVPN
sed -i "s/!SERVER_IP_MASK!/$SERVER_IP_MASK/g" $OUT_OVPN
sed -i "s/!SERVER_PORT!/$SERVER_PORT/g" $OUT_OVPN
sed -i "s/!SERVER_CERT!/keys\/$SERVER_NAME.crt/g" $OUT_OVPN
sed -i "s/!SERVER_KEY!/keys\/$SERVER_NAME.key/g" $OUT_OVPN
sed -i "s/!SERVER_DH!/keys\/dh$KEY_SIZE.pem/g" $OUT_OVPN
sed -i "s/!ROUTE_TABLES!/$ROUTE_TABLES/g" $OUT_OVPN
sed -i "s/!MGMT_PORT!/$MGMT_PORT/g" $OUT_OVPN
sed -i "s/!OTHERS!/$OTHERS/g" $OUT_OVPN

sed -i "s/!SERVER_PORT!/$SERVER_PORT/g" $OUT_USER
sed -i "s/!LOCAL_IP!/$LOCAL_IP/g" $OUT_USER
echo -e "$CLIENT_CA" >> $OUT_USER
echo -e "$CLIENT_TA" >> $OUT_USER
echo -e "$CLIENT_CERT" >> $OUT_USER
echo -e "$CLIENT_KEY" >> $OUT_USER

sed -i "s/!NUM_REMOTE!/$NUM_REMOTE/g" $OUT_SET
sed -i "s/!SERVER_IP!/$SERVER_IP/g" $OUT_SET
sed -i "s/!NETs!/$NETs/g" $OUT_SET
sed -i "s/!SERVER_PORT!/$SERVER_PORT/g" $OUT_SET
sed -i "s/!SERVER_IP_PREFIX!/$SERVER_IP_PREFIX/g" $OUT_SET
sed -i "s/!REMOTE_IFs!/${REMOTE_IFs[@]}/g" $OUT_SET
sed -i "s/!LOCAL_IFs!/${LOCAL_IFs[@]}/g" $OUT_SET

