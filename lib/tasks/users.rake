# frozen_string_literal: true

namespace :users do
  desc "Promote a user to admin (prompts for email)"
  task make_admin: :environment do
    print "Email of user to promote to admin: "
    email = $stdin.gets&.strip
    abort "No email provided." if email.blank?

    user = User.find_by(email: email)
    abort "No user found for #{email.inspect}." unless user

    if user.admin?
      puts "#{user.email} is already an admin. Nothing to do."
      next
    end

    print "Promote #{user.email} (id=#{user.id}) to admin? [y/N]: "
    confirm = $stdin.gets&.strip&.downcase
    abort "Aborted." unless confirm == "y"

    user.update!(admin: true)
    puts "#{user.email} is now an admin."
  end

  desc "Revoke admin on a user (prompts for email)"
  task revoke_admin: :environment do
    print "Email of user to revoke admin from: "
    email = $stdin.gets&.strip
    abort "No email provided." if email.blank?

    user = User.find_by(email: email)
    abort "No user found for #{email.inspect}." unless user

    unless user.admin?
      puts "#{user.email} is not an admin. Nothing to do."
      next
    end

    print "Revoke admin from #{user.email} (id=#{user.id})? [y/N]: "
    confirm = $stdin.gets&.strip&.downcase
    abort "Aborted." unless confirm == "y"

    user.update!(admin: false)
    puts "#{user.email} is no longer an admin."
  end
end
