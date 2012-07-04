#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
### Class definition for Kalesto
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
class Kalesto

@@dev = ''

# Which instance variables can be read?

attr_reader :email, :passive, :host_type, :send_email, :send_sms, :smtp_server, :tftp
attr_reader :testval, :unit, :unit_id, :sineCounter, :heightCounter, :dev, :sendflag, :tftpflag

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Class method definitions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
def Kalesto.write_message_file(testval)
# Notes on the email format from Phil Knight (pjk@pol.ac.uk)
# Subject line:
# RADAR-K STNCODE MTRCODE with STNCODE  character(8) and MTRCODE  number(8)
# Use "<" so that the Perl can identify the data part.
# Use a name like RADAR-K so that Perl can identifiy the email as coming from
# the correct source.
# Use a station code
# Use a meter code
# For the above you could use made up ones like
# station code TEMP1234
# mtrcode code 12345678
  begin
    timeTxt = File.new("/home/kalesto/kalesto/data/time.txt", "w")

# Append data start character ">" for Perl processing into the database
    timeTxt.puts(">")

# Make overlapping 5 minute values so that we don't lose data
    if File.exists?("/home/kalesto/kalesto/data/lastOneMinuteData.txt") then
# Read the last one minute data values into a string 
      str = IO.read("/home/kalesto/kalesto/data/lastOneMinuteData.txt")
# Append the data string to the email message body so we have overlapping 5 minute values
      timeTxt.puts(str)
    end

# Read the one minute data values into a string  
    str = IO.read("/home/kalesto/kalesto/data/oneMinuteData.txt")
# Append the data string to the email message body   
    timeTxt.puts(str)

# Append termination character "<" for Perl processing into the database
    timeTxt.puts("<")

    if testval == "T" then
      timeTxt.puts("Testval: #{testval}")
      timeTxt.flush
    end

  rescue StandardError => bang
    print "Error in writing time.txt: " + bang + "\n"
    raise
  ensure
    timeTxt.close
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def Kalesto.initialise
# Set up the sensor interface
  begin
# setup units on sensor
    unit_str = IO.popen("echo 'u' > /dev/ttyS#{@@dev}", "w+")
    unit_str.close_write
    STDOUT.puts "Unit_str: #{unit_str.gets}"
    unit_str.close

# setup integration time on sensor (s = short, m = medium, l = long)
    int_str = IO.popen("echo 's' > /dev/ttyS#{@@dev}", "w+")
    int_str.close_write
    STDOUT.puts "Int_str: #{int_str.gets}"
    int_str.close

# Get info from sensor
    info_str = IO.popen("echo 'i' > /dev/ttyS#{@@dev}", "w+")
    info_str.close_write
    STDOUT.puts "Info_str: #{info_str.gets}"
    info_str.close

    STDOUT.flush

  rescue StandardError => bang
    print "Error in writing initialising sensor: " + bang + "\n"
    raise

  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
# Instance method definitions
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
def initialize(dev)
# Class variable
  @@dev = dev
# Set up a height counter variable so we can package up values every 5 minutes
  @heightCounter = 0
# Set flag which defines whether an email has been sent or not
  @sendflag = 1
# Set flag which defines whether an tftp has been successful or not
  @tftpflag = 1
# Set a default modification time for the touch.txt file of zero
  @mod_time = Time.at(0)
end

def read_env

  begin
# Read environment variables
    @email = ENV['email']
    @host_type = ENV['host_type']
    @passive = ENV['passive']
    @send_email = ENV['send_email']
    @send_sms = ENV['send_sms']
    @smtp_server = ENV['SMTPSERVER']
    @testval = ENV['testval']
    @unit = ENV['unit']
    @unit_id = ENV['unit_id']
    @tftp = ENV['tftp']
#    return @email, @host_type, @passive, @send_email, @send_sms, @smtp_server, @testval, @unit, @unit_id
    if @testval == "T" then
      STDOUT.puts "#{@unit} #{@unit_id} #{@email} ttyS#{@@dev} #{@host_type} Passive: #{@passive} TFTP: #{@tftp} Testval: #{@testval}"
      STDOUT.flush

