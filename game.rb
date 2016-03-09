require 'rubygems'
require 'bundler/setup'

require 'openssl'
require 'securerandom'

module GameStatus
	PREGAME = 0
	PEERING = 1
end

class Game
	def initialize
		@peers = []
		@status = GameStatus::PREGAME
		@local_rsa = OpenSSL::PKey::RSA.new 2048
		@local_id = Peer.hash_key @local_rsa.public_key
	end

	def add_peer(peer)
		@peers << peer
	end

	def status
		@status
	end

	def can_start
		@status == GameStatus::PREGAME && peers.all?(&:connected)
	end
end

class Peer
	@@GAME_PORT = 84464

	def self.hash_key(key)
		return nil if key.nil?
		Digest::SHA256.digest(key.to_pem).bytes
	end

	def initialize(ip_addr)
		@ip_addr = ip_addr
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

	def connected
		public_key_known
	end
end