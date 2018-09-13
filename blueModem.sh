#! /bin/sh
#start bluetoothd
if ! pgrep bluetoothd 1> /dev/null || false ; then
    if [ ! -x /usr/sbin/bluetoothd ]; then
		echo "nie znaleziono /usr/sbin/bluetoothd "
		exit
    fi
    bluetoothd 
    sleep 2; #zeby zdazyl sie zakonczyc
    if ! pgrep bluetoothd 1> /dev/null || false ; then
		echo "nie udalo sie uruchomic bluetoothd (nie root lub nie uruchomione dbus?)"
		exit
    fi
    echo "uruchomiono bluetoothd"
else
    echo "bluetoothd juz byl uruchomiony"
fi

#wybor lokalnego urzadzenia
eval lokalneArr=( "$(ls /var/lib/bluetooth)" )
lokalne=""
if [ ${#lokalneArr[*]} == 0 ]; then
	echo "nie znaleziono urzadzenia bluetooth"
	exit
fi

if [ ${#lokalneArr[*]} == 1 ]; then
	lokalne=${lokalneArr[0]}
	echo "uzywam jedynego znalezionego urzadzenia $lokalne"
else
	echo "wybierz urzadzenie lokalne"
	i=0
	for dev in ${lokalneArr[*]} ; do
		((i++))
		echo $i $dev
	done
	read line
	lokalne=${lokalneArr[line-1]}
	if [ ${#lokalne} == 0 ]; then
		echo "zly wybor"
		exit
	else
		echo "wybrano $lokalne"
	fi
fi

#wybor zdalengo urzadzenia
hcitool scan
eval zdalneArr=( "$(cut -c 1-17 /var/lib/bluetooth/$lokalne/classes)" )
zdalne=""
if [ ${#zdalneArr[*]} == 0 ]; then
	echo "nie znaleziono urzadzenia bluetooth"
	exit
fi

if [ ${#zdalneArr[*]} == 1 ]; then
	zdalne=${zdalneArr[0]}
	echo "uzywam jedynego znalezionego urzadzenia $zdalne" 
else

    if [ $1 ]; then
	zdalne=${zdalneArr[$1]}    
    else
	echo "wybierz urzadzenie zdalne"
	i=0
	for dev in ${zdalneArr[*]} ; do
		((i++))
		echo $i $dev
	done
	read line
	zdalne=${zdalneArr[line-1]}
	if [ ${#zdalne} == 0 ]; then
		echo "zly wybor"
		exit
	else
		echo "wybrano $zdalne"
	fi
    fi
fi

#parowanie
pin="$(cat /var/lib/bluetooth/$lokalne/pincodes |grep $zdalne |cut -c 19-)"
if [ ${#pin} == 0 ]; then
	echo "podaj kod pin do sparowania tego urzadzenia"
	read line
	echo $zdalne $line >> /var/lib/bluetooth/$lokalne/pincodes
else
	echo "pin dla tego urzadzenia to $pin"
fi 

until hcitool cc $zdalne && hcitool auth $zdalne ; do
	echo "nieudana autentyfikacja - powtarzam";
	echo "jak nie dziala sproboj cofnac parowanie usuwajac komputer z telefonu"
done

#find channel
kanal="$(sdptool search --bdaddr $zdalne DUN |grep Channel |cut -c 14-)"
if [ ${#kanal} == 0 ]; then
	echo "nie znaleziono kanalu modemu tego urzadzenia zdalengo"
	exit 
else
    echo znaleziono modem na kanale $kanal
fi

#rfcomm

while  [ ! -e /dev/rfcomm0 ]; do
    if  pgrep rfcomm 1> /dev/null || false ; then
	echo uruchamiam probe polaczenia rfcomm
	
	rfcomm release rfcomm0;
    
	rfcomm  bind /dev/rfcomm0 $zdalne $kanal&
        sleep 1
    fi

    echo oczekiwanie na polaczenie
    sleep 1
    
done

    pppd call se
    

#wvdial / DNS 
#wvdial SE |& while read line; do
#	dns="$(echo $line |grep primary |grep DNS |grep address | cut -c 25- )"
#	if [ ${#dns} != 0 ]; then
#		echo "nameserver $dns" > /etc/resolv.conf
#		echo "zmieniono /etc/resolv ! $dns"
#		break
#	fi
#	echo $line 
#done

#if [ -x /dev/rfcomm0 ]; then
rfcomm release rfcomm0
#fi

##wvdial.conf######################################
# [Dialer Nokia] #PLAY
# Modem = /dev/rfcomm0
# Baud = 460800
# Init1 = ATZ
# Init2 = ATQ0 V1 E1 S0=0 &C1 &D2 +FCLASS=0
# init3 = AT+CGDCONT=1,"IP","internet","",0,0
# ISDN = 0
# Modem Type = Analog Modem
# Phone = *99#
# Username = play
# Password = play
# Stupid Mode = 1
# [Dialer SE] #ORANGE
# Init1 = ATZ
# Init2 = ATQ0 V1 E1 S0=0 &C1 &D2 +FCLASS=0
# Stupid Mode = 1
# Modem Type = Analog Modem
# ISDN = 0
# Phone = *99#
# Username = three
# Password = three
# Modem = /dev/rfcomm0
# Dial Command = ATDT
# Baud = 9600
####################################################

# cat /etc/ppp/chat-se 
#ABORT "NO DIALTONE"
#ABORT "NO CARRIER"
#ABORT "ERROR"
#ABORT "NO ANSWER"
#ABORT "BUSY"
#ABORT "Username/Password Incorrect"

##REPORT CONNECT ABORT BUSY 
#'' ATZ OK
##ATM1L1 OK 
##"ATQ0 V1 E1 S0=0 &C1 &D2 +FCLASS=0" OK 
##'AT+cgdcont=1,"IP","internet"' OK
#'ATDT*99#' CONNECT

# cat /etc/ppp/peers/se 
#rfcomm0 460800
##ttyACM1 460800
#connect '/usr/sbin/chat -v -e  -f /etc/ppp/chat-se'
##connect 'echo ATDT*99# > /dev/ttyACM1; sleep 4'
#noauth
#defaultroute
#debug debug debug
#nodetach
#usepeerdns
#persist
#noipdefault
#kdebug 4
#novj
#noccp