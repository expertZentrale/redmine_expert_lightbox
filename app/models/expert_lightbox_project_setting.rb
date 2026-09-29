# Per-project override of the inline image size limit, plus the resolver the
# layout hook uses to decide which limit applies on the current page.
#
# Redmine 6+ defines ApplicationRecord and hangs its field_* attribute-name lookup
# (used in validation messages) there; Redmine 5.x has neither and patches
# ActiveRecord::Base. Pick whichever base the running version provides.
class ExpertLightboxProjectSetting < (defined?(ApplicationRecord) ? ApplicationRecord : ActiveRecord::Base)
  belongs_to :project

  validates :project_id, :presence => true, :uniqueness => true
  validates :inline_max_width, :inline_max_height,
            :numericality => { :only_integer => true, :greater_than => 0 },
            :allow_nil => true

  # Blank form fields mean "no limit", stored as NULL rather than 0.
  def inline_max_width=(value)
    super(value.to_s.strip.presence)
  end

  def inline_max_height=(value)
    super(value.to_s.strip.presence)
  end

  # Returns {:width => Integer|nil, :height => Integer|nil}; nil means no limit.
  # A project with an active override uses its own values, everything else (no
  # project, no row, override off) falls back to the global plugin setting.
  def self.limits_for(project)
    row = project && where(:project_id => project.id, :override => true).first
    return { :width => row.inline_max_width, :height => row.inline_max_height } if row

    global_limits
  rescue ActiveRecord::StatementInvalid
    # Plugin deployed but not migrated yet: this runs in the layout of every page,
    # so a missing table must not take the whole application down.
    global_limits
  end

  # Plugin settings come straight from a form, and the keys are nil on installs
  # that predate them until the settings page is saved once - so every value is
  # parsed defensively and anything that is not a positive integer means no limit.
  def self.global_limits
    settings = Setting.plugin_redmine_expert_lightbox
    settings = {} unless settings.is_a?(Hash)
    { :width => positive_int(settings['inline_max_width']),
      :height => positive_int(settings['inline_max_height']) }
  end

  def self.positive_int(value)
    value = value.to_s.strip
    return nil unless value.match?(/\A\d+\z/)

    value.to_i.positive? ? value.to_i : nil
  end
end
