#!/usr/local/bin/ruby
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#                                                                             #
# Script to read data strings from a Kalesto radar gauge and send the string  #
# to given recipients.                                                        #
#                                                                             #
# Usage: Requires starting and stopping with start-stop-kalesto.sh which sets #
#        environment variables                                                #
#                                                                             #
# Simon Holgate (simonh@pol.ac.uk) Feb 2007                                   #
#                                                                             #
#                                                                             #
#*** Revision history ***                                                     #
#                                                                             #
# August 2005: Added use of environment variables in start-stop-kalesto.sh    #
# to make setup easier on deployment especially for development of the NSLU2  #
# platform                                                                    #
#                                                                             #
# 19/08/05: Added passive mode for use with Orbcomm and extended timeout      #
# duration for use with new Basic Stamp chip                                  #
#                                                                             #
# 22/08/06: Added rsync capability to reflect new Gumstix software and get    #
# around the problem of waiting for emails to arrive.                         #
#                                                                             #
# 6/9/06: Added tftp capability to try and reduce bandwidth consumption       #
#                                                                             #
# 8/9/06: Changed tftp capability to try use bootserver on gumstix rather     #
# externally to help reduce security fears                                    #
#                                                                             #
# 22/9/06: Added code for Portux unit                                         #
#                                                                             #
# 20/10/06: Removed 5 minute averaging code                                   #
#                                                                             #
# February 2007: Complete rewrite in Ruby                                     #
# We have standardised on the Portux so no need for alternative platforms now #
# All email and sms handled from within Ruby                                  #
#                                                                             #
# 27/02/07: Rewrote in ruby with methods for each section to make maintenance #
# easier and added some error handling                                        #
#                                                                             #
# 05/03/07: Corrected errors in methods by introducing Kalesto class          #
#                                                                             #
# 06/03/07: Removed Kalesto class into separate file                          #
#                                                                             #
# 13/06/07: Added code for pressure sensors in addition to radar              #
#                                                                             #
# 14/06/07: Added back the possibility of placing files on TFTP server        #
#                                                                             #
# 13/08/07: Added facility of over-lapping 5 minute values so that data       #
# losses due to BGAN outages are reduced                                      #
#                                                                             #
# 15/08/07: Added checking of timestamp of the touch.txt file that is         #
# each time a data file is downloaded                                         #
#                                                                             #
# 16/08/07: Restored overlapping files in place of timestamp method and added #
# gzip compression of tftp files                                              #
#                                                                             #
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#### 
#### Beginning of main script
####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

### Add some rudimentary, catch all error trapping ###
begin

# Class file defining all the BGAN communications
  require '/home/kalesto/kalesto/bin/bgan'
# Class file defining all Kalesto methods
  require '/home/kalesto/kalesto/bin/kalesto'
  
  require 'net/smtp'
  require 'ftools'
  require 'zlib'

#************************# # Define variables here # #************************#
# Serial device on Portux is ttyS2
  kalesto = Kalesto.new("2")

# Read environment variables
  kalesto.read_env

# Set up the sensor interface
  if !(kalesto.testval <=> "T")
    Kalesto.initialise
  end

# Set our looping variable - we're going to loop indefinitely
  i=0

# Set up height and temperature variables so we can package up values every 5 minutes
  radarHeight = Array.new(5)
  p1Height = Array.new(5)
  p2Height = Array.new(5)
  p1Temperature = Array.new(5)
  p2Temperature = Array.new(5)

#***********************# # End defining variables # #************************#

#### Initialisation ####
# Set up the serial port to the correct baud rate: 9600 with 8N1
  kalesto.set_serial(kalesto.testval)

# Get the start time and don't start logging data until we are at the 
# start of a minute
  time = kalesto.start_time(Time.now)

##### End initialisation ####

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#                                                                          #
# Main loop                                                                #
#                                                                          #
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

  while i == 0 # Loop forever

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Start of time checking                                                   #
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Check whether it is time to read the data
# Read every minute (with a 1 second lee-way)
    if time.sec <= 2 then

# Get the data back from the sensor interface
# Sensor can be "radar", "p1" or "p2" for the first and second pressure sensors
# radar
      kalesto.get_data(kalesto.passive, "radar")

# Read the data. Store the height in an array.
      radarHeight[kalesto.heightCounter], status, battery =
        kalesto.read_data(kalesto.testval, "radar")
# p1
      kalesto.get_data(kalesto.passive, "p1")

# Read the data. Store the height in an array.
      p1Height[kalesto.heightCounter], p1Temperature[kalesto.heightCounter] =
        kalesto.read_data(kalesto.testval, "p1")

# p2
      kalesto.get_data(kalesto.passive, "p2")

# Read the data. Store the height in an array.
      p2Height[kalesto.heightCounter], p2Temperature[kalesto.heightCounter] =
        kalesto.read_data(kalesto.testval, "p2")

# Make sure that we have data files to store values locally
      kalesto.log_data(time, radarHeight[kalesto.heightCounter], status,
        p1Height[kalesto.heightCounter], p1Temperature[kalesto.heightCounter], 
        p2Height[kalesto.heightCounter])


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Start of message sending                                                 #
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

# Every five minutes, send a message with the last 5 one minute values
      minTest5 = time.min%5
      if minTest5 == 0 then

# Write data file regardless
        Kalesto.write_message_file(kalesto.testval)

### Are we putting file on tftp server? ###
        if kalesto.tftp == "T" then
          kalesto.write_tftp_file
          kalesto.zip_tftp_file
        end
### End of "Do we put file on tftp server?" ###

### Are we sending email? ###
        if kalesto.send_email == "T" then
          kalesto.send_email_message(kalesto.testval)
        end
### End of "Do we send email?" ###

### Start of SMS sending ###
        if kalesto.send_sms == "T" then
# Calculate the mean temperature for the 5 minutes
          meanTemperature = kalesto.mean_temperature(p1Temperature)

          kalesto.send_sms_message(radarHeight, p1Height, p2Height, 
            battery, meanTemperature, time)
        end
### End of SMS sending ####

# Concatenate the 1 min txt file onto a log file and remove the old txt file 
# unless email hasn't been sent
        if kalesto.sendflag then
          kalesto.update_logfile
        end
        
      end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# End of message sending                                                   #
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

# Update the counter of lines read
      kalesto.update_height_counter

      if kalesto.testval == "T" then
        kalesto.update_sineCounter
      end

# Go to sleep for 5 seconds until it's nearly time for the next reading
      sleep 5

      time = Time.now
    else
# Check periodically whether we are close to the data check time
      sleep 1

      time = Time.now
    end
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# End of time checking                                                     #
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

  end
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# End of main loop                                                         #
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

rescue StandardError
  print "Error running script: " + $! + "\n"
  raise
end
### End of error trapping ###


#### End of script ####
