# Inline delivery endpoint for the lightbox. Core's /attachments/download forces
# Content-Disposition: attachment for non-images, which prevents PDFs from being
# rendered in an <iframe>. The optional :filename segment is cosmetic only (it makes
# the browser's PDF viewer show a sensible title) - the :id decides what is served.
get 'expert_lightbox/inline/:id(/*filename)', :to => 'expert_lightbox#inline',
    :as => 'expert_lightbox_inline', :format => false, :id => /\d+/
