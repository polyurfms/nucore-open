# frozen_string_literal: true

require "csv"

class Reports::DoorAccessExport 
  def initialize(list)
    @list = list
  end

  def export!
    attributes = %w{StartTime	EndTime CardID DoorName} 

    CSV.generate(headers: true) do |csv|
      csv << attributes
      unless @list.empty?
        @list.each do |record|
          csv << [record[:start_datetime].strftime("%Y-%m-%d %H:%M:%S"), record[:end_datetime].strftime("%Y-%m-%d %H:%M:%S"), record[:uid], record[:room_no]]
        end
      end
    end
  end
end
