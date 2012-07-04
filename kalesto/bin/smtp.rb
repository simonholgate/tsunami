#!/usr/local/bin/ruby
mailhost = ARGV[0]
send_to = ARGV[1]
send_from = ARGV[2]
message_subject = ARGV[3]
message_body = ARGV[4]

msgstr = <<END_OF_MESSAGE
From: TGUML <#{send_from}>
To: Rothera Gumstix <#{send_to}>
Subject: #{message_subject}

END_OF_MESSAGE

msgstr << message_body

#puts mailhost, send_to, send_from, msgstr

require 'net/smtp'
Net::SMTP.start(mailhost, 25) do |smtp|
  smtp.send_message msgstr,
  send_from,
  send_to
end


