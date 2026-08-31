# frozen_string_literal: true

require 'tmpdir'

describe CsvReport do
  let(:tmp_dir) { Dir.mktmpdir('csv-report-') }

  after { FileUtils.remove_entry(tmp_dir) }

  it 'creates the report with titles and rows' do
    path = File.join(tmp_dir, 'nested', 'report.csv')
    described_class.write(path, 'w', %w[Test_name Status])
    described_class.write(path, 'a', ['docx to pdf', 'passed'])
    expect(described_class.read(path)).to eq([{ 'Test_name' => 'docx to pdf', 'Status' => 'passed' }])
  end

  it 'returns an empty array for a non-existent report' do
    expect(described_class.read(File.join(tmp_dir, 'unknown.csv'))).to eq([])
  end

  it 'saves rows to the new report' do
    path = File.join(tmp_dir, 'saved.csv')
    rows = [{ 'Test_name' => 'docx to pdf', 'Status' => 'failed' }]
    expect(described_class.save(rows, path)).to eq(path)
    expect(described_class.read(path)).to eq(rows)
  end

  it 'does not save an empty report' do
    path = File.join(tmp_dir, 'empty.csv')
    expect(described_class.save([], path)).to be_nil
    expect(File).not_to exist(path)
  end

  it 'merges several reports into the one' do
    first = File.join(tmp_dir, 'first.csv')
    second = File.join(tmp_dir, 'second.csv')
    described_class.save([{ 'Test_name' => 'docx to pdf', 'Status' => 'passed' }], first)
    described_class.save([{ 'Test_name' => 'docx to odt', 'Status' => 'failed' }], second)
    merged = described_class.merge([first, second], File.join(tmp_dir, 'merged.csv'))
    expect(described_class.read(merged).map { |row| row['Test_name'] }).to eq(['docx to pdf', 'docx to odt'])
  end

  it 'formats rows as a table with the selected columns' do
    rows = [{ 'Test_name' => 'docx to pdf', 'Status' => 'failed' }]
    expect(described_class.to_table(rows, titles: ['Status'])).to eq("Status\n------\nfailed")
  end
end
