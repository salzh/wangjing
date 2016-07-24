#!/bin/bash
echo "MPG123 COMMAND $0 $1 $2 $3 $4 $5 $6 $7 $8 $9 " >> /usr/local/conference_radio/asterisk/log/mpg123.log
#/usr/bin/mpg123.bin $1 $2 $3 $4 $5 $6 $7 $8 $9 
#exit;

#===================================
# startup 
#===================================
PID=$$
STREAM_PIPE=/tmp/stream.$PID.$RANDOM
LOG_FILE="/usr/local/conference_radio/asterisk/log/mpg123.log"
IS_START=0;
BIN_CAT=/bin/cat
BIN_WGET=/usr/bin/wget
BIN_MPG123=/usr/bin/mpg123.bin
BIN_MPLAYER=/usr/bin/mplayer
BIN_MADPLAY=/usr/local/bin/madplay
#===================================



#===================================
# search zenofon URL from arguments
#===================================
STREAM_RAW_URL=""
if [[ $0 == ZENOFON:* ]] 
then
	STREAM_RAW_URL=$0
fi
if [[ $1 == ZENOFON:* ]]
then
	STREAM_RAW_URL=$1
fi
if [[ $2 == ZENOFON:* ]]
then
	STREAM_RAW_URL=$2
fi
if [[ $3 == ZENOFON:* ]]
then
	STREAM_RAW_URL=$3
fi
if [[ $4 == ZENOFON:* ]]
then
	STREAM_RAW_URL=$4
fi
if [[ $5 == ZENOFON:* ]]
then
	STREAM_RAW_URL=$5
fi
if [[ $6 == ZENOFON:* ]]
then
	STREAM_RAW_URL=$6
fi
if [[ $7 == ZENOFON:* ]]
then
	STREAM_RAW_URL=$7
fi
if [[ $8 == ZENOFON:* ]]
then
	STREAM_RAW_URL=$8
fi
if [[ $9 == ZENOFON:* ]]
then
	STREAM_RAW_URL=$9
fi
#===================================



#===================================
# decide URL type
#===================================
STREAM_TYPE="UNKNOWN"
if [[ $STREAM_RAW_URL == ZENOFON:SHOUTCAST:* ]]
then
	STREAM_TYPE="SHOUTCAST"
	STREAM_URL=${STREAM_RAW_URL:18}
fi
if [[ $STREAM_RAW_URL == ZENOFON:MMS:* ]]
then
	STREAM_TYPE="MMS"
	STREAM_URL=${STREAM_RAW_URL:12}
fi
if [[ $STREAM_RAW_URL == ZENOFON:MP3:* ]]
then
	STREAM_TYPE="MP3"
	STREAM_URL=${STREAM_RAW_URL:12}
fi
if [[ $STREAM_RAW_URL == ZENOFON:PLAYLIST:* ]]
then
	STREAM_TYPE="MP3PLS"
	STREAM_URL=${STREAM_RAW_URL:15}
fi
echo "STREAM_RAW_URL=$STREAM_RAW_URL";
echo "STREAM_TYPE=$STREAM_TYPE";
echo "STREAM_URL=$STREAM_URL";
#exit;
#===================================



