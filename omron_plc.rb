# -*- coding: utf-8 -*-

##################################################################
# exp:
#
# $ ruby omron_plc.rb # default 127:0:0:1:9600
#
# $ ruby omron_plc.rb --address=172.16.15.35 --port=9602
#
# $ ruby omron_plc.rb --address=172.16.15.35 --port=9602 --count_up_dm=3,4,5 --countup_interval=5
#
##################################################################

require "socket"
require "thread"
require "getoptlong"
require "yaml"

module OMRON
  class PLC
    attr_accessor :host, :port

    FINS_HEADER_SIZE = 10
    FINS_CODE_SIZE = 2

    def initialize(host = "127.0.0.1", port = 9600, params = {})
      @host = host
      @port = port
      @sock = nil
      @dm_area = Array.new(32767, 0)
      @countup_interval = params[:countup_interval] || 5
      @countup_dmno_list = params[:countup_dmno_list] || []
      @dm_mutex = Mutex.new

      puts
      load_file(params[:load_file])
    end

    def start
      STDOUT.sync = true
      Thread.abort_on_exception = true
      spawn_countup_thread(@countup_interval, @countup_dmno_list)
      spawn_upd_server_thread(@host, @port)

      sleep(0.5)
      puts 
      puts "----------------------------------------------------"
      puts "PLC SIMULATOR SYSTEM"
      puts "----------------------------------------------------"
      puts "SET DM COMMAND     : > set <dm number>, <value>"
      puts "GET DM COMMAND     : > get <dm number>"
      puts "GET DM LIST COMMAND: > get_list <dm number>, <count>"
      puts "EXIT COMMAND       : > exit"
      puts "----------------------------------------------------"
      puts

      while true
        begin
          print "> "
          str = gets

          case str.chomp
          when "exit"
            break
          when /get */, /get_list */, /set */
            eval(str)
          when /load */
            path = str.chomp.split(/\s+/)[1]
            load_file(path)
          end
        rescue Exception => e
          p e
        end
      end
    end

    # UDPサーバーを別スレッドで開始する
    def spawn_upd_server_thread(host, port)
      Thread.start {
        @sock = UDPSocket.open()
        @sock.bind(host, port)
        puts "UDP Socket bind to host:#{host}, port:#{port}."
        
        while true
          bin,sender = @sock.recvfrom(65535)
          header_bin = bin[0, 10]
          header = Header.parse(header_bin)
          code = bin[10, 2]
          body = bin[12..-1]

          puts "-------------------------------------------"
          puts "DEBUG: recv #{bin.unpack('H*').first}"
          puts "DEBUG: recv command code: [#{code[0,1].unpack('H*').first}, #{code[1,1].unpack('H*').first}]"
          
          begin
            handle(code, body, header, sender[2], sender[1])
          rescue => e
            puts "not supported code received!"
            puts " from  : #{host}:#{port}"
            puts " header: #{header.binary.unpack('H*').first}" if header
            puts " code  : #{code.unpack('H*').first}" if code
            puts " body  : #{body.unpack('H*').first}" if body
            puts 

            p e
          end
        end
      }
    end

    # 特定のDMの自動カウントアップを別スレッドで開始する
    def spawn_countup_thread(interval, dmno_list)
      Thread.start {
        val = 0
        loop do
          dmno_list.each do |dmno|
            write_dm_value(dmno, val)
          end
          val += 1
          val = 0 if val >= 32767
          sleep(interval)
        end
      }
    end

    # コマンド用
    def get(dmno)
      puts dm_value(dmno, 1)
    end

    # コマンド用
    def get_list(dmno, count)
      dm_value(dmno, count).each_with_index do |val, i|
        puts "#{dmno + i} : #{val}"
      end
    end

    # コマンド用
    def set(dmno, val)
      write_dm_value(dmno, val)
      puts "ok"
    end

    private

    def load_file(path)
      return if path.nil?

      print "Loading #{path}..."
      YAML.load_file(path).each do |dmno, val|
        write_dm_value(dmno, val)
      end
      puts "done"
    end

    def dm_value(start, count)
      @dm_area[start, count]
    end

    def write_dm_value(dmno, val)
      @dm_mutex.synchronize do
        @dm_area[dmno] = val
      end
    end

    def handle(code, body, header, from_address, from_port)
      handler = {
        "\x01\x01" => lambda{ handle_0101(code, body) },
        "\x01\x02" => lambda{ handle_0102(code, body) },
        "\x01\x03" => lambda{ handle_0103(code, body) },
        "\x01\x04" => lambda{ handle_0104(code, body) }, 
        "\x07\x01" => lambda{ handle_0701(code, body) },
     }[code]

      if handler.nil?
        raise "not supported code received!"
      end

      reply_bin = handler.call()
      
      if reply_bin
        reply_header = Header.new(:da1 => header.sa1, :sa1 => header.da1, :sid => header.sid)
        reply_header_bin = reply_header.format
        send_data = reply_header_bin + reply_bin

        sock_addr = Socket.pack_sockaddr_in(from_port, from_address)
        client = UDPSocket.open()        
        client.send(send_data, 0, sock_addr)
        client.close
        puts "DEBUG: reply sent ok (identifier=#{reply_header.sid.unpack('H*').first.hex})"
        puts "DEBUG: reply bin: #{send_data.unpack('H*').first}"
      end
    end

    def handle_0101(code, body)
      start_address = body[1..3].unpack("H4")[0].hex
      count =         body[4..5].unpack("H*")[0].hex

      values = dm_value(start_address, count)
      p [start_address, count]
      values_bin = values.map {|v| [format("%04x", v)].pack("H*")}.join
      code + finish_code + values_bin
    end

    def handle_0102(code, body)
      start_address = body[1..3].unpack("H4")[0].hex
      count =         body[4..5].unpack("H*")[0].hex

      count.times do |i|
        val = body[(6 + i*2), 2].unpack("H*")[0].hex
        write_dm_value(start_address + i, val)
      end

      code + finish_code
    end

    def handle_0103(code, body)
      start_address = body[1..3].unpack("H4")[0].hex
      count =         body[4..5].unpack("H*")[0].hex
      val =           body[6..7].unpack("H*")[0].hex

      count.times do |i|
        write_dm_value(start_address + i, val)
      end

      code + finish_code
    end

    def handle_0104(code, body)
      i = 0
      values = []

      loop do
        part = body[i*4, 4]
        break if part.empty?
        io_facility = part[0, 1]
        address = part[1..3].unpack("H4")[0].hex
        values << {:io_facility => io_facility, :val => @dm_area[address]}
        i += 1
      end

      values_bin = values.map {|v|
        [v[:io_facility], [format("%04x", v[:val])].pack("H*")]
      }.flatten.join

      code + finish_code + values_bin
    end

    def handle_0701(code, body)
      i = 0
      time = Time.now
      short_year = time.year - 2000

      str =
        format("%d%d", short_year / 10, short_year % 10) +
        format("%d%d", time.month / 10, time.month % 10) +
        format("%d%d", time.day / 10, time.day % 10) +
        format("%d%d", time.hour / 10, time.hour % 10) +
        format("%d%d", time.min / 10, time.min % 10) + 
        format("%d%d", time.sec / 10, time.sec % 10) +
        format("%02d", time.wday)

      values_bin = [str].pack("H*")
      code + finish_code + values_bin
    end

    def finish_code
      "\x00\x00"
    end

    class Header
      attr_accessor :icf, :rsv, :gct, :dna, :da1, :da2, :sna, :sa1, :sa2, :sid
      attr_accessor :binary

      def self.parse(binary)
        raise ArugmentError.new("invalid header binary: #{binary}") unless binary.kind_of?(String)
        raise ArgumentError.new("too short header binary: #{binary.size}byte") if binary.size < 10
        params = {}
        params[:icf] = binary[0, 1]
        params[:rsv] = binary[1, 1]
        params[:gct] = binary[2, 1]
        params[:dna] = binary[3, 1]
        params[:da1] = binary[4, 1]
        params[:da2] = binary[5, 1]
        params[:sna] = binary[6, 1]
        params[:sa1] = binary[7, 1]
        params[:sa2] = binary[8, 1]
        params[:sid] = binary[9, 1]
        self.new(params, binary)
      end

      def initialize(params, binary = nil)
        @binary = binary
        @icf = (params[:icf] || create_icf())
        @rsv = (params[:rsv] || create_rsv())
        @gct = (params[:gct] || create_gct())
        @dna = (params[:dna] || create_dna())
        @da1 = (params[:da1] || (raise ArgumentError.new("no da1")))
        @da2 = (params[:da2] || create_da2())
        @sna = (params[:sna] || create_sna())
        @sa1 = (params[:sa1] || (raise ArgumentError.new("no sa1")))
        @sa2 = (params[:sa2] || create_sa2())
        @sid = (params[:sid] || create_sid())
      end

      def format
        data =  @icf
        data << @rsv
        data << @gct
        data << @dna
        data << @da1
        data << @da2
        data << @sna
        data << @sa1
        data << @sa2
        data << @sid
        data
      end

      def create_icf
        ["10000011"].pack("B*")
      end
      
      def create_rsv
        ["00"].pack("H*")
      end

      def create_gct
        ["02"].pack("H*")      
      end

      def create_dna(dst_network_address = "0")
        [dst_network_address].pack("H*")
      end

      def create_da1(dst_node_address)
        [dst_node_address].pack("H*")
      end

      def create_da2(dst_machine_address = "0")
        [dst_machine_address].pack("H*")
      end

      def create_sna(src_network_address = "0")
        [src_network_address].pack("H*")
      end

      def create_sa1(src_node_address)
        [src_node_address].pack("H*")
      end

      def create_sa2(src_machine_address = "0")
        [src_machine_address].pack("H*")
      end

      def create_sid(service_id = 1)
        [service_id].pack("c*")
      end

    end

  end
