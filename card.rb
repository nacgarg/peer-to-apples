module Card
	def text_for_card(index, type)
		raise NotImplementedError
	end
end

class BlackCard
	include Card

	def initialize(index)
		@index = index
		@type = :black
		@text = Card::text_for_card(@index, @type)
	end

	def to_s
		"#{type} card: '#{text}'"
	end
end

class WhiteCard
	include Card

	def initialize(text)
		@text = text
		@type = :white
		@text = Card::text_for_card(@index, @type)
	end

	def to_s
		"#{type} card: '#{text}'"
	end
end

class Hand
	def initialize(cards = [])
		@cards = cards
	end

	attr_reader :cards

	def <<(card)
		@cards << card
    end
end
