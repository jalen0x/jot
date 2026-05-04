class AddGeoLocationToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :geo_latitude, :decimal, precision: 10, scale: 7, null: true, comment: "Optional geographic latitude"
    add_column :transactions, :geo_longitude, :decimal, precision: 10, scale: 7, null: true, comment: "Optional geographic longitude"

    add_check_constraint :transactions,
      "geo_latitude IS NULL OR geo_latitude BETWEEN -90 AND 90",
      name: "transactions_geo_latitude_range"
    add_check_constraint :transactions,
      "geo_longitude IS NULL OR geo_longitude BETWEEN -180 AND 180",
      name: "transactions_geo_longitude_range"
    add_check_constraint :transactions,
      "(geo_latitude IS NULL AND geo_longitude IS NULL) OR (geo_latitude IS NOT NULL AND geo_longitude IS NOT NULL)",
      name: "transactions_geo_location_pair"
  end
end
