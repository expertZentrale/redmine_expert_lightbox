# Redmine expert Lightbox Plugin
#
# Copyright (C) 2026 Dennis Buehring
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version. See LICENSE for the full text.

require 'redmine'

Redmine::Plugin.register :redmine_expert_lightbox do
  name 'Redmine expert Lightbox'
  author 'Dennis Buehring'
  description 'Preview image and PDF attachments in a modal dialog. No jQuery, no third-party libraries, works on Redmine 5.1 - 7.x.'
  version '1.2.0'
  url 'https://github.com/expertZentrale/redmine_expert_lightbox'
  requires_redmine :version_or_higher => '5.0'

  # Blank = no limit. Installs that predate these keys read nil until the form is
  # saved once; ExpertLightboxProjectSetting.global_limits treats that as blank.
  settings :default => { 'inline_max_width' => '', 'inline_max_height' => '' },
           :partial => 'settings/expert_lightbox_settings'
end

require File.expand_path('../lib/redmine_expert_lightbox/hooks', __FILE__)
require File.expand_path('../lib/redmine_expert_lightbox/patches/projects_helper_patch', __FILE__)

# Applied directly, not from a to_prepare block: Redmine already runs init.rb
# inside to_prepare, so a block registered here would never fire in production.
RedmineExpertLightbox::Patches::ProjectsHelperPatch.apply!
