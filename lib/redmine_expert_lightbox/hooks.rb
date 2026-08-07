# Loads the lightbox assets into every page's <head>.
#
# Unlike the old redmine_lightbox2 fork this does NOT gate on controller class. That
# allowlist (IssuesController, WikiController, ... plus const_defined? probes for
# third-party controllers) goes stale as soon as a plugin adds a page with attachments.
# The script is tiny and completely inert until a matching link is clicked, so loading
# it unconditionally is both simpler and more robust.
module RedmineExpertLightbox
  class Hooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context = {})
      # Config is handed over as a JSON island rather than generated JS, so the script
      # itself stays static and cacheable. inlineUrl/downloadUrl carry the app's
      # relative_url_root and the {id}/{name} placeholders the script substitutes.
      # (Built by hand rather than via the named routes: both routes constrain :id to
      # /\d+/, so Rails refuses to generate a path for a non-numeric placeholder.)
      root = Redmine::Utils.relative_url_root.to_s
      config = {
        :root        => root,
        :inlineUrl   => "#{root}/expert_lightbox/inline/__ID__/__NAME__",
        :downloadUrl => "#{root}/attachments/download/__ID__/__NAME__",
        :labels => {
          :close    => l(:label_expert_lightbox_close),
          :prev     => l(:label_expert_lightbox_previous),
          :next     => l(:label_expert_lightbox_next),
          :download => l(:label_expert_lightbox_download),
          :dialog   => l(:label_expert_lightbox_dialog)
        }
      }
      stylesheet_link_tag('expert_lightbox', :plugin => 'redmine_expert_lightbox') +
        content_tag(:script, config.to_json.html_safe,
                    :type => 'application/json', :id => 'expert-lightbox-config') +
        javascript_include_tag('expert_lightbox', :plugin => 'redmine_expert_lightbox')
    end
  end
end
