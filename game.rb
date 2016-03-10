require 'rubygems'
require 'bundler/setup'

require 'eventmachine'

require 'socket'
require 'openssl'
require 'securerandom'


require_relative 'deck.rb'

class Game
	SERVER_RELEASE = 'Apples-to-Peers 0.1'

	def initialize
		@peers = []
		@initial_peer = request_input 'Initial Peer IP? ', false
		@local_rsa = OpenSSL::PKey::RSA.new 2048
		@local_id = Peer.hash_key @local_rsa.public_key
		@local_nickname = request_input 'Nickname? ', true
		deckPath = request_input 'Path to deck? ',false
		if !deckPath.nil?
			@deck = Deck.new
			@deck.load_from_file deckPath
		end
	end

	attr_reader :local_nickname
	attr_reader :initial_peer

	def has_initial_peer
		!@initial_peer.nil?
	end

	def local_public_key
		@local_rsa.public_key
	end

	def request_input(prompt, required)
		print "#{prompt} "
		loop do
			s = STDIN.gets.strip
			return s unless s.empty?
			return nil unless required
		end
	end

	def has_deck
		!@deck.nil?
	end
	def deck
		@deck
	end
	def get_deck_hash
		@deck.get_hash
	end
	def self.instance
		@@instance ||= Game.new
	end
	def read_deck(data)
		@deck=Deck.new
		@deck.load_from_serialized(data)
	end

end