end


if __FILE__ == $0
  host = "127.0.0.1"
  port = 9600
  count_up_dm_list = []
  countup_interval = 5
  load_file = nil

  optparser = GetoptLong.new
  optparser.set_options(['--address', GetoptLong::REQUIRED_ARGUMENT],
                        ['--port', GetoptLong::REQUIRED_ARGUMENT],
                        ['--count_up_dm', GetoptLong::REQUIRED_ARGUMENT],
                        ['--countup_interval', GetoptLong::REQUIRED_ARGUMENT],
                        ['--load_file', GetoptLong::REQUIRED_ARGUMENT])

  begin
    optparser.each_option do |name, arg|
      case name
      when "--address"
        host = arg
      when "--port"
        port = arg.to_i
      when "--count_up_dm"
        str = arg
        count_up_dm_list = str.split(/\,/).map {|s| s.to_i} 
      when "--countup_interval"
        countup_interval = arg.to_i 
      when "--load_file"
        load_file = arg 
      when "--debug"
        mail_manager.debug = true
      end
    end
  rescue
    exit(1)
  end
  
  plc = OMRON::PLC.new(host, port,
                       :countup_dmno_list => count_up_dm_list,
                       :countup_interval => countup_interval,
                       :load_file => load_file)
  plc.start
end
