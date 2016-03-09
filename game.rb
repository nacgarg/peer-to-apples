require 'rubygems'
require 'bundler/setup'

require 'eventmachine'

require 'socket'
require 'openssl'
require 'securerandom'

class Game
	def initialize
		@peers = []
		@status = GameStatus::PREGAME
		@local_rsa = OpenSSL::PKey::RSA.new 2048
		@local_id = Peer.hash_key @local_rsa.public_key
	end
end

class Peer < EventMachine::Connection
	include EM::P::LineProtocol

	GAME_PORT = 54484 # class constant
	@@peers = []

	def self.hash_key(key)
		return nil if key.nil?
		Digest::SHA256.digest(key.to_pem).bytes
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
		(hashed_key.map { |b| b.to_s(16) }).join('')
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

	ACTION_REGEX = /^([A-Z]*): (.*)/
	def parse_action(line)
		match = Peer::ACTION_REGEX.match(line)
		return nil if match.nil?

		return {
			:action => match[1].downcase.to_sym,
			:data => match[2]
		}
	end


	def post_init
		if !identify_peer # stores peer info in @peer_info
			puts 'Cannot identify peer -- rejecting peer connection.'
			reject_connection 'cannot identify peer'
			return
		end

		@read_status = :idle

		@@peers << self
		puts "Connected to peer #{peer_info_s}."
	end

	def unbind
		# on disconnect
		@@peers.delete(self)
		@disconnect_reason ||= "remote/unknown"
		puts "Connection closed with peer #{peer_info_s} -- reason: '#{@disconnect_reason}'."
	end

	def reject_connection(reason)
		send_action :rejected, reason
		close_connection_after_writing

		@disconnect_reason = "rejected; #{reason}"
	end

	def send_welcome_if_ready
		send_action :welcome, identifying_name if ready
	end

	def read_public_key_part(line)
		@public_key_buffer += "#{line}\n"

		if line === "-----END PUBLIC KEY-----"
			# release read priority
			@read_status = :idle
			begin
				@public_key = OpenSSL::PKey::RSA.new @public_key_buffer
			rescue OpenSSL::PKey::RSAError
				reject_connection 'bad public key'
				return
			end
			send_action :received_public_key, nil
			send_welcome_if_ready
			puts "Read #{peer_info_s}'s public key: #{hashed_key_hex}"
		end
	end

	NICKNAME_CHARS_NOT_ALLOWED = /[^A-Za-z0-9_]/
	def read_nickname(data)
		if data.length > 15 || data =~ Peer::NICKNAME_CHARS_NOT_ALLOWED # bad characters
			reject_connection 'bad nickname'
			return
		end

		@nickname = data
		@read_status = :idle

		send_welcome_if_ready
	end

	def receive_line(line)
		# determine status (each action is responsible for returning @read_status to idle)

		incoming = parse_action line

		if @read_status == :idle

			if line == "-----BEGIN PUBLIC KEY-----" # does not use action "protocol"
				@public_key_buffer = ""
				# capture read priority
				@read_status = :reading_public_key
			end

			# ACTION PROTOCOL/SYSTEM
			unless incoming.nil?
				puts "incoming: #{incoming.inspect}"
				if incoming[:action] == :nickname
					@read_status = :reading_nickname
				end
				# add more actions here
			end

		end

		puts "#{peer_info_s} --> (#{@read_status.to_s}): #{line.inspect}"

		# take action
		case @read_status
		when :reading_public_key
			read_public_key_part line
		when :reading_nickname
			read_nickname incoming[:data]
		end

	end
end

EventMachine.run do
	EM::start_server '127.0.0.1', Peer::GAME_PORT, Peer
	puts "Accepting peer connections at :#{Peer::GAME_PORT}"
end