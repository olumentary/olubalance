require 'rails_helper'

describe UserDecorator do
  let(:user) { FactoryBot.build_stubbed(:user, first_name: 'Full', last_name: 'Name').decorate }

  # Anchor dates inside one Sun–Sat window for predictable assertions.
  let(:sunday) { Date.new(2026, 5, 17) }
  let(:wednesday) { Date.new(2026, 5, 20) }
  let(:friday) { Date.new(2026, 5, 22) }
  let(:saturday) { Date.new(2026, 5, 23) }

  it 'returns the user full name' do
    expect(user.full_name).to eq('Full Name')
  end

  it 'returns the member since formatted date' do
    expect(user.member_since).to eq(user.created_at.in_time_zone(user.timezone).strftime('%b %d, %Y'))
  end

  describe '#streak_display' do
    it 'pluralizes weeks' do
      u1 = FactoryBot.build_stubbed(:user, current_streak_weeks: 1).decorate
      expect(u1.streak_display).to eq('1 week')
      u2 = FactoryBot.build_stubbed(:user, current_streak_weeks: 7).decorate
      expect(u2.streak_display).to eq('7 weeks')
    end
  end

  describe '#streak_subtitle' do
    it 'nudges users with no streak history' do
      u = FactoryBot.build_stubbed(:user, current_streak_weeks: 0, longest_streak_weeks: 0).decorate
      expect(u.streak_subtitle).to match(/Start a streak/)
    end

    it 'shows recovery prompt when current is 0 but longest > 0' do
      u = FactoryBot.build_stubbed(:user, current_streak_weeks: 0, longest_streak_weeks: 5).decorate
      expect(u.streak_subtitle).to eq('Restart this week — your best was 5 weeks')
    end

    it 'celebrates an active streak with the personal best' do
      u = FactoryBot.build_stubbed(:user, current_streak_weeks: 3, longest_streak_weeks: 10).decorate
      expect(u.streak_subtitle).to eq('Best: 10 weeks')
    end
  end

  describe '#streak_color_class' do
    it 'returns has-text-black for zero streak (readable on colored banner backgrounds)' do
      u = FactoryBot.build_stubbed(:user, current_streak_weeks: 0).decorate
      expect(u.streak_color_class).to eq('has-text-black')
    end

    it 'returns has-text-warning-dark for a short streak' do
      u = FactoryBot.build_stubbed(:user, current_streak_weeks: 2).decorate
      expect(u.streak_color_class).to eq('has-text-warning-dark')
    end

    it 'returns has-text-success for a sustained streak' do
      u = FactoryBot.build_stubbed(:user, current_streak_weeks: 6).decorate
      expect(u.streak_color_class).to eq('has-text-success')
    end
  end

  describe '#week_range_display' do
    it 'spans Sun to Sat of the containing week' do
      u = FactoryBot.build_stubbed(:user).decorate
      expect(u.week_range_display(today: wednesday)).to eq('May 17 – May 23')
    end
  end

  describe 'weekly counts and progress (with real records)' do
    let(:real_user) { FactoryBot.create(:user) }

    before do
      @reviewed = FactoryBot.create(:account, user: real_user)
      @pending = FactoryBot.create(:account, user: real_user)
      @reviewed.update_columns(last_transaction_on: wednesday)
      @pending.update_columns(last_transaction_on: 30.days.ago.to_date)
    end

    it 'counts reviewed vs needing review' do
      decorated = real_user.decorate
      expect(decorated.accounts_reviewed_this_week_count(today: wednesday)).to eq(1)
      expect(decorated.accounts_needing_review_count(today: wednesday)).to eq(1)
    end

    it 'detects week_complete? only when all reviewed' do
      decorated = real_user.decorate
      expect(decorated.week_complete?(today: wednesday)).to be false
      @pending.update_columns(last_transaction_on: wednesday)
      expect(real_user.decorate.week_complete?(today: wednesday)).to be true
    end

    it 'paints the banner color: info Sun–Thu, warning Fri, danger Sat — success when complete' do
      decorated = real_user.decorate
      expect(decorated.weekly_banner_color_class(today: wednesday)).to eq('is-info')
      expect(decorated.weekly_banner_color_class(today: friday)).to eq('is-warning')
      expect(decorated.weekly_banner_color_class(today: saturday)).to eq('is-danger')
      @pending.update_columns(last_transaction_on: saturday)
      expect(real_user.decorate.weekly_banner_color_class(today: saturday)).to eq('is-success')
    end

    it 'escalates progress copy as the week ends' do
      decorated = real_user.decorate
      expect(decorated.weekly_progress_message(today: wednesday)).to match(/1 account left/)
      expect(decorated.weekly_progress_message(today: friday)).to start_with('Friday')
      expect(decorated.weekly_progress_message(today: saturday)).to start_with('Saturday')
      @pending.update_columns(last_transaction_on: saturday)
      expect(real_user.decorate.weekly_progress_message(today: saturday)).to match(/All accounts reviewed/)
    end
  end
end
