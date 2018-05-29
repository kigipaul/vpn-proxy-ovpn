#!/bin/bash
# General Init
ROOT_PATH=$(dirname "$0")
SCRIPT_PATH=$ROOT_PATH/script
CONF_PATH=$ROOT_PATH/config
OUT_USER=$ROOT_PATH/o_vpn-proxy.ovpn
OUT_USER_ROOT=/tmp
OUT_OVPN=$ROOT_PATH/o_proxy.conf
OUT_SET=$ROOT_PATH/o_setServer.sh
OUT_REMOTE=$ROOT_PATH/o_remote
VPN_PATH="/etc/openvpn/server"

echo "======================="
echo "=   Install OpenVPN   ="
echo "======================="
apt-get update
apt-get upgrade -y
apt-get install -y openvpn
sleep 5
echo "=========================="
echo "=   Check OpenVPN User   ="
echo "=========================="
if id openvpn|egrep -q '^.*no such user.*$';then
  echo ">> Create User"
  useradd openvpn
else
  echo ">> User already exist"
fi
sleep 5

echo "======================"
echo "=   Connect Remote   ="
echo "======================"
REMOTE=(`du -a $CONF_PATH/remote|grep -E "^.*\.ovpn$"|awk '{print $2}'`)
for ((i=0;i<${#REMOTE[@]};i++));do
  REMOTE_CONF=${REMOTE[$i]}
  echo ">> Connect to $REMOTE_CONF ..."
  screen -S VPN${i} -dm openvpn --config $CONF_PATH/remote/$REMOTE_CONF
  sleep 2
done
sleep 10
echo "==========================="
echo "=   Create Setting file   ="
echo "==========================="

$SCRIPT_PATH/build_file.sh
chbuild=$?
if [ $chbuild -ne 0 ];then
    echo "Error from build_file"
    exit 1
fi

sleep 2

echo "======================"
echo "=   Install Config   ="
echo "======================"

cp $OUT_SET $VPN_PATH/setServer.sh
cp $OUT_OVPN $VPN_PATH/proxy.conf
mv keys $VPN_PATH/

$VPN_PATH/setServer.sh
openvpn --writepid /run/openvpn/ovpn-proxy.pid --daemon ovpn-proxy --cd $VPN_PATH --config $VPN_PATH/proxy.conf
sleep 5

echo "=========================="
echo "=   Create User Config   ="
echo "========================="

mkdir $OUT_USER_ROOT
cp $OUT_USER $OUT_USER_ROOT/vpn-proxy.ovpn

echo "============="
echo "=   Clean   ="
echo "============="
rm $ROOT_PATH/o_*
echo "ALL DONE"

