class AddRoomInterfaceEnabledToFacilities < ActiveRecord::Migration[5.2]
  def change
    add_column :facilities, :room_interface_enabled, :boolean, default:false
  end
end
