#!/bin/bash
#===================================
# startup 
#===================================
PID=$$
PID_CHILD_1=""
PID_CHILD_2=""
IS_START=0;
DATE=`date`;
SESSION_ID=$PID
STREAM_PIPE=""
LOG_FILE="/usr/local/owsline/asterisk/log/mpg123.log"
IS_START=0;
BIN_CAT=/bin/cat
BIN_WGET=/usr/bin/wget
BIN_MPG123=/usr/bin/mpg123.bin
BIN_MPLAYER=/usr/bin/mplayer
BIN_MADPLAY=/usr/local/bin/madplay
BIN_VLC=clvc
#===================================



#===================================
# extract zenofon URL from arguments
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
# understand zenofon url
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
	STREAM_URL=${STREAM_RAW_URL:17}
fi
if [[ $STREAM_RAW_URL == ZENOFON:TEST1:* ]]
then
	STREAM_TYPE="TEST1"
	STREAM_URL=${STREAM_RAW_URL:14}
fi
if [[ $STREAM_RAW_URL == ZENOFON:TEST2:* ]]
then
	STREAM_TYPE="TEST2"
	STREAM_URL=${STREAM_RAW_URL:14}
fi
SESSION_ID=$STREAM_TYPE
#===================================





#===================================
# cleanup  function (and kill trap)
#===================================
function clean_up()
{
	if [ "$IS_START" == "1" ]; then
		if [ "$PID_CHILD_1" != "" ]; then
			kill -9 $PID_CHILD_1 >/dev/null 2>/dev/null
		fi
		if [ "$PID_CHILD_2" != "" ]; then
			kill -9 $PID_CHILD_2 >/dev/null 2>/dev/null
		fi
		if [ "$STREAM_PIPE" != "" ]; then
			rm -f $STREAM_PIPE >/dev/null 2>/dev/null
		fi
	fi
	echo "$DATE|$SESSION_ID|CLEANUP|$STREAM_TYPE|$PID_CHILD_1|$PID_CHILD_2|$STREAM_URL|$STREAM_PIPE" >> $LOG_FILE
	exit 0
}
trap clean_up SIGHUP SIGINT SIGQUIT SIGILL SIGTRAP SIGABRT SIGFPE SIGKILL SIGBUS SIGSEGV SIGSYS SIGPIPE SIGALRM SIGTERM SIGUSR1 SIGUSR2 SIGCHLD SIGWINCH SIGURG SIGSTOP SIGTSTP SIGCONT SIGTTIN SIGTTOU SIGVTALRM SIGPROF SIGXCPU SIGXFSZ
#===================================




#===================================
# Main loop
#===================================
#
echo "$DATE|$SESSION_ID|=======================================================" >> $LOG_FILE
echo "$DATE|$SESSION_ID|MPG123_START|$0 $1 $2 $3 $4 $5 $6 $7 $8 $9" >> $LOG_FILE
echo "$DATE|$SESSION_ID|MPG123_START|STREAM_RAW_URL=$STREAM_RAW_URL" >> $LOG_FILE
echo "$DATE|$SESSION_ID|MPG123_START|STREAM_TYPE=$STREAM_TYPE" >> $LOG_FILE
echo "$DATE|$SESSION_ID|MPG123_START|STREAM_URL=$STREAM_URL" >> $LOG_FILE
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
	echo "$DATE|$SESSION_ID|SHOUTCAST_START|$PID_CHILD_1|$STREAM_URL|$BIN_MPG123 -q -s -m -r 8000 -b 512 --loop -1 $STREAM_URL " >> $LOG_FILE
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
	STREAM_PIPE=/tmp/stream.$PID.$RANDOM
	rm -f $STREAM_PIPE >/dev/null 2>/dev/null
	mkfifo $STREAM_PIPE >/dev/null 2>/dev/null
	if [ -e "$STREAM_PIPE" ]; then
		#
		# Start encoder
		#-really-quiet -quiet -vo null -vc null -ao pcm:fast  -af resample=8000,channels=1,format=mulaw -ao pcm:file=$STREAM_PIPE $STREAM_URL 
		#$BIN_MPLAYER -really-quiet -quiet -vo null -vc null -af resample=8000,channels=1,format=mulaw -ao pcm:file=$STREAM_PIPE $STREAM_URL >/dev/null 2>/dev/null &
 		#$BIN_MPLAYER -vo null -vc null -af resample=8000,channels=1,format=mulaw -ao pcm:nowaveheader:file=$STREAM_PIPE $STREAM_URL >>$LOG_FILE 2>>$LOG_FILE &
		$BIN_MPLAYER -loop 0 -vo null -vc null -ao pcm:fast -af resample=8000,channels=1,format=mulaw -ao pcm:waveheader:file=$STREAM_PIPE $STREAM_URL >/dev/null 2>/dev/null &
		PID_CHILD_1=$!
		#
		# Start deliver
		$BIN_CAT $STREAM_PIPE  2>/dev/null &
		PID_CHILD_2=$!	
		#
		# log 
		DATE=`date`;
		echo "$DATE|$SESSION_ID|MMS_START|$PID_CHILD_1|$PID_CHILD_2|$STREAM_PIPE|$STREAM_URL|$BIN_MPLAYER -loop 0 -vo null -vc null -ao pcm:fast -af resample=8000,channels=1,format=mulaw -ao pcm:waveheader:file=$STREAM_PIPE $STREAM_URL" >> $LOG_FILE
		#
		# wait encoder finish;
		IS_START=1
		wait $PID_CHILD_1
	else 
		DATE=`date`;
		echo "$DATE|$SESSION_ID|MMS_MKFIFO_ERROR|$STREAM_PIPE|$STREAM_URL" >> $LOG_FILE
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
	echo "$DATE|$SESSION_ID|MP3_START|$PID_CHILD_1|$STREAM_URL|$BIN_MPG123 -q -s -m -r 8000 -b 512 --loop -1 $STREAM_URL" >> $LOG_FILE
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
	echo "$DATE|$SESSION_ID|PLAYLIST_START|$PID_CHILD_1|$STREAM_URL|$BIN_MPG123 -q -s -m -r 8000 -f 8192 -b 0 -@ $STREAM_URL " >> $LOG_FILE
	#
	# wait encoder finish;
	IS_START=1
	wait $PID_CHILD_1
