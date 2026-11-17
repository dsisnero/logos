require "regex-automata"

module Regex::Automata::DFA
  class DFA
    def find_longest_match_at_start(input : String) : Tuple(Int32, Array(PatternID))?
      find_longest_match_at_start(input.to_slice)
    end

    def find_longest_match_at_start(slice : Bytes) : Tuple(Int32, Array(PatternID))?
      find_longest_match_from_state(slice, @start_anchored)
    end

    private def find_longest_match_from_state(slice : Bytes, start_state_id : StateID) : Tuple(Int32, Array(PatternID))?
      last_match : Tuple(Int32, Array(PatternID))? = nil
      current_state_id = start_state_id
      index = 0

      # DFA matches are delayed by one byte. Use the actual following byte
      # for assertions, and the EOI transition only at the end of the source.
      while index < slice.size
        next_state_id = transition(slice[index], current_state_id)
        last_match = {index, state_matches(next_state_id)} if is_match_state?(next_state_id)
        break if is_dead_state?(next_state_id)
        break if next_state_id != start_state_id && is_start_state?(next_state_id)

        current_state_id = next_state_id
        index += 1
      end

      if index == slice.size
        eoi_state = next_eoi_state(current_state_id)
        last_match = {index, state_matches(eoi_state)} if is_match_state?(eoi_state)
      end

      last_match
    end
  end
end
