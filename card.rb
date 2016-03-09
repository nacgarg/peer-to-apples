class Card
	@type = nil
	@text = nil
	def to_s
		"#{@type} card: '#{@text}'"
  	end
  	
  	def text()
		@text
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

