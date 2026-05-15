class SummaryController < ApplicationController
  before_action :authenticate_user!
  before_action :collect_summary_info
  skip_forgery_protection

  def index
  end

  def send_mail
    SummaryMailer.with(summary: @summary, current_user: current_user, to: params[:summary_mail][:to]).new_summary_email.deliver_now
  end

  private

  # Get the summary object (defined in facade)
  def collect_summary_info
    accounts = current_user.accounts.where(active: true).order("created_at ASC").decorate
    @summary = Summary.new(accounts)
  end

  def summary_params
    params.require(:summary_mail) \
          .permit(:to)
  end
end
