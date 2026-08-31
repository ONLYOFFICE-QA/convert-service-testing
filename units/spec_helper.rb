# frozen_string_literal: true

require 'onlyoffice_logger_helper/logger_helper'
require_relative '../config/StaticData'
require_relative '../helpers/image_helper'
require_relative '../helpers/csv_report'
require_relative '../helpers/example_status'
require_relative '../helpers/test_report'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