# Set up a sine wave counter for test mode
      @sineCounter = 0
    end
  rescue StandardError => bang
    print "Error in reading evironment variables: " + bang + "\n"
    raise
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def update_height_counter

  begin
    height_counter = @heightCounter
    if height_counter == 4 then
      @heightCounter = 0
    else
      @heightCounter = height_counter + 1
    end
  rescue StandardError => bang
    print "Error in updating heightCounter: " + bang + "\n"
    raise
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def update_sineCounter

  begin
# 12 hours is 720 minutes
    sine_counter = @sineCounter
    if sine_counter <= 720 then
      @sineCounter = sine_counter + 1
    else
      @sineCounter = 0
    end
  rescue StandardError => bang
    print "Error in updating sineCounter: " + bang + "\n"
    raise
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def set_serial(testval)

  begin
# Set up the serial port to the correct baud rate: 9600 with 8N1
    if testval == "F" then

      IO.popen("stty -F /dev/ttyS#{@@dev} 1:0:cbd:0:0:0:0:0:0:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0"){}

      STDOUT.puts "Serial port is set"
      STDOUT.flush
    end

  rescue StandardError => bang
    print "Error in setting serial port: " + bang + "\n"
    raise
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def start_time(time)

  begin
# Don't start logging data until we are at the start of a minute
    while time.sec != 0
      time = Time.now
    end

    STDOUT.puts("First measurement time: #{time}")
    STDOUT.flush

    return time
  rescue StandardError => bang
    print "Error in starting time: " + bang + "\n"
    raise
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def get_data(passive, sensor)

  begin
# Get the data back from the Kalesto by sending an ascii "r" to the radar
# If we're in passive mode, no "r" is sent as that is initiated by the Orbcomm
# unit.
# "k" reads first KPSI pressure sensor, "p" reads second sensor
    case sensor
    when "radar": character = "r"
    when "p1": character = "k"
    when "p2": character = "p"
    else raise "Unknown sensor: #{sensor}"
    end
# Not in passive mode?
    if passive == "F" then
        IO.popen("echo '#{character}' > /dev/ttyS#{@@dev}"){}
    end

  rescue StandardError => bang
    print "Error in getting data from sensor #{sensor}: " + bang + "\n"
    raise
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def read_data(testval, sensor)

  begin
# Read into the variable "line" until some data actually appears. Once the
# string is sent from the Kalesto it is read and so "line" becomes non-empty
# and the truth test fails.
    line = ""
#### If nothing ever gets returned then it would never exit. 
#### Do we want this behaviour?
    while line == ""
# Not testing....
      if testval == "F" then

        sh = IO.popen("/bin/sh", "w+")
        sh.puts "read line < /dev/ttyS#{@@dev}; echo $line"
	sh.close_write
        line = sh.gets
        sh.close

# Testing....
      elsif testval == "T" then
# Test value
# Calculate a sine wave with a period of 12 hours and a range of 0 to 5000 mm
        sineVal = (2500*Math.sin(@sineCounter*Math::PI/360) + 2500).to_i

# Zero pad sineVal to 5 places
#        line = sprintf("%9s%05d%4s","0+005.65+",sineVal,"+000\n")

# Need different strings for the different sensors
        if sensor == "radar" then
          line = sprintf("%1s%05d%5s","+",sineVal,"+000+\n")
        elsif sensor == "p1" then
          line = sprintf("%1s%05d%11s","+",sineVal/1000,"+m+0.01+K+\n")
        elsif sensor == "p2" then
          line = sprintf("%1s%05d%11s","+",sineVal/1000,"+m+0.01+K+\n")
        else raise "Unknown sensor: #{sensor}"
        end

      else
        puts("Error in testval: #{testval}")
 
      end # if testing conditional

    end # while line = "" loop

# Radar returns string of the form: +99999+999+
# Pressure sensors return strings of the form: +9.999+9+99.999+9+
    if sensor == "radar" then
      junk1,height,status,junk2 = line.split("+")
