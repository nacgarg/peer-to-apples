load('card.rb')
require 'securerandom'

class Deck
	def initialize()
		@black_cards = []
		@white_cards = []
	end

	def load_from_file(fpath)
		File.open(fpath, 'r') do |deck_file|
			deck_file.each_line do |line|
				if !line.strip.start_with?('#') and !(line =~ /^\s*$/)
					if line.strip == 'black_cards' then
						@current_type = :black
						next
					end
					if line.strip == 'white_cards' then
						@current_type = :white
						next
					end
					if @current_type.nil?
						raise 'Card type not specified before card text'
					end
					if @current_type == :black
						@black_cards << BlackCard.new(line.strip)
					end
					if @current_type == :white
						@white_cards << WhiteCard.new(line.strip)
					end
				end
			end
		end
	end

	def serialize()
		data = 'black_cards\n'
		@black_cards.each do |card|
			data += '#{card.text}'
		end
		data += 'white_cards'
		@white_cards.each do |card|
			data += '#{card.text}'
		end
		return data
	end

	def get_hash()
		Digest::SHA256.digest(serialize()).bytes.each.map { |b| b.to_s(16) }.join
	end

	def black_cards()
		@black_cards
	end

	def white_cards()
		@white_cards
	end
end
