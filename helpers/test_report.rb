# frozen_string_literal: true

require_relative 'csv_report'
require_relative 'example_status'

# Collects rspec results of the one run and writes them to the csv report
class TestReport
  TITLES = %w[Test_name Status Comment Extra_info Version Run Time].freeze
  CONSOLE_TITLES = %w[Test_name Status Comment Extra_info].freeze
  VERSION_PATTERN = /\d+\.\d+\.\d+\.\d+/

  attr_reader :path, :errors_path, :run_name, :version

  class << self
    # @return [Array<TestReport>] reports created during the current rspec run
    def reports
      @reports ||= []
    end

    # Prints results of all reports created during the current rspec run
    # @return [nil]
    def print_summary
      reports.each(&:handler)
      nil
    end
  end

  # @param version [String] tested documentserver version, used as a report directory name
  # @param run_name [String] name of the run, used as a report file name
  # @param reports_dir [String] root directory for all reports
  def initialize(version, run_name, reports_dir: StaticData.reports_folder)
    @version = version.to_s.strip.empty? ? 'unknown' : version.to_s.strip
    @run_name = run_name
    @dir = File.join(reports_dir, version_dir_name)
    name = file_name
    @path = File.join(@dir, "#{name}.csv")
    @errors_path = File.join(@dir, "#{name}(errors_only).csv")
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
    CsvReport.write(@path, 'w', TITLES) unless File.file?(@path)
    CsvReport.write(@path, 'a', [example.metadata[:description],
                                 status,
                                 comment,
                                 extra_info(file_data, server_response),
                                 @version,
                                 @run_name,
                                 run_time(example)])
    status
  end

  # Names of the tests already finished with one of the statuses in the reports of the previous runs
  # @param statuses [Array<String>] statuses which mean that the test should not be run again
  # @return [Array<String>] names of the finished tests
  def completed_tests(statuses)
    return [] unless StaticData.skip_completed_tests?

    previous_reports.flat_map do |report|
      CsvReport.read(report)
               .select { |row| statuses.include?(row['Status']) }
               .map { |row| row['Test_name'] }
    end.uniq
  end

  # Prints results of the run and saves the report with the failed tests only
  # @return [nil]
  def handler
    rows = CsvReport.read(@path)
    return OnlyofficeLoggerHelper.log("No new results for `#{@run_name}`") if rows.empty?

    errors = rows.reject { |row| StaticData::POSITIVE_STATUSES.include?(row['Status']) }
    puts("\n#{'-' * 90}\n#{@run_name}\n#{CsvReport.to_table(errors, titles: CONSOLE_TITLES)}") unless errors.empty?
    log_paths(rows, errors)
    nil
  end

  private

  def log_paths(rows, errors)
    CsvReport.save(errors, @errors_path)
    OnlyofficeLoggerHelper.log("Report: #{@path}")
    return OnlyofficeLoggerHelper.green_log("All #{rows.count} tests passed") if errors.empty?

    OnlyofficeLoggerHelper.red_log("Failed tests: #{errors.count} of #{rows.count}, report: #{@errors_path}")
  end

  # @return [Array<String>] paths to the reports of the same run and version written before the current one
  def previous_reports
    Dir.glob(File.join(@dir, "#{sanitize(@run_name)}_*.csv"))
       .reject { |report| report.end_with?('(errors_only).csv') }
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

  def version_dir_name
    @version[VERSION_PATTERN] || sanitize(@version)
  end

  # Timestamp and rspec process number keep reports of the parallel and repeated runs separated
  def file_name
    [sanitize(@run_name),
     Time.now.strftime('%Y_%m_%d_%H_%M_%S'),
     ENV.fetch('TEST_ENV_NUMBER', nil)].compact.reject(&:empty?).join('_')
  end

  def sanitize(value)
    value.gsub(/[^\w.-]+/, '_').gsub(/\A_+|_+\z/, '')
  end
end
