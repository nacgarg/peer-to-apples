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
			index = 0
			STDOUT.flush
			while true do
				hand.each_with_index { |card, ind| puts ind == index ? "\e[47m#{card.text}\e[0m  ": " #{card.text}  " }
				STDOUT.flush
				input = read_char
				case input
				when "\e[B" # Left arrow
					print "\r" + ("\e[A\e[K"*hand.size)
					index -= 1
				when "\e[A" # Right arrow
					print "\r" + ("\e[A\e[K"*hand.size)
					index += 1
				when "\r" # Enter
					print "\n\n"
					return hand[index]
				end
				index+=hand.size
				index%=hand.size
			end
		end

		def self.judge_cards(hand)
			index = 0
			STDOUT.flush
			while true do
				hand.each_with_index { |card, ind| puts ind == index ? "\e[47m#{card.text}\e[0m  ": " #{card.text}  " }
				STDOUT.flush
				input = read_char
				case input
				when "\e[B" # Left arrow
					print "\r" + ("\e[A\e[K"*hand.size)
					index -= 1
				when "\e[A" # Right arrow
					print "\r" + ("\e[A\e[K"*hand.size)
					index += 1
				when "\r" # Enter
					print "\n\n"
					return index
				end
				index+=hand.size
				index%=hand.size
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