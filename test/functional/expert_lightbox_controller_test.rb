require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class ExpertLightboxControllerTest < Redmine::ControllerTest
  tests ExpertLightboxController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :enabled_modules, :issues, :trackers, :attachments

  def setup
    User.current = nil
    # `inline` refuses to serve an attachment whose file is not on disk
    # (Attachment#readable?). Redmine's fixtures only describe the rows; the
    # matching files live under test/fixtures/files, and the storage path has to
    # be pointed at them or every fixture attachment 404s.
    set_fixtures_attachments_directory
  end

  def teardown
    set_tmp_attachments_directory
  end

  def test_inline_image_is_served_inline
    @request.session[:user_id] = 2
    get :inline, :params => { :id => 16, :filename => 'testfile.png' }

    assert_response :success
    assert_equal 'image/png', response.media_type
    assert_include 'inline', response.headers['Content-Disposition']
    assert_equal 'nosniff', response.headers['X-Content-Type-Options']
  end

  def test_inline_rejects_non_previewable_attachment
    @request.session[:user_id] = 2
    # attachment 4 is source.rb - not an image and not a PDF
    get :inline, :params => { :id => 4, :filename => 'source.rb' }

    assert_response :not_found
  end

  def test_inline_denies_access_to_invisible_attachment
    # attachment 7 belongs to the private project "OnlineStore"
    get :inline, :params => { :id => 7 }

    assert_response :found
    assert_redirected_to %r{/login}
  end

  def test_inline_returns_404_for_unknown_attachment
    @request.session[:user_id] = 2
    get :inline, :params => { :id => 999999 }

    assert_response :not_found
  end
end
