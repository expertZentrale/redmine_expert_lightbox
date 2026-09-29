# Adds the "Image preview" tab to the project settings.
#
# UnboundMethod capture, not prepend + super. project_settings_tabs is wrapped by
# several plugins in this deployment (redmine_agile, redmine_contacts,
# redmine_contacts_helpdesk) with alias_method pairs, and prepend collides with
# every one of them ("super: no superclass method"). Calling an explicitly
# captured original is immune to ordering and to chaining.
module RedmineExpertLightbox
  module Patches
    module ProjectsHelperPatch
      def self.apply!(base = ProjectsHelper)
        return if base.instance_variable_get(:@expert_lightbox_tabs_patched)

        original = base.instance_method(:project_settings_tabs)
        base.send(:define_method, :project_settings_tabs) do
          tabs = original.bind(self).call
          # Gated on core's edit_project, so no role needs extra configuration.
          if User.current.allowed_to?(:edit_project, @project)
            tabs << {
              :name => 'expert_lightbox',
              :action => :edit_project,
              :partial => 'projects/settings/expert_lightbox',
              :label => :label_expert_lightbox_settings_tab
            }
          end
          tabs
        end
        base.instance_variable_set(:@expert_lightbox_tabs_patched, true)
      end
    end
  end
end
