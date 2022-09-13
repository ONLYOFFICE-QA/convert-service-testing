# frozen_string_literal: true

require 'json'

class StaticData
  PROJECT_NAME = 'Convert Service Testing'
  POSITIVE_STATUSES = %w[passed passed_2 pending].freeze
  PALLADIUM_SERVER = 'palladium.teamlab.info'

  MIN_DOCX_IMAGE_SIZE = 5327
  MIN_PPTX_IMAGE_SIZE = 1085
  MIN_XLSX_IMAGE_SIZE = 5384
  MIN_ODT_IMAGE_SIZE = 4149
  MIN_ODS_IMAGE_SIZE = 6021
  MIN_ODP_IMAGE_SIZE = 7788
  MIN_FB2_IMAGE_SIZE = 12_787
  MIN_EPUB_IMAGE_SIZE = 6022
  MIN_HTML_IMAGE_SIZE = 5978
  MIN_MHT_IMAGE_SIZE = 6022
  MIN_XLSB_IMAGE_SIZE = 6021
  MIN_XML_IMAGE_SIZE = 11_932

  TMP_FOLDER = 'files_tmp'

  EXCEPTION_FILES = JSON.load_file("#{Dir.pwd}/config/exception_file.json")

  INVALID_TOKEN_ERROR = '-8'

  def self.jwt_key_in_env?
    ENV.key?('DOCUMENTSERVER_JWT') && ENV.fetch('DOCUMENTSERVER_JWT', '') != ''
  end

  def self.jwt_key_in_config_file?
    File.exist?("#{Dir.home}/.documentserver/documentserver_jwt")
  end

  def self.get_jwt_key
    File.read("#{Dir.home}/.documentserver/documentserver_jwt")
  end

  def self.nginx_url
    ENV.fetch('NGINX', 'http://nginx')
  end

  def self.documentserver_url
    ENV.fetch('DOCUMENTSERVER', 'http://documentserver')
  end

  def self.get_palladium_token
    return ENV.fetch('PALLADIUM_TOKEN') if ENV.key?('PALLADIUM_TOKEN')

    File.read("#{Dir.home}/.palladium/token")
  end
end