fi 
#
# ------------------------
# handler TEST1 start 
# ------------------------
if [ "$STREAM_TYPE" == "TEST1" ]; then
	#
	# we have values. lets create pipe
	STREAM_PIPE=/tmp/stream.$PID.$RANDOM
	rm -f $STREAM_PIPE >/dev/null 2>/dev/null
	mkfifo $STREAM_PIPE >/dev/null 2>/dev/null
	if [ -e "$STREAM_PIPE" ]; then
		#
		# Start encoder
		#$BIN_MPLAYER -loop 0              -vo null -vc null -ao pcm:fast -af resample=8000,channels=1,format=mulaw -ao pcm:waveheader:file=$STREAM_PIPE $STREAM_URL >/dev/null 2>/dev/null &
		$BIN_MPLAYER  -really-quiet -quiet -vo null -vc null -ao pcm:fast -af resample=8000,channels=1,format=mulaw -ao pcm:file=$STREAM_PIPE $STREAM_URL >/dev/null 2>/dev/null &
		PID_CHILD_1=$!
		#
		# Start deliver
		$BIN_CAT $STREAM_PIPE  2>/dev/null &
		PID_CHILD_2=$!	
		#
		# log 
		DATE=`date`;
		echo "$DATE|$SESSION_ID|TEST_1_START|$PID_CHILD_1|$PID_CHILD_2|$BIN_MPLAYER  -really-quiet -quiet -vo null -vc null -ao pcm:fast -af resample=8000,channels=1,format=mulaw -ao pcm:file=$STREAM_PIPE $STREAM_URL " >> $LOG_FILE
		#
		# wait encoder finish;
		IS_START=1
		wait $PID_CHILD_1
	else 
		DATE=`date`;
		echo "$DATE|$SESSION_ID|TEST_1_MKFIFO_ERROR|$STREAM_PIPE|$STREAM_URL" >> $LOG_FILE
	fi 
fi 
#
# ------------------------
# handler TEST2 start 
# ------------------------
if [ "$STREAM_TYPE" == "TEST2" ]; then
	#
	# Start encoder
	IS_START=1;
	#su -c "/usr/bin/cvlc --no-video --verbose=0 --quiet --no-stats --loop --aout=file --sout-mono-downmix --aout-rate=8000 --audiofile-format=s8 --audiofile-file=- --hq-resampling --volume=10 $STREAM_URL 2>/dev/null " neyfrota 
	su -c "/usr/bin/cvlc --no-video --loop --aout=file  --audiofile-file=- $STREAM_URL " radio 2>> $LOG_FILE
	PID_CHILD_1=$!
	#
	# log 
	DATE=`date`;
	echo "$DATE|$SESSION_ID|TEST_2_START|$PID_CHILD_1|/usr/bin/cvlc --no-video --loop --aout=file  --audiofile-file=- $STREAM_URL " >> $LOG_FILE
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
	echo "$DATE|$SESSION_ID|UNKNOWN_START|$1 $2 $3 $4 $5 $6 $7 $8 $9" >> $LOG_FILE
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
exit 0;
#===================================