#===================================
# cleanup  function (and kill trap)
#===================================
function clean_up()
{
	#
	# ------------------------
	# handler SHOUTCAST stop
	# ------------------------
	if [ "$STREAM_TYPE" == "SHOUTCAST" ]; then
		#
		# log 
		if [ "$IS_START" == "1" ]; then
			DATE=`date`;
			echo "$DATE|SHOUTCAST_STOP_OK|$PID|$PID_CHILD_1|$STREAM_URL" >> $LOG_FILE
		fi
		#
		# kill child_1;
		kill -9 $PID_CHILD_1 >/dev/null 2>/dev/null
	fi 
	#
	# ------------------------
	# handler MMS stop
	# ------------------------
	if [ "$STREAM_TYPE" == "MMS" ]; then
		#
		# log 
		if [ "$IS_START" == "1" ]; then
			DATE=`date`;
			echo "$DATE|MMS_STOP_OK|$PID|$PID_CHILD_1|$PID_CHILD_2|$STREAM_PIPE|$STREAM_URL" >> $LOG_FILE
		fi
		#
		# kill child_[1/2];
		kill -9 $PID_CHILD_2 >/dev/null 2>/dev/null
		kill -9 $PID_CHILD_1 >/dev/null 2>/dev/null
		#
		# remove pipe
		rm -f $STREAM_PIPE >/dev/null 2>/dev/null
	fi 
	#
	#
	# ------------------------
	# handler MP3 stop
	# ------------------------
	if [ "$STREAM_TYPE" == "MP3" ]; then
		#
		# log 
		if [ "$IS_START" == "1" ]; then
			DATE=`date`;
			echo "$DATE|MP3_STOP_OK|$PID|$PID_CHILD_1|$STREAM_URL" >> $LOG_FILE
		fi
		#
		# kill child_1;
		kill -9 $PID_CHILD_1 >/dev/null 2>/dev/null
	fi 
	#
	# ------------------------
	# handler PLAYLIST stop
	# ------------------------
	if [ "$STREAM_TYPE" == "PLAYLIST" ]; then
		#
		# log 
		if [ "$IS_START" == "1" ]; then
			DATE=`date`;
			echo "$DATE|PLAYLIST_STOP_OK|$PID|$PID_CHILD_1|$STREAM_URL" >> $LOG_FILE
		fi
		#
		# kill child_1;
		kill -9 $PID_CHILD_1 >/dev/null 2>/dev/null
	fi 
	#
	# ------------------------
	# handler UNKNOWN stop
	# ------------------------
	if [ "$STREAM_TYPE" == "UNKNOWN" ]; then
		#
		# log 
		if [ "$IS_START" == "1" ]; then
			DATE=`date`;
			echo "$DATE|UNKNOWN_STOP_OK|$PID|$PID_CHILD_1|$STREAM_URL" >> $LOG_FILE
		fi
		#
		# kill child_1;
		kill -9 $PID_CHILD_1 >/dev/null 2>/dev/null
	fi 
	#
	# ------------------------
	# finish 
	# ------------------------
	#kill -9 $PID >/dev/null 2>/dev/null
	exit 0
}
trap clean_up SIGHUP SIGINT SIGQUIT SIGILL SIGTRAP SIGABRT SIGFPE SIGKILL SIGBUS SIGSEGV SIGSYS SIGPIPE SIGALRM SIGTERM SIGUSR1 SIGUSR2 SIGCHLD SIGWINCH SIGURG SIGSTOP SIGTSTP SIGCONT SIGTTIN SIGTTOU SIGVTALRM SIGPROF SIGXCPU SIGXFSZ
#===================================




#===================================
# Main loop
#===================================
#
# ------------------------
# handler SHOUTCAST start 
# ------------------------
if [ "$STREAM_TYPE" == "SHOUTCAST" ]; then
	#
	# Start encoder
	#$BIN_MPG123 -q -s -m -r 8000 -f 8192 -b 0 $STREAM_URL 2>/dev/null &
	$BIN_MPG123 -q -s -m -r 8000 -f 8192 -b 0 --loop -1 $STREAM_URL 2>/dev/null &
	PID_CHILD_1=$!
	#
	# log 
	DATE=`date`;
	echo "$DATE|SHOUTCAST_START_OK|$PID|$PID_CHILD_1|$STREAM_URL| $BIN_MPG123 -q -s -m -r 8000 -b 512 --loop -1 $STREAM_URL " >> $LOG_FILE
	#
	# wait encoder finish;
	IS_START=1
	wait $PID_CHILD_1
