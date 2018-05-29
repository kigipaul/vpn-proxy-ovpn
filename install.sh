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

function usage(){
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "OPTIONS:"
    echo "  --without-init-vpn             Without init openvpn"
    echo "  --without-connect-remote-vpn   Without Connect to remote vpn"
    echo "  --without-create-file          Without Create tmp config file"
    echo "  --no-start                     NO Start VPN PROXY Server"
    echo "  --dev DEV                      Setting Host physical interface name. (default: ens4)"
    echo "  --net NET                      Choose Network Group for vpn server"
    echo "                                 NET: net1=10.0.0.0/8"
    echo "                                      net2=172.16.0.0/12"
    echo "                                      net3=192.168.0.0/16"
    echo
}
function init_openvpn() {
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
}

function connect_remote() {
    if [ ! -z "$1" ]; then
        no_connect=1
    fi
    echo "======================"
    echo "=   Connect Remote   ="
    echo "======================"
    REMOTE=(`du -a $CONF_PATH/remote|grep -E "^.*\.ovpn$"|awk '{print $2}'`)
    for ((i=0;i<${#REMOTE[@]};i++));do
      REMOTE_CONF=${REMOTE[$i]}
      if [ -z $no_connect ]; then
        echo -e ">> Connect to $REMOTE_CONF ... \c"
        screen -S VPN${i} -dm openvpn --config $REMOTE_CONF
        ch=$?
        sleep 2
        if [ -z $ch ];then
            echo "OK"
        else
            echo "Failed"
        fi
      else
        echo "NO Connect >> screen -S VPN${i} -dm openvpn --config $REMOTE_CONF"
      fi
    done
    if [ -z $no_connect ]; then
      sleep 10
    fi
}
function create_file() {
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
}
function install_config() {
    if [ ! -z $1 ]; then
        no_start=1
    fi
    echo "======================"
    echo "=   Install Config   ="
    echo "======================"

    cp $OUT_SET $VPN_PATH/setServer.sh
    cp $OUT_OVPN $VPN_PATH/proxy.conf
    mv keys $VPN_PATH/

    if [ -z $no_start ];then
        echo -n ">> Start OpenVPN Server ... "
        $VPN_PATH/setServer.sh
        openvpn --writepid /run/openvpn/ovpn-proxy.pid --daemon ovpn-proxy --cd $VPN_PATH --config $VPN_PATH/proxy.conf
        ch=$?
        sleep 5
        if [ -z $ch ];then
            echo "OK"
        else
            echo "Failed"
        fi
    else
        echo "All Ready Create set script[$VPN_PATH/setServer.sh] and server config[$VPN_PATH/proxy.conf]"
        echo "NO Excute: openvpn --writepid /run/openvpn/ovpn-proxy.pid --daemon ovpn-proxy --cd $VPN_PATH --config $VPN_PATH/proxy.conf"
    fi
    echo "=========================="
    echo "=   Create User Config   ="
    echo "========================="

    if [ ! -e $OUT_USER_ROOT ]; then
        mkdir -p $OUT_USER_ROOT
    fi
    cp $OUT_USER $OUT_USER_ROOT/vpn-proxy.ovpn
}
function clean() {
    echo "============="
    echo "=   Clean   ="
    echo "============="
    rm $ROOT_PATH/o_*
}

while [ ! -z $1 ]; do
    case $1 in 
        --without-init-vpn) WITHOUT_INIT=1;shift;;
        --without-connect-remote-vpn) WITHOUT_REMOTE_VPN=1;shift;;
        --without-create-file) WITHOUT_CREATE_FILE=1;shift;;
        --no-start) NO_START=1;shift;;
        --dev) shift; DEV=$1; shift;;
        --net) shift; NET=$1; shift;;
        *) usage;;;
    esac
done
if [ -z $WITHOUT_INIT ];then
    init_openvpn
fi
connect_remote $WITHOUT_REMOTE_VPN
if [ -z $WITHOUT_CREATE_FILE ];then
    create_file 
fi
install_config $NO_START
clean
echo "ALL DONE"

