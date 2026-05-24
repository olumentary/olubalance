RailsAdmin.config do |config|
  config.asset_source = :sprockets

  # Devise + admin gate. The `authenticate :user, ->(u) { u.admin? }` route
  # constraint is the primary gate; these blocks defend in depth so RailsAdmin
  # itself refuses non-admins if the engine is ever mounted outside that scope.
  config.authenticate_with do
    warden.authenticate!(scope: :user)
    redirect_to main_app.root_path unless current_user&.admin?
  end
  config.current_user_method(&:current_user)
  config.authorize_with do
    redirect_to main_app.root_path unless current_user&.admin?
  end

  # Devise 5's `validatable` sets `password` length min/max to Procs, which
  # RailsAdmin's String#generic_help can't compare with `.min`. Override the
  # help text on the virtual password fields so editing a user doesn't 500.
  config.model "User" do
    configure :password do
      help "Leave blank to keep the current password."
    end
    configure :password_confirmation do
      help ""
    end
  end

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete
    show_in_app

    ## With an audit adapter, you can add:
    # history_index
    # history_show
  end
end
