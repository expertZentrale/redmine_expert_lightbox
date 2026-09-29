require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# The size limit is emitted by the layout hook; tested through a real issue page
# so the :project the hook receives comes from Redmine, not from the test.
class ExpertLightboxInlineSizeHookTest < Redmine::ControllerTest
  tests IssuesController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :enabled_modules, :issues, :trackers, :issue_statuses, :enumerations,
           :projects_trackers, :workflows

  def setup
    User.current = nil
    @request.session[:user_id] = 2
  end

  def test_style_emitted_with_global_limits
    with_settings :plugin_redmine_expert_lightbox => { 'inline_max_width' => '800', 'inline_max_height' => '400' } do
      get :show, :params => { :id => 1 }
    end
    assert_response :success
    assert_select 'style#expert-lightbox-inline-size', :text => /max-width:min\(100%,800px\);max-height:400px/
    # Anchored to the app's own path, so external URLs containing /attachments/ are left alone.
    assert_select 'style#expert-lightbox-inline-size', :text => %r{img\[src\^="/attachments/"\]}
  end

  def test_project_override_replaces_global_limits
    ExpertLightboxProjectSetting.create!(:project_id => 1, :override => true, :inline_max_height => '600')
    with_settings :plugin_redmine_expert_lightbox => { 'inline_max_width' => '800', 'inline_max_height' => '400' } do
      get :show, :params => { :id => 1 }
    end
    assert_select 'style#expert-lightbox-inline-size' do |nodes|
      css = nodes.first.text
      assert_includes css, 'max-height:600px'
      assert_not_includes css, 'max-width'
    end
  end

  def test_no_style_without_limits
    with_settings :plugin_redmine_expert_lightbox => { 'inline_max_width' => '', 'inline_max_height' => '' } do
      get :show, :params => { :id => 1 }
    end
    assert_response :success
    assert_select 'style#expert-lightbox-inline-size', 0
  end
end
