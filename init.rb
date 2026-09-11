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
  version '1.1.0'
  url 'https://github.com/expertZentrale/redmine_expert_lightbox'
  requires_redmine :version_or_higher => '5.0'
end

require File.expand_path('../lib/redmine_expert_lightbox/hooks', __FILE__)
