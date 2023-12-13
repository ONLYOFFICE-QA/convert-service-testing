# frozen_string_literal: true

require './spec/spec_helper'

palladium = PalladiumHelper.new DocumentServerHelper.get_version, 'Documents to All'
result_sets = palladium.get_result_sets StaticData::POSITIVE_STATUSES
files = JSON.load_file(File.join(Dir.pwd, 'assets', 'testing_files.json'))['documents']
output_formats = JSON.load_file(File.join(Dir.pwd, 'assets', 'output_formats.json'))

describe 'Convert documents to all formats by convert service' do
  before do
    @metadata = nil
    @tmp_dir = FileHelper.create_tmp_dir
  end

  files.each do |s3_file_path|
    input_format = File.extname(s3_file_path).delete('.').to_s
    formats = output_formats.key?(input_format) ? output_formats[input_format] : output_formats['documents']

    formats.each do |format|
      test_name = "#{input_format} to #{format}"
      next if result_sets.include?(test_name) || input_format == format

      it test_name do
        file_path = s3.download_file_by_name(s3_file_path, @tmp_dir)
        result_path = File.join(@tmp_dir, "#{File.basename(s3_file_path)}.#{format}")
        @metadata = converter.perform_convert(url: file_uri(file_path), outputtype: format)
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