# Remove leading zeros from height
      height = height.to_i
    elsif ((sensor == "p1") || (sensor == "p2")) then
      junk1,height,heightUnits,temperature, temperatureUnits,junk2 = line.split("+")
# Remove leading zeros from height & temperature
      height = height.to_f
      temperature = temperature.to_f
# Convert to integers
      height = height*1000
      height = height.to_i
      temperature = temperature*1000
      temperature = temperature.to_i
    else raise "Unknown sensor: #{sensor}"
    end

#### Need to sort this bit out! ####
# battery will be read by further call to the interface board over the serial port "b"?
    battery = 123 # no decimal point

    case sensor
    when "radar": return height, status, battery
    when "p1": return height, temperature
    when "p2": return height, temperature
    end

  rescue StandardError => bang
    print "Error in reading data: " + bang + "\n"
    raise
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def log_data(time, radarHeight, status, p1Height, p1Temperature, p2Height)

  begin  
    date = time.strftime("%d%m%Y%H%M")

# Temporary file for one minute means (removed every 5 minutes)
    oneMinuteDataTxt = File.new(
                       "/home/kalesto/kalesto/data/oneMinuteData.txt", "a")
# Pad height to five places if necessary to make it neat in the output
# Pad $sec to two places if necessary to make it neat in the output
# Append the data string to the local fast data file
    printf(oneMinuteDataTxt,
      "%12s%02d%1s%05d%1s%3s%1s%04d%1s%05d%1s%04d%1s",date,time.sec,"+",
      radarHeight,"+",status,"+",p1Height,"+",p1Temperature,"+",p2Height,"\n")
  rescue StandardError => bang
    print "Error in logging data: " + bang + "\n"
    raise
  ensure
    oneMinuteDataTxt.close
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def rename_logfile(time)

  begin
# Every half hour, move the one minute data log file to an old file which can be
# picked up remotely. This avoids any problem of data corruption if the
# file is remotely removed at the same time as data is being written.
# It also avoids the problem of filling up the Gumstix with one minute
# data if the connection goes down.
    minTest30 = time.min%30
    if minTest30 == 0 then
      File.rename("/home/kalesto/kalesto/data/oneMinuteData.log",
        "/home/kalesto/kalesto/data/oneMinuteData.old")
    end
  rescue StandardError => bang
    print "Error in renaming log file: " + bang + "\n"
    raise
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def send_email_message(testval)

  begin

# Send the email.
    send_from = @email
    send_to = @email
    message_subject = "RADAR-K #{@unit_id} 12345678"
    message_body = IO.read("/home/kalesto/kalesto/data/time.txt")
    msgstr = <<END_OF_MESSAGE
From: TPORT <#{send_from}>
To: Rothera Gumstix <#{send_to}>
Subject: #{message_subject}

END_OF_MESSAGE

    msgstr << message_body

    Net::SMTP.start(smtp_server, 25) do |smtp|
    smtp.send_message msgstr,
    send_from,
    send_to
    end
# Message sent so set sendflag to a true value
    @sendflag = 1

  rescue StandardError => bang
    print "Error in sending email: " + bang + "\n"
# Message not sent so set sendflag to false
    @sendflag = false
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def send_sms_message(rHeight, p1Height, p2Height, battery, p1Temperature, time)

# Use SMS test string
#:ID:GA-TAKO:DA:20061214143245:RA:0710707107071070710707107:P1:0710707107071070710707107:P2:0710707107071070710707107:BA:123:TE:1824;
  begin
    date = time.strftime("%d%m%Y%H%M")

    bgan = BGAN.new(@host_type)
    test_string = sprintf("%4s%7s%4s%12s%02d%4s%05d%05d%05d%05d%05d%4s%05d%05d%05d%05d%05d%4s%05d%05d%05d%05d%05d%4s%03d%4s%04d%1s",
      ':ID:', @unit_id,':DA:', date, time.sec, 
      ':RA:', rHeight[0], rHeight[1], rHeight[2], rHeight[3], rHeight[4],
      ':P1:', p1Height[0], p1Height[1], p1Height[2], p1Height[3], p1Height[4],
      ':P2:', p2Height[0], p2Height[1], p2Height[2], p2Height[3], p2Height[4],
      ':BA:', battery, ':TE:', p1Temperature, ';')
