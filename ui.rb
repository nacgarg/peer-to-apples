require 'io/console'

module ApplesToPeers

	class Interface

		LOGFILE = "logs.txt"
		def self.request_input(prompt, required=false)
			print "#{prompt} "
			loop do
				s = STDIN.gets.strip
				return s unless s.empty?
				return nil unless required
			end
		end

		def self.pick_white_card(hand)
			hand.each_with_index { |card, index| print index == 0 ? " \e[47m#{card.text}\e[0m  ": " #{card.text}  " }
			index = 0
			STDOUT.flush
			while true do
				input = read_char
				case input
				when "\e[D" # Left arrow
					print "\r"
					index -= 1
					hand.each_with_index { |card, ind| print ind == index ? " \e[47m#{card.text}\e[0m  ": " #{card.text}  " }
					STDOUT.flush
				when "\e[C" # Right arrow
					print "\r"
					index += 1
					hand.each_with_index { |card, ind| print ind == index ? " \e[47m#{card.text}\e[0m  ": " #{card.text}  " }
					STDOUT.flush
				when "\r" # Enter
					print "\n\n"
					return hand[index]
				end
			end
		end

		def self.judge_cards(hand)
			hand.each_with_index { |card, index| print index == 0 ? " \e[47m#{card.text}\e[0m  ": " #{card.text}  " }
			index = 0
			STDOUT.flush
			while true do
				input = read_char
				case input
				when "\e[D" # Left arrow
					print "\r"
					index -= 1
					hand.each_with_index { |card, ind| print ind == index ? " \e[47m#{card.text}\e[0m  ": " #{card.text}  " }
					STDOUT.flush
				when "\e[C" # Right arrow
					print "\r"
					index += 1
					hand.each_with_index { |card, ind| print ind == index ? " \e[47m#{card.text}\e[0m  ": " #{card.text}  " }
					STDOUT.flush
				when "\r" # Enter
					print "\n\n"
					return index
				end
			end
		end

		def self.log(text)
			open(LOGFILE, 'a') do |f|
				f.puts text
			end
		end

		def self.notify(text)
			puts text
		end

		def self.read_char
			STDIN.echo = false
			STDIN.raw!
			input = STDIN.getch
			if input == "\e" then
				input << STDIN.read_nonblock(3) rescue nil
				input << STDIN.read_nonblock(2) rescue nil
			end
			ensure
				STDIN.echo = true
				STDIN.cooked!
			return input
		end
	end

end