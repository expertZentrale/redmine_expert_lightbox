# Seeds the demo project used to generate this plugin's screenshots.
#
#   bundle exec rails runner plugins/redmine_expert_lightbox/scripts/seed_screenshot_demo.rb
#
# The plugin has no pages of its own — it is a click handler that opens
# attachments in a dialog — so what a screenshot needs is somewhere with
# attachments worth clicking: an issue carrying images and a PDF, a wiki page
# with an inline image, and a Files entry.
#
# Run it against the parent repo's docker-compose.screenshots.yml, not the dev
# stack. Attachments are written to disk, and that compose file puts
# /usr/src/redmine/files on a named volume shared with the web container —
# without it a `compose run` container takes every uploaded file with it when it
# exits, and the screenshots would show broken thumbnails.
#
# Everything it creates is recorded in a `settings` row named
# `expert_lightbox_screenshot_backup`, and scripts/teardown_screenshot_demo.rb
# removes exactly those rows.
#
# The attachments come from scripts/demo-assets/ and are all synthetic: an
# invented error dialog, an invented type plate, an invented topology and an
# invented inspection report.
#
# Modes:
#   DEMO_PASSWORD=   password for the capture user (random and printed if unset)

require 'json'
require 'securerandom'

IDENT      = 'field-service'.freeze
LOGIN      = 'm.keller'.freeze
BACKUP_KEY = 'expert_lightbox_screenshot_backup'.freeze
ASSETS     = File.expand_path('demo-assets', __dir__)
NOW        = Time.current

def say(msg)
  puts("[seed] #{msg}")
end

def raw_setting(name)
  Setting.where(:name => name).pick(:value)
end

def write_raw_setting!(name, value)
  unless Setting.where(:name => name).exists?
    row = Setting.new
    row.name = name
    row.save(:validate => false)
  end
  Setting.where(:name => name).update_all(:value => value, :updated_on => Time.current)
end

abort "[seed] missing #{ASSETS}" unless Dir.exist?(ASSETS)

# --- Redmine default data -----------------------------------------------------

# A migrated-but-not-seeded database has no trackers or statuses, so there is
# nothing to hang an issue on.
if Redmine::DefaultData::Loader.no_data?
  say 'loading Redmine default data'
  Redmine::DefaultData::Loader.load('en')
end

# --- capture user -------------------------------------------------------------

previous = raw_setting(BACKUP_KEY).presence

password = ENV['DEMO_PASSWORD'].presence || SecureRandom.alphanumeric(20)

# Only ever touch an account this script created. Taking over an existing login
# would mean elevating a real user to admin, resetting their password, and then
# deleting them on teardown.
previous_user_id = previous ? JSON.parse(previous)['user_id'] : nil
existing = User.find_by(login: LOGIN)

if existing && existing.id != previous_user_id
  abort "[seed] A user '#{LOGIN}' already exists and was not created by this script. " \
        "Refusing to take it over - it would be made an admin, have its password " \
        "reset, and be deleted on teardown."
end

user = existing || User.new(login: LOGIN, firstname: 'Martin', lastname: 'Keller',
                            mail: 'martin.keller@example.com')
user.admin    = true
user.language = 'en'
user.password = password
user.password_confirmation = password
user.status = User::STATUS_ACTIVE
user.save!
say "capture user #{LOGIN} / #{password}"

# --- wipe a previous run ------------------------------------------------------

if previous
  Project.where(id: Array(JSON.parse(previous)['project_ids'])).destroy_all
  say 'removed the previous demo project'
end

# --- project ------------------------------------------------------------------

project = Project.create!(
  name: 'Field Service',
  identifier: IDENT,
  description: 'Repairs and on-site work. Demo project for the attachment preview.',
  is_public: false
)
project.enabled_module_names = %w[issue_tracking wiki documents files]
project.trackers = Tracker.all.to_a
project.save!

Member.create!(project: project, principal: user,
               roles: [Role.givable.first].compact) if Role.givable.any?
say "created project #{IDENT}"

