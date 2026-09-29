# Per-project override of the inline image size limit. One row per project at most;
# a project without a row (or with override = false) follows the global setting.
class CreateExpertLightboxProjectSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :expert_lightbox_project_settings do |t|
      # Plain integer, not t.references: Redmine's projects.id is a 4-byte int and
      # MySQL refuses a foreign key between columns of different widths.
      t.integer :project_id, :null => false
      t.boolean :override, :null => false, :default => false
      t.integer :inline_max_width
      t.integer :inline_max_height
      t.timestamps
    end
    add_index :expert_lightbox_project_settings, :project_id, :unique => true
    # Cascade so deleting a project takes its row along, without patching Project.
    add_foreign_key :expert_lightbox_project_settings, :projects, :on_delete => :cascade
  end
end
