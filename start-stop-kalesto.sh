#!/bin/sh
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Starts or stops read_kalesto script.                                        #
# Usage: start-stop-kalesto.sh start                                          #
#        start-stop-kalesto.sh stop                                           #
#        start-stop-kalesto.sh restart                                        #
#                                                                             #
# Simon Holgate, May 2005                                                     #
# simonh@pol.ac.uk                                                            #
#                                                                             #
#*** Revision history ***                                                     #
#                                                                             #
# August 2005, added environment variables to make setup up easier on         #
# deployment.                                                                 #
#                                                                             #
# 19/08/05: Added passive mode for use with Orbcomm and extended timeout      #
# duration for use with new Basic Stamp chip                                  #
#                                                                             #
# 22/09/06: Added "portux" environment variable "PORT" and code               #
#                                                                             #
# 20/10/06: Added "send_email" & "send_sms" environment variables             #
#                                                                             #
# 05/03/07: Added "host_type" variable                                        #
#                                                                             #
# 08/03/07: Removed references to other platforms now we've settled on the    #
# Portux, and general tidy up                                                 #
#                                                                             #
# 13/08/07: Added delete of lastOneMinuteData.txt file                        #
#                                                                             #
#********************# # Set user variables here # #**************************#
# Is the unit NSLU2=SLUG or gumstix=GUMS or portux=PORT
unit="PORT"
# unit_id
unit_id="TPORT001"
# email address to send to: tguml@btconnect.com
email="someone@example.com"
# error reporting email address for restarts
error_email="someone@example.com"
# passive mode for use with Orbcomm: F=FALSE, T=TRUE
passive="F"
# testval, if TRUE, sends a test string instead of reading the Kalesto unit:
# F=FALSE, T=TRUE
testval="F"
# set SMTPSERVER so we know where to send emails
SMTPSERVER="smtp.bgan.inmarsat.com"
# Do we want to send emails?
send_email="T"
# Do we want to send sms messages?
send_sms="F"
# Are we using tftp?
tftp="F"
# What sort of BGAN unit? ("HUGHES", "TT" or "NERA")
host_type="HUGHES"
#******************# # End setting user variables # #********************#

# Export variables
export unit unit_id email error_email passive testval tftp\
       SMTPSERVER send_email send_sms host_type

#
start() {
 	echo -n "Starting read_kalesto.13.rb: "

# Set up log files
        rm -f /home/kalesto/kalesto/data/oneMinuteData.txt
        rm -f /home/kalesto/kalesto/data/lastOneMinuteData.txt
        cp -f /home/kalesto/kalesto/data/oneMinuteData.log\
 /home/kalesto/kalesto/data/oneMinuteData.log.bak
        rm -f /home/kalesto/kalesto/data/oneMinuteData.log

        cp -f /home/kalesto/kalesto/data/errors.txt\
 /home/kalesto/kalesto/data/errors.txt.bak
        rm -f /home/kalesto/kalesto/data/errors.txt
# Make note of start time in error log
        Date=`date`
        echo "Start time: $Date" > /home/kalesto/kalesto/data/errors.txt
	/home/kalesto/kalesto/bin/read_kalesto.rb\
	 >> /home/kalesto/kalesto/data/errors.txt 2>&1 &
# Store the process id in a file so we can kill it later
        jobs -p > /home/kalesto/kalesto/pid.kalesto

# Send email notification of starting
        cat > /home/kalesto/kalesto/start.txt <<-EOF
	Subject: Starting Kalesto RADAR-K $unit_id at $Date

	Starting Kalesto RADAR-K $unit_id at $Date
EOF

# "Start" message sending
        if [ "$unit" = "PORT" ]
        then
          Subject="Starting Kalesto RADAR-K $unit_id at $Date"
          Message="Starting Kalesto RADAR-K $unit_id at $Date"
             /home/kalesto/kalesto/bin/smtp.rb $SMTPSERVER \
             $error_email $email "$Subject" "$Message"
        fi

	echo "OK"
}
stop() {
	echo -n "Stopping read_kalesto.13.rb: "
# Read process id from file and use it to kill the script nicely
        read pid1 pid2 < /home/kalesto/kalesto/pid.kalesto
        if [ -z $pid2 ]
        then
	  kill $pid1
        fi

        rm -f /home/kalesto/kalesto/pid.kalesto
# Note stop time in error log
        Date=`date`
        echo "Stop time: $Date" >> /home/kalesto/kalesto/data/errors.txt 

# Send email notification of stopping
        cat > /home/kalesto/kalesto/stop.txt <<-EOF
	Subject: Stopping Kalesto RADAR-K $unit_id at $Date
	
	Stopping Kalesto RADAR-K $unit_id at $Date
EOF

# "Stop" message sending 
        if [ "$unit" = "PORT" ]
        then
          Subject="Stopping Kalesto RADAR-K $unit_id at $Date"
          Message="Stopping Kalesto RADAR-K $unit_id at $Date"
             /home/kalesto/kalesto/bin/smtp.rb $SMTPSERVER \
             $error_email $email "$Subject" "$Message"

        fi
 
	echo "OK"
}
restart() {
	stop
	start
}


# Check which part of the script to call:

case "$1" in
  start)
  	start
	;;
  stop)
  	stop
	;;
  restart|reload)
  	restart
	;;
  *)
	echo $" Usage: $0 {start|stop|restart}"
	exit 1
esac

exit $?