#    bgan.dial_number="+870772133573"
    bgan.dial_number="+870772134323"
    bgan.text_send(test_string)

  rescue StandardError => bang
    print "Error in sending sms: " + bang + "\n"
    raise
  ensure
    bgan.close
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def update_logfile
# Concatenate the 1 min txt file onto a log file and remove the old txt file
# Log-file for one minute means (removed periodically by remote ssh)
  begin
    oneMinuteDataLog = 
      File.new("/home/kalesto/kalesto/data/oneMinuteData.log", "a")
    str = IO.read("/home/kalesto/kalesto/data/oneMinuteData.txt")
    oneMinuteDataLog.puts(str)
  rescue StandardError => bang
    print "Error in generating oneMinuteData.log: " + bang + "\n"
    raise
  ensure
    oneMinuteDataLog.close
  end

# Copy oneMinuteData.txt file to lastOneMinuteData.txt file
  File.copy("/home/kalesto/kalesto/data/oneMinuteData.txt","/home/kalesto/kalesto/data/lastOneMinuteData.txt")
# Delete old oneMinuteData.txt file
  File.delete("/home/kalesto/kalesto/data/oneMinuteData.txt")
end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def mean_temperature(temperatureArray)
# Calculates the mean of the temperature array
  begin
# Remove any "nil" elements from the array
    temperatureArray.compact!
    @sum = 0
    temperatureArray.each { |x| @sum = @sum + x }
    mean = @sum/temperatureArray.length
    return mean
  rescue StandardError => bang
    print "Error in calculating mean temperature: " + bang + "\n"
    raise
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

# Setter function for sineCounter
def sineCounter=(new_sineCounter)

  begin
    @sineCounter = new_sineCounter
  rescue StandardError => bang
    print "Error in Kalesto sineCounter setter: " + bang + "\n"
    raise
  end

end

# Setter function for heightCounter
def heightCounter=(new_heightCounter)

  begin
    @heightCounter = new_heightCounter
  rescue StandardError => bang
    print "Error in Kalesto heightCounter setter: " + bang + "\n"
    raise
  end

end
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#  Copy the time.txt file to the tftp directory
def write_tftp_file()

  begin
    File.copy("/home/kalesto/kalesto/data/time.txt", "/var/lib/tftpboot/time.txt")
  rescue StandardError => bang
    print "Error in copying time.txt: " + bang + "\n"
    raise
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#  Gzip the time.txt file in the tftp directory
def zip_tftp_file()

  begin
#    Zlib::GzipWriter.open("/var/lib/tftpboot/time.txt.gz") do |gz|
#      gz.write(File.read("/var/lib/tftpboot/time.txt"))
#    end
     
# Delete old file
     if File.exists?("/var/lib/tftpboot/time.txt.gz") then
       File.delete("/var/lib/tftpboot/time.txt.gz")
     end
     system("/bin/gzip /var/lib/tftpboot/time.txt")

  rescue StandardError => bang
    print "Error in gzipping time.txt: " + bang + "\n"
    raise
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#  Check the modification time of the touched file in the tftp directory
def check_file_time()

  begin
    if File.exist?("/var/lib/tftpboot/touch.txt") then
      file_time = File.new("/var/lib/tftpboot/touch.txt").mtime
      
      if file_time > @mod_time then
        @mod_time = file_time
        @tftpflag = 1
      else
        @tftpflag = false
      end
    end

  rescue StandardError => bang
    print "Error in checking modification of touch.txt: " + bang + "\n"
    raise
  end

end

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

### Other message methods ####
#
# We place the file into the bootserver directory from where it can be picked
# up every 5 minutes by a cron job running a tftp client on a remote machine
#  system("cp -f /home/kalesto/kalesto/data/time.txt /var/lib/tftpboot/time.txt")

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end # Class definition Kalesto
