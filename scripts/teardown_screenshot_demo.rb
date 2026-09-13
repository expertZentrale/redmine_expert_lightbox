# Removes everything scripts/seed_screenshot_demo.rb created.
#
#   bundle exec rails runner plugins/redmine_expert_lightbox/scripts/teardown_screenshot_demo.rb
#
# Reads the ids the seed recorded in the `expert_lightbox_screenshot_backup`
# settings row and deletes exactly those. Without that row it deletes nothing:
# guessing from names would risk taking real rows with it.
#
# Destroying the project takes its issues, wiki, documents and files with it,
# and Redmine's own callbacks remove the attachment files from disk.

require 'json'

BACKUP_KEY = 'expert_lightbox_screenshot_backup'.freeze
LOGIN      = 'm.keller'.freeze

def say(msg)
  puts("[teardown] #{msg}")
end

raw = Setting.where(:name => BACKUP_KEY).pick(:value)
if raw.blank?
  abort "[teardown] No #{BACKUP_KEY} row - nothing to undo."
end

backup   = JSON.parse(raw)
projects = Project.where(id: Array(backup['project_ids']))

say "removing #{projects.count} project(s), " \
    "#{Issue.where(project_id: projects.select(:id)).count} issue(s) and " \
    "their attachments"
projects.destroy_all

# Only the account the seed itself created. The seed refuses to adopt a
# pre-existing login precisely so that this delete can never reach a real user,
# but check the login as well before destroying anything.
if backup['user_id']
  user = User.find_by(id: backup['user_id'])
  if user.nil?
    say 'capture user already gone'
  elsif user.login != LOGIN
    say "user ##{user.id} is now '#{user.login}', not '#{LOGIN}' - leaving it alone"
  else
    Token.where(user_id: user.id).delete_all
    user.destroy
    say 'removed the capture user'
  end
end

Setting.where(:name => BACKUP_KEY).delete_all
say "done. projects=#{Project.count} issues=#{Issue.count} attachments=#{Attachment.count}"
