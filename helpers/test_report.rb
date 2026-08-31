# frozen_string_literal: true

require_relative 'csv_report'
require_relative 'example_status'

# Collects rspec results and writes them to the single csv report of the tested version
class TestReport
  TITLES = %w[Test_name Status Comment Extra_info Version Run Time].freeze
  CONSOLE_TITLES = %w[Run Test_name Status Comment Extra_info].freeze
  VERSION_PATTERN = /\d+\.\d+\.\d+\.\d+/

  attr_reader :path, :errors_path, :run_name, :version

  class << self
    # @return [Array<TestReport>] reports created during the current rspec run
    def reports
      @reports ||= []
    end

    # Prints results of the current rspec run
    # @return [nil]
    # @note all spec files write to the report of the version, so it is handled only once
    def print_summary
      reports.uniq(&:path).each(&:handler)
      nil
    end
  end

  # @param version [String] tested documentserver version, used as a report name
  # @param run_name [String] name of the run, written to the `Run` column
  # @param reports_dir [String] root directory for all reports
  def initialize(version, run_name, reports_dir: StaticData.reports_folder)
    @version = version.to_s.strip.empty? ? 'unknown' : version.to_s.strip
    @run_name = run_name
    name = report_name
    @path = File.join(reports_dir, name, "#{name}.csv")
    @errors_path = File.join(reports_dir, name, "#{name}(errors_only).csv")
    self.class.reports << self
  end

  # Writes the result of the example to the report and logs it
  # @param example [RSpec::Core::Example] finished rspec example
  # @param file_data [Integer, nil] size of the converted image
  # @param server_response [String, nil] raw response of the convert service
  # @return [String] status of the example
  def add_result_and_log(example, file_data = nil, server_response = nil)
    status = add_result(example, file_data, server_response)
    OnlyofficeLoggerHelper.log("Test is #{status}, result is written to #{@path}")
    status
  end

  # Writes the result of the example to the report
  # @param example [RSpec::Core::Example] finished rspec example
  # @param file_data [Integer, nil] size of the converted image
  # @param server_response [String, nil] raw response of the convert service
  # @return [String] status of the example
  def add_result(example, file_data = nil, server_response = nil)
    status, comment = ExampleStatus.of(example)
    CsvReport.create(@path, TITLES)
    CsvReport.append(@path, [example.metadata[:description],
                             status,
                             comment,
                             extra_info(file_data, server_response),
                             @version,
                             @run_name,
                             run_time(example)])
    status
  end

  # Names of the tests of this run already finished with one of the statuses
  # @param statuses [Array<String>] statuses which mean that the test should not be run again
  # @return [Array<String>] names of the finished tests
  def completed_tests(statuses)
    return [] unless StaticData.skip_completed_tests?

    CsvReport.read(@path)
             .select { |row| row['Run'] == @run_name && statuses.include?(row['Status']) }
             .map { |row| row['Test_name'] }
             .uniq
  end

  # Leaves the actual result of every test in the report, saves the report with the failed tests only
  # and prints the results to the console
  # @return [nil]
  def handler
    rows = actual_results(CsvReport.read(@path))
    return OnlyofficeLoggerHelper.log("No results in #{@path}") if rows.empty?

    CsvReport.save(rows, @path)
    errors = rows.reject { |row| StaticData::POSITIVE_STATUSES.include?(row['Status']) }
    puts("\n#{'-' * 90}\n#{@version}\n#{CsvReport.to_table(errors, titles: CONSOLE_TITLES)}") unless errors.empty?
    log_results(rows, errors)
    nil
  end

  private

  # The test can be run several times, only the last of its results is actual
  # @param rows [Array<Hash>] all rows of the report
  # @return [Array<Hash>] one row per test
  def actual_results(rows)
    rows.to_h { |row| [[row['Run'], row['Test_name']], row] }.values
  end

  def log_results(rows, errors)
    OnlyofficeLoggerHelper.log("Report: #{@path}")
    if errors.empty?
      File.delete(@errors_path) if File.file?(@errors_path)
      return OnlyofficeLoggerHelper.green_log("All #{rows.count} tests passed")
    end

    CsvReport.save(errors, @errors_path)
    OnlyofficeLoggerHelper.red_log("Failed tests: #{errors.count} of #{rows.count}, report: #{@errors_path}")
  end

  # @param file_data [Integer, nil] size of the converted image
  # @param server_response [String, nil] raw response of the convert service
  # @return [String, nil] additional info about the result
  def extra_info(file_data, server_response)
    return "image size (byte): #{file_data}" if file_data

    error = parse_server_response(server_response)
    error ? "server error: #{error}" : nil
  end

  # @param server_response [String, nil] raw response of the convert service
  # @return [String, nil] short error text if the response contains it
  def parse_server_response(server_response)
    %r{<Error>.[1-8]</Error>}.match(server_response.to_s)&.to_s
  end

  # Rspec fills `run_time` only after the `after` hooks, so it is counted from the start of the example
  def run_time(example)
    result = example.metadata[:execution_result]
    return result.run_time.round(2) if result.run_time

    result.started_at ? (Time.now - result.started_at).round(2) : nil
  end

  def report_name
    @version[VERSION_PATTERN] || @version.gsub(/[^\w.-]+/, '_').gsub(/\A_+|_+\z/, '')
  end
end
