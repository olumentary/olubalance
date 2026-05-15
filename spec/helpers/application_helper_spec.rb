# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#class_string" do
    it "joins enabled keys with a space" do
      result = helper.class_string("a" => true, "b" => false, "c" => true)
      expect(result).to eq("a c")
    end

    it "returns an empty string when nothing is enabled" do
      expect(helper.class_string("a" => false, "b" => false)).to eq("")
    end
  end

  describe "Devise helpers" do
    it "returns :user as the resource name" do
      expect(helper.resource_name).to eq(:user)
    end

    it "returns a new User as the resource" do
      expect(helper.resource).to be_a(User)
      expect(helper.resource).to be_new_record
    end

    it "returns the user Devise mapping" do
      expect(helper.devise_mapping).to eq(Devise.mappings[:user])
    end
  end
end
