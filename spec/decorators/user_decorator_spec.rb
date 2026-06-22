require 'rails_helper'

describe UserDecorator do
  let(:user) { FactoryBot.build_stubbed(:user, first_name: 'Full', last_name: 'Name').decorate }

  it 'returns the user full name' do
    expect(user.full_name).to eq('Full Name')
  end

  it 'returns the member since formatted date' do
    expect(user.member_since).to eq(user.created_at.in_time_zone(user.timezone).strftime('%b %d, %Y'))
  end
end
