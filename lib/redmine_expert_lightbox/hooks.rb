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
        javascript_include_tag('expert_lightbox', :plugin => 'redmine_expert_lightbox') +
        inline_size_style(context[:project])
    end

    private

    # Caps inline attachment images in rich text (issue description, notes, wiki,
    # news, forums) at the configured size; a click still opens the original in
    # the lightbox. Only attachment images - external ones cannot be opened in the
    # lightbox, so shrinking them would lose detail for good. The limits are
    # integers from the resolver, so interpolating them into CSS is safe.
    def inline_size_style(project)
      limits = ExpertLightboxProjectSetting.limits_for(project)
      return ''.html_safe unless limits[:width] || limits[:height]

      rules = []
      # min() keeps Redmine's own max-width:100% so narrow columns still win.
      rules << "max-width:min(100%,#{limits[:width].to_i}px)" if limits[:width]
      rules << "max-height:#{limits[:height].to_i}px" if limits[:height]
      # width/height auto keep the aspect ratio even when the markup sets an
      # explicit size; object-fit covers what auto cannot undo.
      rules << 'width:auto;height:auto;object-fit:contain;cursor:zoom-in'
      # Prefix match on this app's own root-relative attachment path (which is how
      # Redmine renders inline attachment images), so an external URL that merely
      # contains /attachments/ - e.g. https://cdn.example/attachments/x.png - is not
      # shrunk. relative_url_root is a deployment path; to_json quotes it for CSS.
      prefix = "#{Redmine::Utils.relative_url_root}/attachments/".to_json
      content_tag(:style, "div.wiki img[src^=#{prefix}]{#{rules.join(';')}}".html_safe,
                  :id => 'expert-lightbox-inline-size')
    end
  end
end
