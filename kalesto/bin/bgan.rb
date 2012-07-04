class BGAN

  attr_reader :dial_number, :host_ip, :host_type, :port_number, :service_centre, :cgact
  attr_reader :cgdcont_str, :cgact_str
  
  def initialize(host_type)

    begin
      require 'net/telnet'

      @host_type = host_type
      # Set default service centre number
      @service_centre = "+870772001799"
      # Set default number to send messages to
      @dial_number = "+870772133573"

      case @host_type
      when "HUGHES"
        @host_ip = '192.168.128.100'
        @port_number = 1829
      when "NERA"
        @host_ip = '192.168.0.1'
        @port_number = 9998
      when "TT"
        @host_ip = '192.168.0.1'
        @port_number = 5454
      else
        print "Unknown host type: #{@host_type}"
      end

      @tn = Net::Telnet.new( 'Host' => @host_ip,
                             'Port' => @port_number)


    rescue TimeoutError, StandardError => bang
      print "Error in BGAN initialisation: " + bang + "\n"
      raise
    end

  end

  def reset
    begin
# Do reset - this should bring up the unit in pointing mode. We then need to
# contact it and set it to register with the network etc.
      @tn.cmd( 'String'        =>      "at+cfun=1,1",
              'Match'         =>      /OK/,
              'Timeout'       =>      2)

    rescue TimeoutError, StandardError => bang
      print "Error in BGAN reset: " + bang + "\n"
      raise
    end
      
  end

  def text_send(message)

    begin
# Put unit into SMS mode
      @tn.cmd( 'String'        =>      "at+cmgf=1",
               'Match'         =>      /OK/,
               'Timeout'       =>      2)      
# Set service centre number
      @tn.cmd( 'String'        =>      %/at+csca="#@service_centre"/,
               'Match'         =>      /OK/,
               'Timeout'       =>      2)

      @tn.cmd( 'String'        =>      %/at+cmgs="#@dial_number"\r/,
               'Match'         =>      />/,
               'Timeout'       =>      20)

      data_string = ""
      data_string << message
# Append a Ctrl-z to the string to finish...
      data_string << 26
#    print data_string
      @tn.cmd( 'String'        =>      data_string,
              'Match'         =>      /OK/,
              'Timeout'       =>      30)

    rescue TimeoutError, StandardError => bang
      print "Error in BGAN text_send: " + bang + "\n"
      raise
    end

  end

  def pdu_send(message)

    begin

# Temporary array
      b = Array.new
      encoded_string = Array.new
# Counters
      i = 0
      j = 0

      message.each_byte { |d|
        b[i] = d.to_s(2)
        if j>0 then
          encoded_string[i-1] = b[i][(7-j)..6]<<b[i-1]
          encoded_string[i-1] = (encoded_string[i-1].to_i(2)).to_s(16)
          if j>=7
            j=0
            next
          end
          b[i] = b[i][0..(6-j)]
        end
        i=i+1
        j=j+1

      }
      encoded_string[i] = b[i-1]
      encoded_string[i] = (encoded_string[i].to_i(2)).to_s(16)

# Now construct the PDU message.
#
# Length of SMSC information. Here the length is 0, which means that the SMSC stored in the phone should be used. Note: This octet is optional. On some phones this octet should be omitted! (Using the SMSC stored in phone is thus implicit)
      pdu_message="00"
# First octet of SMS-SUBMIT
      pdu_message << "11"
# TP-Message-Reference.
# The "00" value here lets the phone set the message reference number itself.
      pdu_message << "00"
# Address-Length. Length of the sender number (0C hex = 12 dec)
      pdu_message << "OC"
# Type-of-Address. (91 indicates international format of the phone number).
      pdu_message << "91"
# The phone number in semi octets (e.g. 46708251358). If the length of the phone number is odd (11), then a trailing F has been added, as if the phone number were "46708251358F". Using the unknown format (i.e. the Type-of-Address 81 instead of 91) would yield the phone number octet sequence 7080523185 (0708251358). Note that this has the length 10 (A), which is even.
# We'll send to +447905473867 which has 12 characters and is even
      phone_number = @dial_number
    # Remove leading '+'
      if phone_number[0..0] == "+" then
        phone_number.slice!(0..0)
      end
    # Check for evenness of length
      if (phone_number.length)%2 != 0 then
        phone_number<<"F"
      end
      0.step((phone_number.length)-1,2) {|x|
        i = phone_number[x]
        j = phone_number[x+1]
        phone_number[x] = j
        phone_number[x+1] = i
      }
      pdu_message << phone_number
# TP-PID. Protocol identifier
      pdu_message << "00"
# TP-DCS. Data coding scheme.This message is coded according to the 7bit default alphabet. Having "04" instead of "00" here, would indicate that the TP-User-Data field of this message should be interpreted as 8bit rather than 7bit (used in e.g. smart messaging, OTA provisioning etc).
      pdu_message << "00"
# TP-Validity-Period. "AA" means 4 days. Note: This octet is optional, see bits 4 and 3 of the first octet
      pdu_message << "AA"
# TP-User-Data-Length. Length of message. The TP-DCS field indicated 7-bit data, so the length here is the number of septets (10). If the TP-DCS field were set to 8-bit data or Unicode, the length would be the number of octets.
      pdu_message << sprintf("%02x",encoded_string.length).upcase
