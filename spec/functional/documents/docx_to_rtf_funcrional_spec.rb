# frozen_string_literal: true

require './spec/spec_helper'
FileHelper.clear_dir 'files_tmp'
palladium = PalladiumHelper.new DocumentServerHelper.get_version, 'Docx to Rtf'
result_sets = palladium.get_result_sets StaticData::POSITIVE_STATUSES
files = s3.files_from_folder 'docx'
describe 'Convert docx to rtf by convert service' do
  before do
    @metadata = nil
  end

  (files - result_sets.map { |result_set| "docx/#{result_set}" }).each do |file_path|
    it File.basename(file_path) do
      s3.download_file_by_name(file_path, './files_tmp')
      @metadata = converter.perform_convert(url: file_uri(file_path), outputtype: 'rtf')
      expect(@metadata[:url]).not_to be_nil
      expect(@metadata[:url]).not_to be_empty
      @metadata[:file_path] = FileHelper.download_file(@metadata[:url])
      expect(File).to exist(@metadata[:file_path])
    end
  end
  after do |example|
    FileHelper.clear_dir('files_tmp')
    palladium.add_result_and_log(example)
  end
end