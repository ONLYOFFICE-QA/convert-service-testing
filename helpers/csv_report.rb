# frozen_string_literal: true

require 'csv'
require 'fileutils'

# Low level utility for reading, writing and merging csv reports
class CsvReport
  DEFAULT_DELIMITER = "\t"

  class << self
    # Creates the report with titles, does nothing if the report already exists
    # @param file_path [String] path to the csv file
    # @param titles [Array] titles of the columns
    # @param delimiter [String] delimiter used in the csv file
    # @return [String, nil] path to the created file, nil if the report already exists
    def create(file_path, titles, delimiter: DEFAULT_DELIMITER)
      FileUtils.mkdir_p(File.dirname(file_path))
      File.open(file_path, File::WRONLY | File::CREAT | File::EXCL) do |file|
        file.write(CSV.generate_line(titles, col_sep: delimiter))
      end
      file_path
    rescue Errno::EEXIST
      nil
    end

    # Adds one row to the end of the report
    # @param file_path [String] path to the csv file
    # @param row [Array] values of the row
    # @param delimiter [String] delimiter used in the csv file
    # @return [nil]
    # @note the exclusive lock allows several rspec processes to write to the same report
    def append(file_path, row, delimiter: DEFAULT_DELIMITER)
      FileUtils.mkdir_p(File.dirname(file_path))
      File.open(file_path, 'a') do |file|
        file.flock(File::LOCK_EX)
        file.write(CSV.generate_line(row, col_sep: delimiter))
      end
      nil
    end

    # Reads the csv file
    # @param file_path [String] path to the csv file
    # @param delimiter [String] delimiter used in the csv file
    # @return [Array<Hash>] rows of the csv file, empty array if the file does not exist
    def read(file_path, delimiter: DEFAULT_DELIMITER)
      return [] unless File.file?(file_path)

      CSV.read(file_path, col_sep: delimiter, headers: true).map(&:to_h)
    end

    # Rewrites the report with the given rows
    # @param rows [Array<Hash>] rows to save
    # @param file_path [String] path to the csv file
    # @param delimiter [String] delimiter used in the csv file
    # @return [String, nil] path to the saved file, nil if there is nothing to save
    # @note the report is replaced by the temporary file, so it never stays partially written
    def save(rows, file_path, delimiter: DEFAULT_DELIMITER)
      return nil if rows.empty?

      titles = rows.first.keys
      tmp_path = "#{file_path}.#{Process.pid}.tmp"
      FileUtils.mkdir_p(File.dirname(file_path))
      CSV.open(tmp_path, 'w', col_sep: delimiter) do |csv|
        csv << titles
        rows.each { |row| csv << titles.map { |title| row[title] } }
      end
      File.rename(tmp_path, file_path)
      file_path
    end

    # Merges several csv reports into the one
    # @param reports [Array<String>] paths to the csv reports
    # @param result_path [String] path to the merged csv report
    # @param delimiter [String] delimiter used in the csv files
    # @return [String, nil] path to the merged report, nil if there is nothing to merge
    def merge(reports, result_path, delimiter: DEFAULT_DELIMITER)
      rows = reports.select { |report| File.file?(report) }
                    .flat_map { |report| read(report, delimiter: delimiter) }
      save(rows, result_path, delimiter: delimiter)
    end

    # Formats rows as an aligned text table for the console output
    # @param rows [Array<Hash>] rows to format
    # @param titles [Array<String>] columns to print, all columns by default
    # @return [String] formatted table
    def to_table(rows, titles: nil)
      return '' if rows.empty?

      titles ||= rows.first.keys
      widths = column_widths(rows, titles)
      header = titles.map { |title| title.ljust(widths[title]) }.join(' | ')
      body = rows.map { |row| table_row(row, titles, widths) }
      [header, titles.map { |title| '-' * widths[title] }.join('-+-'), *body].join("\n")
    end

    private

    def column_widths(rows, titles)
      titles.to_h do |title|
        values = rows.map { |row| row[title].to_s.length }
        [title, values.push(title.length).max]
      end
    end

    def table_row(row, titles, widths)
      titles.map { |title| row[title].to_s.ljust(widths[title]) }.join(' | ')
    end
  end
end
