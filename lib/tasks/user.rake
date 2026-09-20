# Svapna has no public signup: accounts are created here or in the console.
#
#   bin/d r user:create EMAIL=me@example.com PASSWORD=...
#   bin/d r user:list
namespace :user do
  desc "Create a user (EMAIL and PASSWORD required)"
  task create: :environment do
    email = ENV["EMAIL"].presence
    password = ENV["PASSWORD"].presence

    abort "EMAIL is required, e.g. bin/d r user:create EMAIL=me@example.com PASSWORD=secret" if email.nil?
    abort "PASSWORD is required" if password.nil?

    user = User.find_or_initialize_by(email_address: email)
    existed = user.persisted?
    user.password = password
    user.save!

    puts existed ? "Updated password for #{user.email_address}" : "Created #{user.email_address}"
  end

  desc "List users"
  task list: :environment do
    if User.none?
      puts "No users yet. Create one with: bin/d r user:create EMAIL=... PASSWORD=..."
    else
      User.order(:email_address).each { |u| puts "#{u.email_address} (#{u.sessions.count} active sessions)" }
    end
  end
end
