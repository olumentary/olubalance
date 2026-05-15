require "rails_helper"

# Routes for self-registration are skipped (`devise_for :users, skip: [:registrations]`
# in config/routes.rb), so the custom RegistrationsController#create is not
# reachable. The only registration-style endpoints exposed are profile edit and
# update, which point at `devise/registrations`. This spec covers those.
RSpec.describe "User profile", type: :request do
  let(:user) { create(:user) }

  describe "GET /users/edit" do
    it "redirects to login when not signed in" do
      get edit_user_registration_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders the edit form for the signed-in user" do
      sign_in user
      get edit_user_registration_path
      expect(response).to be_successful
    end
  end

  describe "PATCH /users/:id" do
    before { sign_in user }

    it "updates first_name when current_password is supplied" do
      patch user_registration_path(user), params: {
        user: {
          first_name: "Updated",
          current_password: "topsecret"
        }
      }
      expect(user.reload.first_name).to eq("Updated")
    end

    it "refuses to update without current_password" do
      original = user.first_name
      patch user_registration_path(user), params: {
        user: { first_name: "Hacked" }
      }
      expect(user.reload.first_name).to eq(original)
    end
  end
end