# --- attachments --------------------------------------------------------------

# Attachment#file= writes the file into Attachment.storage_path, which is why
# this has to run with the files volume mounted.
def attach!(path, author, description)
  Attachment.new(author: author, description: description).tap do |a|
    a.file = File.open(path, 'rb')
    a.filename = File.basename(path)
    a.save!
  end
end

ASSET_DESCRIPTIONS = {
  '01-error-dialog.png'       => 'Error message on the till',
  '02-type-plate.jpg'         => 'Type plate of the affected terminal',
  '03-network-diagram.png'    => 'Branch connection, both lines',
  '04-inspection-report.pdf'  => 'Inspection report, signed'
}.freeze

tracker  = Tracker.first
status   = IssueStatus.where(is_closed: false).order(:position).first
priority = IssuePriority.default || IssuePriority.first

issue = Issue.new(project: project, tracker: tracker, author: user,
                  assigned_to: user, status: status, priority: priority,
                  subject: 'Till in branch 042 loses its connection every morning',
                  description: <<~TEXT)
    The till in branch 042 drops its connection to the warehouse server shortly
    after opening. Screenshot of the message, the type plate and the topology
    are attached, along with the inspection report from the last visit.
  TEXT
issue.save!

ASSET_DESCRIPTIONS.each do |filename, description|
  path = File.join(ASSETS, filename)
  next say("missing asset #{filename}") unless File.exist?(path)
  attachment = attach!(path, user, description)
  attachment.update_columns(container_type: 'Issue', container_id: issue.id)
end
say "created issue ##{issue.id} with #{issue.reload.attachments.count} attachments"

# A plain journal note, no attachment of its own: a fifth attachment would make
# the gallery read "1 / 5" and contradict the counter in the screenshots.
journal = issue.init_journal(user, 'Replacement power supply fitted — the message is unchanged.')
journal.save!

# --- wiki, documents, files ---------------------------------------------------

wiki = project.wiki || Wiki.create!(project: project, start_page: 'Wiki')
page = WikiPage.new(wiki: wiki, title: 'Branch 042')

# Image syntax follows the instance's own text formatting: Redmine 7 defaults to
# common_mark, where Textile's !name.png! is literal text and the image silently
# does not appear. Same distinction the helpdesk plugin's inline images handle.
image_markup =
  if Setting.text_formatting.to_s == 'textile'
    '!03-network-diagram.png!'
  else
    '![Branch topology](03-network-diagram.png)'
  end

page.build_content(text: <<~TEXT, author: user)
  # Branch 042

  Network layout of the branch, both the primary and the backup line:

  #{image_markup}

  The inspection report of the last visit is attached to the ticket.
TEXT
page.save!
wiki_image = attach!(File.join(ASSETS, '03-network-diagram.png'), user, 'Branch topology')
wiki_image.update_columns(container_type: 'WikiPage', container_id: page.id)
say 'created wiki page with an inline image'

document = Document.create!(project: project,
                            category: DocumentCategory.first || Enumeration.first,
                            title: 'Inspection reports 2026',
                            description: 'Signed reports from on-site visits.')
doc_file = attach!(File.join(ASSETS, '04-inspection-report.pdf'), user, 'Visit 04.09.2026')
doc_file.update_columns(container_type: 'Document', container_id: document.id)

project_file = attach!(File.join(ASSETS, '02-type-plate.jpg'), user, 'Terminal type plate')
project_file.update_columns(container_type: 'Project', container_id: project.id)
say 'created a document and a project file'

write_raw_setting!(BACKUP_KEY,
                   { 'project_ids' => [project.id],
                     'user_id'     => user.id,
                     'issue_id'    => issue.id,
                     'seeded_at'   => NOW.utc.iso8601 }.to_json)

say ''
say "done. Sign in as #{LOGIN} / #{password}"
say "  issue     /issues/#{issue.id}"
say "  wiki      /projects/#{IDENT}/wiki/Branch_042"
say "  files     /projects/#{IDENT}/files"
say "  documents /projects/#{IDENT}/documents"
