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

load('peer.rb')

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
			if Peer.has_peers && Peer.peers.length >= 3
				puts "letting people know that I am ready now"
				Peer.set_ready
				return
			else
				puts "can't be ready, you don't have enough peers"
			end
		end
	end
end

