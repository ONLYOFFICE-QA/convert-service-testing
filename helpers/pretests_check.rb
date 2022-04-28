# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'

# class with methods for check working system before run tests
class PretestsCheck
  # Sends a deliberately invalid request, checking the error code
  # @return [TrueClass, FalseClass] true if valid error == -8 (invalid token)
  def self.jwt_enable?
    url = URI("#{StaticData.documentserver_url}/ConvertService.ashx")
    http = Net::HTTP.new(url.host, url.port)
    request = Net::HTTP::Post.new(url)
    request['Content-Type'] = 'application/json'
    request.body = JSON.dump({})
    response = http.request(request)
    xml = Nokogiri.XML(response.body)
    StaticData::INVALID_TOKEN_ERROR === xml.xpath('//Error').text
  end

  def self.pretests_check
    FileHelper.check_temp_dir('files_tmp')
    documentserver_check = documentserver_available?
    nginx_check = nginx_available?
    s3_check = s3_available?
    palladium_token = palladium_token?

    unless s3_check && documentserver_check && nginx_check && palladium_token
      colorize_log("Documentserver check: #{documentserver_check}")
      colorize_log("Nginx check: #{nginx_check}")
      colorize_log("S3 check: #{s3_check}")
      colorize_log("Palladium token: #{palladium_token}")
      raise 'Pre-test checks is failed!'
    end
    FileHelper.clear_dir('files_tmp')
  end

  def self.documentserver_available?
    OnlyofficeLoggerHelper.log("Check documentserver is available #{StaticData.documentserver_url}")
    status = request_to(StaticData.documentserver_url)

    OnlyofficeLoggerHelper.log("Documentserver on #{StaticData.documentserver_url} is unavailable") unless status
    status
  end

  def self.nginx_available?
    random_file_name = "#{Time.now.nsec}.txt"
    FileHelper.create_file("#{StaticData::TMP_FOLDER}/#{random_file_name}")
    status = request_to("#{StaticData.nginx_url}/#{random_file_name}")
    unless status
      OnlyofficeLoggerHelper.log("Nginx server on #{StaticData.nginx_url} can not send files fom #{StaticData::TMP_FOLDER} folder")
    end
    status
  end

  def self.s3_available?
    s3 = OnlyofficeS3Wrapper::AmazonS3Wrapper.new(bucket_name: 'conversion-testing-files', region: 'us-east-1')
    path = s3.download_file_by_name('docx/Doc8.docx', './files_tmp')
    File.file?(path) && File.size(path) > 1000
  end

  def self.request_to(path)
    url = URI.parse(path)
    req = Net::HTTP.new(url.host, url.port)
    req.use_ssl = (url.scheme == 'https')
    path = if url.path.empty?
             '/'
           else
             url.path
           end
    res = req.request_get(path)
    res.code != '404'
  rescue StandardError
    false
  end

  def self.palladium_token?
    return true unless File.read("#{ENV['HOME']}/.palladium/token").strip.empty?

    false
  rescue Errno::ENOENT => e
    OnlyofficeLoggerHelper.log(e.to_s)
    false
  end

  def self.colorize_log(entry)
    case entry
    when /true$/
      OnlyofficeLoggerHelper.green_log(entry)
    else
      OnlyofficeLoggerHelper.red_log(entry)
    end
  end
end
