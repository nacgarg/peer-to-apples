module ApplesToPeers

	class Interface

		def self.request_input(prompt, required=false)
			print "#{prompt} "
			loop do
				s = STDIN.gets.strip
				return s unless s.empty?
				return nil unless required
			end
		end

		def self.pick_white_card(hand)
			hand.each_with_index { |card, index| puts "#{index+1}: #{card.text}" }
			puts "Type in the number of the card you want to play."
			input = STDIN.gets.strip.to_i
			if input <= 0 || input > hand.length
				puts "Invalid number, try again."
				return Interface.pick_white_card(hand)
			end
			return hand[input - 1]
		end

		def self.judge_cards(hand)
			hand.each_with_index { |card, index| puts "#{index+1}: #{card.text}" }
			puts "Type in the number of the card you think should win."
			input = STDIN.gets.strip.to_i
			if input <= 0 || input > hand.length
				puts "Invalid number, try again."
				return Interface.judge_cards(hand)
			end
			return input-1
		end

	end

end