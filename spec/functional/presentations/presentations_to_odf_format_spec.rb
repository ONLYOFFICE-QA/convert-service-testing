# frozen_string_literal: true

require './spec/spec_helper'
require 'nokogiri'

report = TestReport.new(DocumentServerHelper.get_version, 'Presentations to odf')
completed_tests = report.completed_tests(StaticData::POSITIVE_STATUSES)
files = StaticData::PRESENTATIONS['presentations_to_odf']

describe 'Convert presentations to odf by convert service' do
  before do
    @metadata = nil
    @tmp_dir = FileHelper.create_tmp_dir
  end

  files.each do |s3_file_path|
    test_name = "#{File.extname(s3_file_path).delete('.')} to odf"
    next if completed_tests.include?(test_name)

    it test_name do
      file_path = s3.download_file_by_name(s3_file_path, @tmp_dir)
      @metadata = converter.perform_convert(url: file_uri(file_path), outputtype: 'odf')[:data]
      data = Nokogiri::XML(@metadata)
      expect(data.at('FileResult/FileUrl').text).not_to be_nil
      expect(data.at('FileResult/FileUrl').text).not_to be_empty
      expect(data.at('FileResult/FileType').text).to eq('odp')
      result_path = File.join(@tmp_dir, "#{File.basename(s3_file_path)}.#{data.at('FileResult/FileType').text}")
      FileHelper.download_file(data.at('FileResult/FileUrl').text, result_path)
      expect(File).to exist(result_path)
    end
  end

  after do |example|
    FileUtils.rm_rf(@tmp_dir, secure: true)
    report.add_result_and_log(example)
  end
end
