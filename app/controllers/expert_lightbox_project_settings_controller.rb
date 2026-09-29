# Saves the per-project inline image size override from the project settings tab.
class ExpertLightboxProjectSettingsController < ApplicationController
  before_action :find_project_by_project_id
  # Checked by hand: core's edit_project permission does not list this controller,
  # so the usual `authorize` would always refuse.
  before_action :authorize_edit_project

  def update
    setting = ExpertLightboxProjectSetting.find_or_initialize_by(:project_id => @project.id)
    attrs = params[:expert_lightbox_project_setting] || {}
    setting.override = attrs[:override] == '1'
    setting.inline_max_width = attrs[:inline_max_width]
    setting.inline_max_height = attrs[:inline_max_height]

    if setting.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = setting.errors.full_messages.join(', ')
    end
    redirect_to settings_project_path(@project, :tab => 'expert_lightbox')
  end

  private

  def authorize_edit_project
    deny_access unless User.current.allowed_to?(:edit_project, @project)
  end
end
