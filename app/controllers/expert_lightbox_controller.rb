# Serves previewable attachments with Content-Disposition: inline so the browser can
# render them inside the lightbox dialog (PDFs in an <iframe>, images in an <img>).
#
# This is deliberately a plugin-owned controller instead of a patch on Redmine's
# AttachmentsController: other plugins in this deployment (redmine_contacts) already
# patch that controller, and core rewrote it several times between 5.1 and 7.x.
class ExpertLightboxController < ApplicationController
  before_action :find_attachment

  # Only these extensions may ever be served inline. Serving arbitrary uploads inline
  # would turn this action into a stored-XSS gadget (think .html or .svg uploaded as an
  # attachment and then executed on the Redmine origin). SVG is intentionally NOT in
  # this list - the JS renders SVG through an <img> tag, which does not run scripts,
  # and <img> is served by core's own download route.
  INLINE_TYPES = {
    'png'  => 'image/png',
    'gif'  => 'image/gif',
    'jpg'  => 'image/jpeg',
    'jpeg' => 'image/jpeg',
    'bmp'  => 'image/bmp',
    'webp' => 'image/webp',
    'avif' => 'image/avif',
    'pdf'  => 'application/pdf'
  }.freeze

  def inline
    content_type = INLINE_TYPES[@attachment.filename.to_s.split('.').last.to_s.downcase]
    return render_404 if content_type.nil?
    return render_404 unless @attachment.readable?

    response.headers['X-Content-Type-Options'] = 'nosniff'
    send_file @attachment.diskfile,
              :filename => filename_for_content_disposition(@attachment.filename),
              :type => content_type,
              :disposition => 'inline'
  end

  private

  # Attachment#visible? performs the full container/project/permission check and exists
  # unchanged from Redmine 5.1 through 7.x.
  def find_attachment
    @attachment = Attachment.find(params[:id])
    raise ::Unauthorized unless @attachment.visible?
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
