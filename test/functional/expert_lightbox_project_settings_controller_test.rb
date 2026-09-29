require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ExpertLightboxProjectSettingsControllerTest < Redmine::ControllerTest
  tests ExpertLightboxProjectSettingsController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :enabled_modules

  def setup
    User.current = nil
  end

  def test_manager_saves_override
    @request.session[:user_id] = 2 # Manager in project 1
    patch :update, :params => {
      :project_id => 'ecookbook',
      :expert_lightbox_project_setting => { :override => '1', :inline_max_width => '',
                                            :inline_max_height => '500' }
    }
    assert_redirected_to '/projects/ecookbook/settings/expert_lightbox'
    setting = ExpertLightboxProjectSetting.find_by(:project_id => 1)
    assert setting.override?
    assert_nil setting.inline_max_width
    assert_equal 500, setting.inline_max_height
  end

  def test_invalid_value_is_not_saved
    @request.session[:user_id] = 2
    patch :update, :params => {
      :project_id => 'ecookbook',
      :expert_lightbox_project_setting => { :override => '1', :inline_max_height => '-5' }
    }
    assert_redirected_to '/projects/ecookbook/settings/expert_lightbox'
    assert flash[:error].present?
    assert_nil ExpertLightboxProjectSetting.find_by(:project_id => 1)
  end

  def test_user_without_edit_project_is_denied
    @request.session[:user_id] = 7 # no membership in project 1
    patch :update, :params => {
      :project_id => 'ecookbook',
      :expert_lightbox_project_setting => { :override => '1', :inline_max_height => '500' }
    }
    assert_response 403
    assert_nil ExpertLightboxProjectSetting.find_by(:project_id => 1)
  end

  def test_anonymous_is_sent_to_login
    patch :update, :params => {
      :project_id => 'ecookbook',
      :expert_lightbox_project_setting => { :override => '1', :inline_max_height => '500' }
    }
    assert_response 302
    assert_match %r{/login}, response.location
  end
end
