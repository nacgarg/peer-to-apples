module Handlers

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

	def read_deck_contents(data)
		Game.instance.read_deck(data)
		#save this deck to disk for later
		send_action :has_deck, nil
	end

	def send_deck
		send_action :deck_contents, Game.instance.deck.serialize
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

	def read_deck_contents(data)
		Game.instance.read_deck(data)
		#save this deck to disk for later
		send_action :has_deck, nil
	end

	def received_ready
		@ready=true
	end
end