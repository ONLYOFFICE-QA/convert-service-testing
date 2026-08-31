# frozen_string_literal: true

require 'tmpdir'

describe TestReport do
  let(:tmp_dir) { Dir.mktmpdir('test-report-') }
  let(:version) { '10.0.0.44 (build:44)' }
  let(:run_name) { 'Documents to All' }
  let(:report) { described_class.new(version, run_name, reports_dir: tmp_dir) }

  after { FileUtils.remove_entry(tmp_dir) }

  # Builds a stub of the finished rspec example
  # @param description [String] name of the test
  # @param exception [Exception, nil] exception raised by the test
  # @param pending [Boolean] whether the test is pending
  # @param pending_message [String, nil] reason of the pending test
  # @return [RSpec::Mocks::InstanceVerifyingDouble] stub of the rspec example
  def example_stub(description, exception: nil, pending: false, pending_message: nil)
    execution_result = instance_double(RSpec::Core::Example::ExecutionResult,
                                       pending_message: pending_message,
                                       run_time: 1.234)
    instance_double(RSpec::Core::Example,
                    metadata: { description: description, execution_result: execution_result },
                    exception: exception,
                    pending: pending)
  end

  # Writes the report of the previous run of the same version
  # @param results [Array<Array>] test names with their statuses
  # @param run [String] name of the run
  # @return [String] path to the report
  def write_previous_report(results, run: run_name)
    CsvReport.create(report.path, described_class::TITLES)
    results.each { |name, status| CsvReport.append(report.path, [name, status, '', '', version, run, 1.0]) }
    report.path
  end

  it 'stores the report named by the documentserver version' do
    expect(report.path).to eq(File.join(tmp_dir, '10.0.0.44', '10.0.0.44.csv'))
    expect(report.errors_path).to eq(File.join(tmp_dir, '10.0.0.44', '10.0.0.44(errors_only).csv'))
  end

  it 'writes results of all runs of the version to the same report' do
    expect(described_class.new(version, 'Documents to Odf', reports_dir: tmp_dir).path).to eq(report.path)
  end

  it 'writes the passed result' do
    expect(report.add_result(example_stub('docx to pdf'))).to eq('passed')
    expect(CsvReport.read(report.path).first)
      .to include('Test_name' => 'docx to pdf', 'Status' => 'passed', 'Comment' => 'Ok',
                  'Run' => run_name, 'Version' => version, 'Time' => '1.23')
  end

  it 'counts the time of the example when rspec has not filled it yet' do
    execution_result = instance_double(RSpec::Core::Example::ExecutionResult,
                                       run_time: nil,
                                       started_at: Time.now - 5)
    example = instance_double(RSpec::Core::Example,
                              metadata: { description: 'docx to pdf', execution_result: execution_result },
                              exception: nil,
                              pending: false)
    report.add_result(example)
    expect(CsvReport.read(report.path).first['Time'].to_f).to be_within(0.5).of(5)
  end

  it 'writes the failed result with the single line comment' do
    exception = RSpec::Expectations::ExpectationNotMetError.new("expected: nil\ngot: 1")
    expect(report.add_result(example_stub('docx to odt', exception: exception))).to eq('failed')
    expect(CsvReport.read(report.path).first)
      .to include('Status' => 'failed', 'Comment' => 'expected: nil got: 1')
  end

  it 'writes the aborted result for an unexpected error' do
    expect(report.add_result(example_stub('docx to txt', exception: ArgumentError.new('no host')))).to eq('aborted')
    expect(CsvReport.read(report.path).first).to include('Status' => 'aborted', 'Comment' => 'ArgumentError: no host')
  end

  it 'writes the pending result with the reason' do
    example = example_stub('odt to docm', pending: true, pending_message: 'bug 61652')
    expect(report.add_result(example)).to eq('pending')
    expect(CsvReport.read(report.path).first).to include('Status' => 'pending', 'Comment' => 'bug 61652')
  end

  it 'writes the size of the converted image' do
    report.add_result(example_stub('docx to png'), 5327)
    expect(CsvReport.read(report.path).first).to include('Extra_info' => 'image size (byte): 5327')
  end

  it 'writes the error of the convert service' do
    report.add_result(example_stub('docx to pdf'), nil, '<FileResult><Error>-4</Error></FileResult>')
    expect(CsvReport.read(report.path).first).to include('Extra_info' => 'server error: <Error>-4</Error>')
  end

  it 'returns the tests completed with a positive status in the previous runs' do
    write_previous_report([['docx to pdf', 'passed'], ['docx to odt', 'failed'], ['docx to txt', 'pending']])
    expect(report.completed_tests(StaticData::POSITIVE_STATUSES)).to eq(['docx to pdf', 'docx to txt'])
  end

  it 'returns the completed tests of its own run only' do
    write_previous_report([['docx to pdf', 'passed']], run: 'Documents to Odf')
    expect(report.completed_tests(StaticData::POSITIVE_STATUSES)).to eq([])
  end

  it 'returns no completed tests when the previous results are disabled' do
    write_previous_report([['docx to pdf', 'passed']])
    allow(StaticData).to receive(:skip_completed_tests?).and_return(false)
    expect(report.completed_tests(StaticData::POSITIVE_STATUSES)).to eq([])
  end

  it 'leaves the last result of the test in the report' do
    write_previous_report([['docx to pdf', 'failed']])
    report.add_result(example_stub('docx to pdf'))
    report.handler
    expect(CsvReport.read(report.path)).to contain_exactly(include('Test_name' => 'docx to pdf',
                                                                   'Status' => 'passed'))
  end

  it 'saves the report with the failed tests only' do
    report.add_result(example_stub('docx to pdf'))
    report.add_result(example_stub('docx to odt', exception: ArgumentError.new('no host')))
    report.handler
    expect(CsvReport.read(report.errors_path).map { |row| row['Test_name'] }).to eq(['docx to odt'])
  end

  it 'deletes the outdated report with the failed tests' do
    report.add_result(example_stub('docx to pdf', exception: ArgumentError.new('no host')))
    report.handler
    report.add_result(example_stub('docx to pdf'))
    report.handler
    expect(File).not_to exist(report.errors_path)
  end

  it 'handles the report of the version only once' do
    second_report = described_class.new(version, 'Documents to Odf', reports_dir: tmp_dir)
    allow(described_class).to receive(:reports).and_return([report, second_report])
    allow(report).to receive(:handler)
    allow(second_report).to receive(:handler)
    described_class.print_summary
    expect(report).to have_received(:handler).once
    expect(second_report).not_to have_received(:handler)
  end
end
