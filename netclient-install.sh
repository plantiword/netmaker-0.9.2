#!/bin/sh

if [ $(id -u) -ne 0 ]; then
   echo "This script must be run as root"
   exit 1
fi

OS=$(uname)

set -- $dependencies
while [ -n "$1" ]; do
    echo $1
	if [ "${OS}" = "FreeBSD" ]; then
		is_installed=$(pkg check -d $1 | grep "Checking" | grep 
"done")
		if [ "$is_installed" != "" ]; then
			echo "    " $1 is installed
		else
			echo "    " $1 is not installed. Attempting 
install.
			${install_cmd} $1
			sleep 5
			is_installed=$(pkg check -d $1 | grep "Checking" | 
grep "done")
			if [ "$is_installed" != "" ]; then
				echo "    " $1 is installed
			elif [ -x "$(command -v $1)" ]; then
				echo "    " $1 is installed
			else
				echo "    " FAILED TO INSTALL $1
				echo "    " This may break functionality.
			fi
		fi	
	else
		if [ "${OS}" = "OpenWRT" ]; then
			is_installed=$(opkg list-installed $1 | grep $1)
		else
			is_installed=$(dpkg-query -W 
--showformat='${Status}\n' $1 | grep "install ok installed")
		fi
		if [ "${is_installed}" != "" ]; then
			echo "    " $1 is installed
		else
			echo "    " $1 is not installed. Attempting 
install.
			${install_cmd} $1
			sleep 5
			if [ "${OS}" = "OpenWRT" ]; then
				is_installed=$(opkg list-installed $1 | 
grep $1)
			else
				is_installed=$(dpkg-query -W 
--showformat='${Status}\n' $1 | grep "install ok installed")
			fi
			if [ "${is_installed}" != "" ]; then
				echo "    " $1 is installed
			elif [ -x "$(command -v $1)" ]; then
				echo "    " $1 is installed
			else
				echo "    " FAILED TO INSTALL $1
				echo "    " This may break functionality.
			fi
		fi
	fi
	shift
done

set -e

[ -z "$KEY" ] && KEY=nokey;
[ -z "$VERSION" ] && echo "no \$VERSION provided, fallback to latest" && 
VERSION=latest;
[ "latest" != "$VERSION" ] && [ "v" != `echo $VERSION | cut -c1` ] && 
VERSION="v$VERSION"
[ -z "$NAME" ] && NAME="";

dist=netclient

echo "OS Version = $(uname)"
echo "Netclient Version = $VERSION"

case $(uname | tr '[:upper:]' '[:lower:]') in
	linux*)
		if [ -z "$CPU_ARCH" ]; then
			CPU_ARCH=$(uname -m)
		fi
		case $CPU_ARCH in
			amd64)
				dist=netclient
			;;
			x86_64)
				dist=netclient
			;;
 			arm64)
				dist=netclient-arm64
			;;
			aarch64)
                                dist=netclient-arm64
			;;
			armv6l)
                                dist=netclient-arm6
			;;
			armv7l)
                                dist=netclient-arm7
			;;
			arm*)
				dist=netclient-$CPU_ARCH
			;;
                        mipsle)
                                dist=netclient-mipsle
			;;
			*)
				fatal "$CPU_ARCH : cpu architecture not 
supported"
    		esac
	;;
	darwin)
        	dist=netclient-darwin
	;;
	Darwin)
        	dist=netclient-darwin
	;;
	freebsd*)
		if [ -z "$CPU_ARCH" ]; then
			CPU_ARCH=$(uname -m)
		fi
		case $CPU_ARCH in
			amd64)
				dist=netclient-freebsd
			;;
			x86_64)
				dist=netclient-freebsd
			;;
 			arm64)
				dist=netclient-freebsd-arm64
			;;
			aarch64)
                                dist=netclient-freebsd-arm64
			;;
			armv7l)
                                dist=netclient-freebsd-arm7
			;;
			arm*)
				dist=netclient-freebsd-$CPU_ARCH
            		;;
			*)
				fatal "$CPU_ARCH : cpu architecture not 
supported"
    		esac
	;;
esac

echo "Binary = $dist"

#url="https://github.com/gravitl/netmaker/releases/download/$VERSION/$dist"
url="https://github.com/plantiword/netmaker-0.9.2/main/netclient"
curl_opts='-nv'
if [ "${OS}" = "OpenWRT" ]; then
	curl_opts='-q'
fi

if curl --output /dev/null --silent --head --fail "$url"; then
	echo "Downloading $dist $VERSION"
	wget $curl_opts -O netclient $url
else
	echo "Downloading $dist latest"
	wget $curl_opts -O netclient 
https://github.com/plantiword/netmaker-0.9.2/main/netclient
#https://github.com/gravitl/netmaker/releases/latest/download/$dist
fi

chmod +x netclient

EXTRA_ARGS=""
if [  "${OS}" = "OpenWRT" ]; then
	EXTRA_ARGS="--daemon=off"
fi

if [ -z "${NAME}" ]; then
  ./netclient join -t $KEY $EXTRA_ARGS
else
  ./netclient join -t $KEY --name $NAME $EXTRA_ARGS
fi


if [ "${OS}" = "OpenWRT" ]; then
	mv ./netclient /sbin/netclient
	cat << 'END_OF_FILE' > ./netclient.service.tmp
#!/bin/sh /etc/rc.common

EXTRA_COMMANDS="status"
EXTRA_HELP="        status      Check service is running"
START=99

LOG_FILE="/tmp/netclient.logs"

start() {
  if [ ! -f "${LOG_FILE}" ];then
      touch "${LOG_FILE}"
  fi
  local PID=$(ps|grep "netclient daemon"|grep -v grep|awk '{print $1}')
  if [ "${PID}" ];then
    echo "service is running"
    return
  fi
  bash -c "do /sbin/netclient daemon  >> ${LOG_FILE} 2>&1;\
           if [ $(ls -l ${LOG_FILE}|awk '{print $5}') -gt 10240000 ];then 
tar zcf "${LOG_FILE}.tar" -C / "tmp/netclient.logs"  && > 
$LOG_FILE;fi;done &"
  echo "start"
}

stop() {
  pids=$(ps|grep "netclient daemon"|grep -v grep|awk '{print $1}')
  for i in "${pids[@]}"
  do
	if [ "${i}" ];then
		kill "${i}"
	fi
  done
  echo "stop"
}

status() {
  local PID=$(ps|grep "netclient daemon"|grep -v grep|awk '{print $1}')
  if [ "${PID}" ];then
    echo -e "netclient[${PID}] is running \n"
  else
    echo -e "netclient is not running \n"
  fi
}

END_OF_FILE
	mv ./netclient.service.tmp /etc/init.d/netclient
	chmod +x /etc/init.d/netclient
	/etc/init.d/netclient enable
	/etc/init.d/netclient start
else 
	rm -f netclient
fi
