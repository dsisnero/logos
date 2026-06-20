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
      start_eoi_state = next_eoi_state(current_state_id)
      if is_match_state?(start_eoi_state)
        last_match = {0, state_matches(start_eoi_state)}
      end

      idx = 0
      size = slice.size

      while idx < size
        next_state_id = transition(slice[idx], current_state_id)
        break if is_dead_state?(next_state_id)
        # Logos needs a token match anchored at the current lexer position.
        # If the DFA restarts into another start state after consuming input,
        # then it has found a later match and we must stop instead of skipping.
        break if next_state_id != start_state_id && is_start_state?(next_state_id)

        current_state_id = next_state_id
        eoi_state = next_eoi_state(current_state_id)
        last_match = {idx + 1, state_matches(eoi_state)} if is_match_state?(eoi_state)
        idx += 1
      end

      if idx == size
        eoi_state = next_eoi_state(current_state_id)
        last_match = {size, state_matches(eoi_state)} if is_match_state?(eoi_state)
      end

      last_match
    end
  end
end