class Peer < EventMachine::Connection
	include EM::P::LineProtocol

	GAME_PORT = ARGV[0].nil? ? 54484 : ARGV[0].to_i# class constant
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
		if pname.nil?
			@peer_info = { # store because get_peername doesn't work in `#unbind`
				:port => :unknown,
				:ip => :unknown
			}
			return false
		end
		port, ip = Socket.unpack_sockaddr_in(pname)
		@peer_info = { # store because get_peername doesn't work in `#unbind`
			:port => port,
			:ip => ip
		}
		return true
	end

	def peer_is_ready_for_game_to_start
		@ready.nil? ? false : @ready
	end

	def peer_info_s
		"#{@peer_info[:ip]}:#{@peer_info[:port]}"
	end

	def ip_address
		"#{@peer_info[:ip]}"
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
		return nil unless has_identified
		"#{nickname}@#{hashed_key_hex}"
	end

	def nickname
		@nickname
	end

	def nickname_known
		!@nickname.nil?
	end

	def has_identified
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
		msg = "#{action.to_s.upcase}: "
		msg += "#{data.to_s}" unless data.nil?
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
			@identification_attempts_left ||= 5
			@identification_attempts_left -= 1
			if @identification_attempts_left > 0
				puts "Couldn't identify peer... will try #{@identification_attempts_left} more times..."
				EM.add_timer(0.3) { post_init }
				return
			end
			puts 'Cannot identify peer -- rejecting peer connection.'
			reject_connection 'cannot identify peer'
			return
		end

		unless Peer.accepting_peers?
			puts "Peer candidate denied admission -- not currently accepting peers."
			reject_connection 'not currently accepting peers'
			return
		end

		@@peers << self
		puts "Connected to peer #{peer_info_s}."
		EM.add_timer(1) { send_action :gameserver_release, Game::SERVER_RELEASE }
	end

	def unbind(possible_reason= "remote/unknown")
		# on disconnect
		@@peers.delete(self)
		@disconnect_reason ||= possible_reason
		puts "Connection closed with peer #{peer_info_s} -- reason: '#{@disconnect_reason}'."
		abort_game if !enough_players?
	end

	def enough_players?
		return @@peers.length >= 3
	end 

	def abort_game
		puts "Oh no! #{peer_info_s} left the game, and now there aren't enough people to keep going."
		abort("Aborting...")
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
		if public_key_known
			reject_connection 'already has public key' 
			return
		end
		begin
			@public_key = key = Peer.socket_decode_key(data)
		rescue OpenSSL::PKey::RSAError
			reject_connection 'bad public key'
			return
		end
		send_action :received_public_key, nil
		puts "Read #{peer_info_s}'s public key: #{hashed_key_hex}"

		send_deck_info if has_identified
	end

	def send_deck_info
		if !Game.instance.has_deck
			puts "doesn't have a deck, so not sending hash"
			return
		end
		send_action :deck_hash, Game.instance.get_deck_hash
	end

	def read_deck_hash(data)
		if !Game.instance.has_deck
			#if has this deck hash on disk
				#read from disk
				#send action :has_deck, nil
			#else
				send_action :get_deck, nil
			#end
			return
		end
		if data==Game.instance.get_deck_hash
			send_action :has_deck, nil 
		else
			reject_connection 'already got a different deck from someone else'
		end
	end

	def send_deck
		send_action :deck_contents, Game.instance.deck.serialize
	end

	def read_deck_contents(data)
		Game.instance.read_deck(data)
		#save this deck to disk for later
		send_action :has_deck, nil
	end

	def peer_has_deck
		puts "Peer has same deck, here we would send our peers"
		#now we know that they have the same deck as us
		#send them all our peers
		
		res = @@peers.select {|peer| peer != self }.map(&:ip_address).join ','
		puts "Peers to send: #{res}"
		send_action :peers, res
	end

	def received_peers(data)
		puts "Received peers #{data}"
		data.split(",").each do |ip|
			puts "peer: #{ip}"
			if @@peers.any? { |peer| peer.ip_address == ip}
				puts "already connected"
			else
				puts "not connected yet"
				connect_to_peer ip
			end

		end
	end

	def received_ready
		@ready=true
	end

	NICKNAME_CHARS_NOT_ALLOWED = /[^A-Za-z0-9_]/
	def read_nickname(data)
		if data.length > 15 || data =~ Peer::NICKNAME_CHARS_NOT_ALLOWED # bad characters
			reject_connection 'bad nickname'
			return
		end
		if nickname_known
			reject_connection 'already has nickname'
			return
		end


		@nickname = data
		@read_status = :idle


		send_deck_info if has_identified
	end

	def read_version(data)
		if Game::SERVER_RELEASE != data
			reject_connection 'bad version'
			return
		end
		unless Peer.accepting_peers?
			reject_connection 'bad'
			return
		end
		identify 
	end

	def receive_line(line)
		return if line.nil?

		# determine status (each action is responsible for returning @read_status to idle)

		incoming = parse_action line
		return if incoming.nil?
		puts "i => #{incoming}"
		puts "#{peer_info_s} --> #{line}"
		case incoming[:action]
		when :public_key
			read_public_key incoming[:data]
		when :nickname
			read_nickname incoming[:data]
		when :gameserver_release
			read_version incoming[:data]
		when :deck_hash
			read_deck_hash incoming[:data]
		when :deck_contents
			read_deck_contents incoming[:data]
		when :get_deck
			send_deck
		when :has_deck
			peer_has_deck
		when :peers
			received_peers incoming[:data]
		when :ready
			received_ready
			Peer.on_readiness_update
		end

		
	end
	def self.set_ready
		@@peers.each { |peer| peer.send_action(:ready,nil)}
		@@me_ready=true
		Peer.on_readiness_update
	end
	@@me_ready = false
	def self.on_readiness_update
		if check_ready
			puts "EVERYONE IS READY, LETS GO"
			@@accepting_peers=false
			puts "No longer accepting new peers because game is in progress"
		else
			puts "not all peers are ready, or I'm not ready =("
		end
	end
	def self.check_ready
		return false unless @@me_ready
		return false if @@peers.length==0
		return false if @@peers.any? {|peer| !peer.peer_is_ready_for_game_to_start}
		return true
	end
	def self.has_peers
		@@peers.length!=0
	end
end

Game.instance # initialize everything
def connect_to_peer(ip)
	EM::connect ip, 54484, Peer if ip
end

EventMachine.run do
	EM::start_server '0.0.0.0', Peer::GAME_PORT, Peer
	connect_to_peer(Game.instance.initial_peer)

	puts "Accepting peer connections at :#{Peer::GAME_PORT}"
	Thread.new do
		loop do
			puts "waiting, hit enter once you are ready for the game to start"
			STDIN.gets.strip
			if Peer.has_peers
				puts "letting people know that I am ready now"
				Peer.set_ready
				return
			else
				puts "can't be ready, you don't have any peers"
			end
		end
	end
end

