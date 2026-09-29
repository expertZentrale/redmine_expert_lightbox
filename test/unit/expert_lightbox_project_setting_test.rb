require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ExpertLightboxProjectSettingTest < ActiveSupport::TestCase
  fixtures :projects

  def plugin_settings(width, height)
    { :plugin_redmine_expert_lightbox => { 'inline_max_width' => width, 'inline_max_height' => height } }
  end

  def test_global_setting_applies_without_project
    with_settings plugin_settings('800', '400') do
      assert_equal({ :width => 800, :height => 400 }, ExpertLightboxProjectSetting.limits_for(nil))
    end
  end

  def test_global_setting_applies_to_project_without_row
    with_settings plugin_settings('', '400') do
      assert_equal({ :width => nil, :height => 400 }, ExpertLightboxProjectSetting.limits_for(Project.find(1)))
    end
  end

  # Installs that predate the setting read nil (or a hash without the keys).
  def test_missing_global_keys_mean_no_limit
    with_settings :plugin_redmine_expert_lightbox => {} do
      assert_equal({ :width => nil, :height => nil }, ExpertLightboxProjectSetting.limits_for(Project.find(1)))
    end
  end

  def test_garbage_global_values_mean_no_limit
    with_settings plugin_settings('abc', '0') do
      assert_equal({ :width => nil, :height => nil }, ExpertLightboxProjectSetting.global_limits)
    end
  end

  def test_oversized_global_values_are_capped
    with_settings plugin_settings('99999999999', '20000') do
      assert_equal({ :width => 10_000, :height => 10_000 }, ExpertLightboxProjectSetting.global_limits)
    end
  end

  def test_active_override_wins
    ExpertLightboxProjectSetting.create!(:project_id => 1, :override => true,
                                         :inline_max_width => '', :inline_max_height => '600')
    with_settings plugin_settings('800', '400') do
      assert_equal({ :width => nil, :height => 600 }, ExpertLightboxProjectSetting.limits_for(Project.find(1)))
      # Other projects keep following the global setting.
      assert_equal({ :width => 800, :height => 400 }, ExpertLightboxProjectSetting.limits_for(Project.find(2)))
    end
  end

  def test_inactive_override_is_ignored
    ExpertLightboxProjectSetting.create!(:project_id => 1, :override => false, :inline_max_height => '600')
    with_settings plugin_settings('', '400') do
      assert_equal({ :width => nil, :height => 400 }, ExpertLightboxProjectSetting.limits_for(Project.find(1)))
    end
  end

  def test_rejects_non_positive_and_non_numeric_values
    ['0', '-5', 'abc', '1.5', '10001', '99999999999'].each do |value|
      setting = ExpertLightboxProjectSetting.new(:project_id => 1, :inline_max_height => value)
      assert_not setting.valid?, "#{value.inspect} should be invalid"
    end
    assert ExpertLightboxProjectSetting.new(:project_id => 1, :inline_max_height => ' ').valid?
  end
end
