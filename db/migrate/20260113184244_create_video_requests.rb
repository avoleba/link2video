# db/migrate/20240101_create_video_requests.rb
class CreateVideoRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :video_requests do |t|
      t.string :url, null: false
      t.string :video_url
      t.string :thumbnail_url
      t.string :title
      t.string :duration
      t.string :author
      t.bigint :telegram_chat_id
      t.bigint :telegram_message_id
      
      t.integer :status, default: 0, null: false  # pending: 0
      t.integer :platform, default: 3, null: false  # unknown: 3
      
      t.text :error_message
      t.jsonb :result_data, default: {}
      
      # t.references :user, foreign_key: true
      
      t.datetime :processed_at
      t.timestamps
    end
    
    add_index :video_requests, :telegram_chat_id
    add_index :video_requests, :status
    add_index :video_requests, :platform
    add_index :video_requests, :created_at
  end
end