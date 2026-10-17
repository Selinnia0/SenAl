class AddOpenDedupIndexToIncidents < ActiveRecord::Migration[8.1]
  def change
    # (service, dedup_key) için en fazla bir açık (resolved olmayan) olay. status 2 = resolved.
    add_index :incidents, %i[service_id dedup_key], unique: true, where: "status <> 2",
                                                    name: "index_incidents_on_open_dedup_key"
  end
end
