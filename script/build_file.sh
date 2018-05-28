#!/bin/bash
###
#  General Init
###
SCRIPT_PATH=$(dirname "$0")
ROOT_PATH=$SCRIPT_PATH/..
BIN_KEY_PATH=$ROOT_PATH/bin/ovpn
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
    route_table=(`route -n|grep $(REMOTE_IFs[$i])|awk '{print $1,$3}'`)
    for route in ${route_table[@]};do
        ROUTE_TABLES="${ROUTE_TABLES}push \"route $route\"\n"
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
./build-ca << eof








eof
./build-key-server $SERVER_NAME << eof











eof
./build-key $CLIENT_NAME << eof











eof
./build-dh
cd keys
openvpn --genkey --secret ta.key
cd $now
mv $BIN_KEY_PATH/keys .
CLIENT_CA=`cat keys/ca.crt`
CLIENT_TA=`cat keys/ta.key`
CLIENT_CERT=`cat keys/${CLIENT_NAME}.crt`
CLIENT_KEY=`cat keys/${CLIENT_NAME}.key`
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

sed -i "s/!CLIENT_CA!/$CLIENT_CA/g" $OUT_USER
sed -i "s/!CLIENT_TA!/$CLIENT_TA/g" $OUT_USER
sed -i "s/!CLIENT_CERT!/$CLIENT_CERT/g" $OUT_USER
sed -i "s/!CLIENT_KEY!/$CLIENT_KEY/g" $OUT_USER

sed -i "s/!NUM_REMOTE!/$NUM_REMOTE/g" $OUT_SET
sed -i "s/!SERVER_IP!/$SERVER_IP/g" $OUT_SET
sed -i "s/!NETs!/$NETs/g" $OUT_SET
sed -i "s/!SERVER_PORT!/$SERVER_PORT/g" $OUT_SET
sed -i "s/!SERVER_IP_PREFIX!/$SERVER_IP_PREFIX/g" $OUT_SET
sed -i "s/!REMOTE_IFs!/${REMOTE_IFs[@]}/g" $OUT_SET
sed -i "s/!LOCAL_IFs!/${LOCAL_IFs[@]}/g" $OUT_SET

