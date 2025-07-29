require 'pagy/extras/bulma'

Pagy::DEFAULT[:items] = 15
Pagy::DEFAULT[:link_extra] = 'data-turbo-frame="_self"'
Pagy::DEFAULT[:page_param] = 'page'