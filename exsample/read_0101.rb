require "socket"

HOST = ARGV.empty? ? "127.0.0.1" : ARGV.shift.strip
PORT = ARGV.empty? ? 9600 : ARGV.shift.to_i

if HOST.nil? or HOST.empty?
  puts "Usage: ruby example/read_0101.rb <ipaddress> <port>"
end

command = "800002000100000100000101000000010001"
bin = [command].pack("H*")

udp_client = UDPSocket.open()
sockaddr = Socket.pack_sockaddr_in(PORT, HOST)
byte_size = udp_client.send(bin, 0, sockaddr)
puts "#{byte_size}byte sent ok."
