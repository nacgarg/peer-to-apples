require 'rubygems'
require 'bundler/setup'

require 'eventmachine'

require 'socket'
require 'openssl'
require 'securerandom'

class Game
	SERVER_RELEASE = 'Apples-to-Peers 0.1'

	def initialize
		@peers = []
		@local_rsa = OpenSSL::PKey::RSA.new 2048
		@local_id = Peer.hash_key @local_rsa.public_key
		@local_nickname = request_nickname
	end

	attr_reader :local_nickname

	def local_public_key
		@local_rsa.public_key
	end

	def request_nickname # bad hack
		print "Nickname? "
		gets.strip
	end


	def self.instance
		@@instance ||= Game.new
	end
end

class Peer < EventMachine::Connection
	include EM::P::LineProtocol

	GAME_PORT = 54484 # class constant
	@@peers = []

	def self.hash_key(key)
		Digest::SHA256.digest(key.to_pem).bytes
	end

	def self.socket_encode_key(key)
		key.to_pem.gsub "\n", '|'
	end

	def self.socket_decode_key(key_s)
		OpenSSL::PKey::RSA.new(key_s.gsub '|', "\n")
	end

	def identify_peer
		pname = get_peername
		return false if pname.nil?
		port, ip = Socket.unpack_sockaddr_in(pname)
		@peer_info = { # store because get_peername doesn't work in `#unbind`
			:port => port,
			:ip => ip
		}
		return true
	end

	def peer_info_s
		"#{@peer_info[:ip]}:#{@peer_info[:port]}"
	end

	def player_id
		return Peer.hash_key(@public_key)
	end

	def public_key
		@public_key
	end

	def public_key_known
		!@public_key.nil?
	end

	def hashed_key
		Peer.hash_key(@public_key) if public_key_known
	end

	def hashed_key_hex
		hashed_key.map { |b| b.to_s(16) }.join
	end

	def identifying_name
		return nil unless ready
		"#{nickname}@#{hashed_key_hex}"
	end

	def nickname
		@nickname
	end

	def nickname_known
		!@nickname.nil?
	end

	def ready
		public_key_known && nickname_known
	end

	@@accepting_peers = true
	def self.accepting_peers?
		@@accepting_peers
	end

	def self.accepting_peers=(value)
		@@accepting_peers = value
	end

	# EVENTMACHINE HANDLERS

	def send_line(line)
		send_data "#{line}\n"
		puts "#{peer_info_s} <-- #{line}"
	end

	def send_action(action, data)
		msg = "#{action.to_s.upcase}"
		msg += ": #{data.to_s}" unless data.nil?
		send_line msg
	end

	ACTION_REGEX = /^([A-Z_]*): (.*)/
	def parse_action(line)
		match = Peer::ACTION_REGEX.match(line)
		return nil if match.nil?

		return {
			:action => match[1].downcase.intern,
			:data => match[2]
		}
	end

	def post_init
		if !identify_peer # stores peer info in @peer_info
			puts 'Cannot identify peer -- rejecting peer connection.'
			reject_connection 'cannot identify peer'
			return
		end

		unless Peer.accepting_peers?
			puts "Peer candidate #{peer_info_s} denied admission -- not currently accepting peers."
			reject_connection 'not currently accepting peers'
			return
		end

		@@peers << self
		puts "Connected to peer #{peer_info_s}."

		send_action :gameserver_release, Game::SERVER_RELEASE
	end

	def unbind(possible_reason= "remote/unknown")
		# on disconnect
		@@peers.delete(self)
		@disconnect_reason ||= possible_reason
		puts "Connection closed with peer #{peer_info_s} -- reason: '#{@disconnect_reason}'."
	end

	def reject_connection(reason)
		send_action :rejected, reason
		close_connection_after_writing

		@disconnect_reason = "rejected; #{reason}"
	end

	def identify
		send_action :welcome, identifying_name
		send_action :nickname, Game.instance.local_nickname
		send_action :public_key, Peer.socket_encode_key(Game.instance.local_public_key)
	end

	def read_public_key(data)
		begin
			@public_key = key = Peer.socket_decode_key(data)
		rescue OpenSSL::PKey::RSAError
			reject_connection 'bad public key'
			return
		end

		send_action :received_public_key, nil
		puts "Read #{peer_info_s}'s public key: #{hashed_key_hex}"

		identify if ready
	end

	NICKNAME_CHARS_NOT_ALLOWED = /[^A-Za-z0-9_]/
	def read_nickname(data)
		if data.length > 15 || data =~ Peer::NICKNAME_CHARS_NOT_ALLOWED # bad characters
			reject_connection 'bad nickname'
			return
		end

		@nickname = data
		@read_status = :idle

		identify if ready
	end

	def receive_line(line)
		return if line.nil?

		# determine status (each action is responsible for returning @read_status to idle)

		incoming = parse_action line
		return if incoming.nil?
		puts "i => #{incoming}"

		case incoming[:action]
		when :public_key
			read_public_key incoming[:data]
		when :nickname
			read_nickname incoming[:data]
		end

		puts "#{peer_info_s} --> #{line}"
	end
end

class ServerPeer < Peer

Game.instance # initialize everything

EventMachine.run do
	EM::start_server '0.0.0.0', Peer::GAME_PORT, Peer
	# example: EM::connect peer_ip, Peer::GAME_PORT, Peer ?

	puts "Accepting peer connections at :#{Peer::GAME_PORT}"
end