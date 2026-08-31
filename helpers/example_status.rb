# frozen_string_literal: true

require 'rspec/expectations'

# Converts the result of the finished rspec example to the status with the comment
module ExampleStatus
  class << self
    # @param example [RSpec::Core::Example] finished rspec example
    # @return [Array(String, String)] status of the example and the comment about it
    def of(example)
      return ['pending', normalize(example.metadata[:execution_result].pending_message)] if example.pending

      exception = example.exception
      case exception
      when nil then %w[passed Ok]
      when RSpec::Expectations::ExpectationNotMetError then ['failed', normalize(exception.message)]
      else ['aborted', normalize("#{exception.class}: #{exception.message}")]
      end
    end

    # Csv report is much easier to read when the value is a single line
    # @param value [String, nil] value to normalize
    # @return [String] value without line breaks and repeated spaces
    def normalize(value)
      value.to_s.gsub(/\s+/, ' ').strip
    end
  end
end
