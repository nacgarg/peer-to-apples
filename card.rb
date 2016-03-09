class Card
	@type = nil
	@text = nil
	def to_s
		"#{@type} card: '#{@text}'"
  	end
end

class BlackCard < Card
	def initialize(text)
		@text = text
		@type = :black
	end

end

class WhiteCard < Card
	def initialize(text)
		@text = text
		@type = :white
	end
end

class Hand
	def initialize(cards = [])
		@cards = []
	end
	def << (card)
		@cards << card
    end
end

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

	def black_cards()
		@black_cards
	end

	def white_cards()
		@white_cards
	end
end

