# frozen_string_literal: true

require './spec/spec_helper'

palladium = PalladiumHelper.new DocumentServerHelper.get_version, 'Protected Spreadsheets to All'
result_sets = palladium.get_result_sets StaticData::POSITIVE_STATUSES
files = StaticData::SPREADSHEETS['protected_spreadsheets']
output_formats = StaticData::OUTPUT_FORMATS

describe 'Convert protected spreadsheets to all formats by convert service' do
  before do
    @metadata = nil
    @tmp_dir = FileHelper.create_tmp_dir
  end

  files.each do |s3_file_path|
    input_format = File.extname(s3_file_path).delete('.').to_s
    out_formats = output_formats.key?(input_format) ? output_formats[input_format] : output_formats['spreadsheets']

    out_formats.each do |out_format|
      test_name = "#{input_format} to #{out_format}"
      next if result_sets.include?(test_name) || input_format == out_format

      it test_name do
        file_path = s3.download_file_by_name(s3_file_path, @tmp_dir)
        result_path = File.join(@tmp_dir, "#{File.basename(s3_file_path)}.#{out_format}")
        password = File.basename(s3_file_path).match(/\[pass(\d+)\]/)&.[](1)
        @metadata = converter.perform_convert(url: file_uri(file_path), outputtype: out_format, password: password)
        expect(@metadata[:url]).not_to be_nil
        expect(@metadata[:url]).not_to be_empty
        FileHelper.download_file(@metadata[:url], result_path)
        expect(File).to exist(result_path)
      end
    end
  end

  after do |example|
    FileUtils.rm_rf(@tmp_dir, secure: true)
    palladium.add_result_and_log(example)
  end
end
