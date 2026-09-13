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
projects = Project.where(:id => Array(backup['project_ids']))

say "removing #{projects.count} project(s), " \
    "#{Issue.where(:project_id => projects.select(:id)).count} issue(s) and " \
    "their attachments"
projects.destroy_all

# Only the account the seed itself created. The seed refuses to adopt a
# pre-existing login precisely so that this delete can never reach a real user,
# but check the login as well before destroying anything.
# Destroying the project takes its issues, wiki, documents and files with it, but
# an attachment whose container row is gone leaves the file on disk. Sweep any
# the capture user authored whose container no longer exists - authored-by keeps
# this from ever reaching an attachment the demo did not create.
# The same identity check the user delete makes, applied before the sweep rather
# than after it: if someone renamed the recorded account while the backup row
# stayed behind, this must not go looking through a real user's attachments.
capture_user = backup['user_id'] ? User.find_by(:id => backup['user_id']) : nil
if capture_user && capture_user.login != LOGIN
  say "user ##{capture_user.id} is now '#{capture_user.login}', not '#{LOGIN}' - leaving it and its attachments alone"
  capture_user = nil
end

if capture_user
  orphans = Attachment.where(:author_id => capture_user.id).select do |a|
    # attach! saves the row before assigning its container, so an interrupted
    # seed leaves attachments with no container at all - those are orphans too.
    next true if a.container_type.blank?

    klass = a.container_type.safe_constantize
    # An unknown container class means nothing can own this row any more.
    next true if klass.nil?

    # No blanket rescue here: a transient database error must not read as
    # "container missing" and take a live attachment with it. Let it raise.
    !klass.exists?(a.container_id)
  end
  if orphans.any?
    say "removing #{orphans.size} orphaned attachment(s)"
    orphans.each(&:destroy)
  end
end

if capture_user
  Token.where(:user_id => capture_user.id).delete_all
  capture_user.destroy
  say 'removed the capture user'
elsif backup['user_id']
  say 'capture user already gone or not ours'
end

Setting.where(:name => BACKUP_KEY).delete_all
say "done. projects=#{Project.count} issues=#{Issue.count} attachments=#{Attachment.count}"