# TP-User-Data. These octets represent the message "hellohello". How to do the transformation from 7bit septets into octets is shown here
      pdu_message << encoded_string.to_s.upcase
    #printf pdu_message
    # Add Ctrl-z to finish
      pdu_message << 26

### Send message ###
# Set PDU mode
      @tn.cmd(   'String'        =>      "at+cmgf=0",
                 'Match'         =>      /OK/,
                 'Timeout'       =>      2)      {|str| print str }
# Check if modem supports SMS commands
      @tn.cmd(   'String'        =>      "AT+CSMS=0",
                 'Match'         =>      /OK/,
                 'Timeout'       =>      2)      {|str| print str }
# Send message, 23 octets (excluding the two initial zeros)
      @tn.cmd(   'String'        =>      "AT+CMGS=" << ((pdu_message.length/2)-1).to_s,
                 'Match'         =>      />/,
                 'Timeout'       =>      2)      {|str| print str }
# Write message
      @tn.write(pdu_message) 

    rescue TimeoutError, StandardError => bang
      print "Error in BGAN pdu_send: " + bang + "\n"
      raise
    end


  end 

  # Setter function for dial_number
  def dial_number=(new_dial_number)

    begin
      @dial_number = new_dial_number
    rescue StandardError => bang
      print "Error in BGAN dial_number: " + bang + "\n"
      raise
    end

  end

  # Setter function for service_centre
  def service_centre=(new_service_centre)

    begin
      @service_centre = new_service_centre
    rescue StandardError => bang
      print "Error in BGAN service_centre: " + bang + "\n"
      raise
    end

  end

  def close

    begin
      @tn.close
    rescue TimeoutError, StandardError => bang
      print "Error in BGAN close: " + bang + "\n"
      raise
    end

  end

  def end_ip_session
    begin
        @tn.cmd( 'String'        =>      "AT+CGACT?",
                 'Match'         =>      /OK/,
                 'Timeout'       =>      2)      {|str|
                if str =~ /\+CGACT:/
                  @tn.cmd( 'String'        =>      "AT+CGACT=0,1",
                           'Match'         =>      /OK/,
                           'Timeout'       =>      2)
                  @tn.cmd( 'String'        =>      "AT+CGDCONT=1",
                           'Match'         =>      /OK/,
                           'Timeout'       =>      2)
                end
                }
    rescue TimeoutError, StandardError => bang
      print "Error in BGAN end_ip_session: " + bang + "\n"
      raise
    end

  end

# Remember to end_ip_session before starting a new one.
  def start_ip_session
    begin
      @tn.cmd( 'String'        =>      
              %/AT+CGDCONT=1,"IP","BGAN.INMARSAT.COM","",0,0,"inmtester13","inmstatic13"/,
             'Match'         =>      /OK/,
             'Timeout'       =>      20)
# This only gives us a dynamic IP address. How do we get a fixed IP?
      @tn.cmd( 'String'        =>      
              %/AT+CGEQREQ=1,3,512,512,512,512,2,0,"0E0","0E0",3,500,0/,
             'Match'         =>      /OK/,
             'Timeout'       =>      20)
      @tn.cmd( 'String'        =>      "AT+CGACT=1,1",
             'Match'         =>      /OK/,
             'Timeout'       =>      30)
    rescue TimeoutError, StandardError => bang
      print "Error in BGAN start_ip_session: " + bang + "\n"
      raise
    end

  end
  
  def check_ip_session
    begin
        @tn.cmd( 'String'        =>      "AT+CGACT?",
                 'Match'         =>      /OK/,
                 'Timeout'       =>      2)      {|str|
                 
                 @cgact_str=str
                if str =~ /\+CGACT\: 1\,1/
                  @cgact=TRUE
                else str =~ /\+CGACT\: 1\,0/
                  @cgact=FALSE
#                else
#                  raise "+CGACT unknown: #{str}"
                end
                }

         return @cgact, @cgdact_str
    rescue TimeoutError, StandardError => bang
      print "Error in BGAN check_ip_session: " + bang + "\n"
      raise
    end
  end
  
  def activate
    begin
        @tn.cmd( 'String'        =>      "AT+CGACT=1,1",
                 'Match'         =>      /OK/,
                 'Timeout'       =>      60)
    rescue TimeoutError, StandardError => bang
      print "Error in BGAN activate: " + bang + "\n"
      raise
    end

  end

  def deactivate
    begin
        @tn.cmd( 'String'        =>      "AT+CGACT=0,1",
                 'Match'         =>      /OK/,
                 'Timeout'       =>      60)
    rescue TimeoutError, StandardError => bang
      print "Error in BGAN activate: " + bang + "\n"
      raise
    end

  end
 
# Code lifted from ping.rb
  def pingecho(host, timeout=5, service="echo")
    begin
      timeout(timeout) do
        s = TCPSocket.new(host, service)
        s.close
      end
    rescue Errno::ECONNREFUSED
      return true
    rescue Timeout::Error, StandardError
      return false
    end
    return true
  end
  
  def check_cgdcont
    begin
         @tn.cmd( 'String'        =>      "AT+CGDCONT?",
                 'Match'         =>      /OK/,
                 'Timeout'       =>      30)  {|str|
                  @cgdcont_str=str
                }

         return @cgdcont_str
    rescue TimeoutError, StandardError => bang
      print "Error in BGAN check_cgdcont: " + bang + "\n"
      raise
    end

  end
     
end

