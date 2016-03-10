module UI

	def request_input(prompt, required)
		print "#{prompt} "
		loop do
			s = STDIN.gets.strip
			return s unless s.empty?
			return nil unless required
		end
	end

	def pick_white_card(hand)
		hand.each_with_index { |card, index| puts "#{index+1}: #{card}" }
		puts "Type in the number of the card you want to play."
		input = gets.strip.to_i
		if input == 0 || input > hand.length
			puts "Invalid number, try again."
			return pick_white_card(hand)
		end
		return hand[input - 1]
	end

end