fi 
#
# ------------------------
# handler MMS start 
# ------------------------
if [ "$STREAM_TYPE" == "MMS" ]; then
	#
	# we have values. lets create pipe
	rm -f $STREAM_PIPE
	mkfifo $STREAM_PIPE
	if [ -e "$STREAM_PIPE" ]; then
		#
		# Start encoder
		#-really-quiet -quiet -vo null -vc null -ao pcm:fast  -af resample=8000,channels=1,format=mulaw -ao pcm:file=$STREAM_PIPE $STREAM_URL 
		#$BIN_MPLAYER -really-quiet -quiet -vo null -vc null -af resample=8000,channels=1,format=mulaw -ao pcm:file=$STREAM_PIPE $STREAM_URL >/dev/null 2>/dev/null &
 		#$BIN_MPLAYER -vo null -vc null -af resample=8000,channels=1,format=mulaw -ao pcm:nowaveheader:file=$STREAM_PIPE $STREAM_URL >>$LOG_FILE 2>>$LOG_FILE &
		$BIN_MPLAYER -loop 0 -vo null -vc null -af resample=8000,channels=1,format=mulaw -ao pcm:waveheader:file=$STREAM_PIPE $STREAM_URL >/dev/null 2>/dev/null &
		PID_CHILD_1=$!
		#
		# Start deliver
		$BIN_CAT $STREAM_PIPE  2>/dev/null &
		PID_CHILD_2=$!	
		#
		# log 
		DATE=`date`;
		echo "$DATE|MMS_START_OK|$PID|$PID_CHILD_1|$PID_CHILD_2|$STREAM_PIPE|$STREAM_URL" >> $LOG_FILE
		#
		# wait encoder finish;
		IS_START=1
		wait $PID_CHILD_1
	else 
		DATE=`date`;
		echo "$DATE|MMS_START_ERROR|$PID|$PID_CHILD_1|$PID_CHILD_2|$STREAM_PIPE|$STREAM_URL" >> $LOG_FILE
	fi 
fi 
#
# ------------------------
# handler MP3 start 
# ------------------------
if [ "$STREAM_TYPE" == "MP3" ]; then
	#
	# Start encoder
	#$BIN_WGET -q -O - $3 | $BIN_MADPLAY -Q -z -o raw:- --mono -R 8000 -a +3 - &
	#$BIN_MPG123 -q -s -m -r 8000 -f 8192 -b 0 $STREAM_URL 2>/dev/null &
	$BIN_MPG123 -q -s -m -r 8000 -b 512 --loop -1 $STREAM_URL 2>/dev/null &
	PID_CHILD_1=$!
	#
	# log 
	DATE=`date`;
	echo "$DATE|MP3_START_OK|$PID|$PID_CHILD_1|$STREAM_URL" >> $LOG_FILE
	#
	# wait encoder finish;
	IS_START=1
	wait $PID_CHILD_1
fi 
#
# ------------------------
# handler PLAYLIST start 
# ------------------------
if [ "$STREAM_TYPE" == "PLAYLIST" ]; then
	#
	# Start encoder
	$BIN_MPG123 -q -s -m -r 8000 -f 8192 -b 0 -@ $STREAM_URL 2>/dev/null &
	PID_CHILD_1=$!
	#
	# log 
	DATE=`date`;
	echo "$DATE|PLAYLIST_START_OK|$PID|$PID_CHILD_1|$STREAM_URL" >> $LOG_FILE
	#
	# wait encoder finish;
	IS_START=1
	wait $PID_CHILD_1
fi 
#
# ------------------------
# unknown stream
# ------------------------
if [ "$STREAM_TYPE" == "UNKNOWN" ]; then
	#
	# Start encoder with standard values
	$BIN_MPG123 $1 $2 $3 $4 $5 $6 $7 $8 $9 2>/dev/null &
	PID_CHILD_1=$!
	#
	# log 
	DATE=`date`;
	echo "$DATE|UNKNOWN_START_OK|$1 $2 $3 $4 $5 $6 $7 $8 $9" >> $LOG_FILE
	#
	# wait encoder finish;
	IS_START=1
	wait $PID_CHILD_1
fi 
#
# ------------------------
# cleanup and finish
# ------------------------
clean_up
#===================================


