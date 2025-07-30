# Objects
users = []
accounts = []
transactions = []
stashes = []

# Seed Lists
trx_type = %w[debit credit]
emails = %w[
  john@gmail.com 
  john2@gmail.com 
  john3@gmail.com
]
checking_account_names = %w[
  Chase 
  PNC 
  Wells\ Fargo 
  BB&T 
  TD\ Bank 
  Capital\ One 
  Bank\ of\ America
  Ally
]
credit_account_names = %w[
  Chase\ Freedom
  Chase\ Slate
  American\ Express
  Apple\ Card
  Citi\ Double\ Cash
]
savings_account_names = %w[
  Capital\ One\ 360
  Vio
  Synchrony
  Marcus
  Barclays
  Chime
]
cash_account_names = %w[
  Piggy\ Bank
  Under\ Mattress
  Secret\ Stash
  Home\ Safe
  Wallet
]
trx_debit_desc = %w[
  Electric\ Payment
  Gas\ Payment
  Rent
  Mortgage
  Shell
  BP
  Kroger
  Transfer\ to\ Savings
  Gym\ Membership
  Mobile\ Phone\ Payment
  McDonalds
  Subway
  Oil\ Change
  Internet\ Payment
  Car\ Payment
  Food\ Lion
  Movie\ Theater
  Starbucks
  Sunoco
]
trx_credit_desc = %w[
  Paycheck
  Refund
  Transfer\ from\ Savings
]
stash_names = %w[
  Bills
  Computer
  New\ Bike
  Guitar
  Jewelery
  House\ Down\ Payment
  Vacation
]

# Create 3 test accounts
emails.each do |email|
  user = User.new(
    email: email,
    password: 'topsecret',
    password_confirmation: 'topsecret',
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    timezone: 'Eastern Time (US & Canada)',
    confirmed_at: DateTime.now
  )
  user.skip_confirmation!
  user.save!
  users << user
end

# Create 5 accounts for each user
users.each do |user|
  selected_accounts = []
    
  # Checking
  3.times do

    # Ensure that an account name isn't repeated (unique constraint per user)
    account_name = (checking_account_names - selected_accounts).sample
    selected_accounts << account_name

    account = Account.create!(
      name: account_name,
      last_four: Faker::Number.number(digits: 4).to_i,
      starting_balance: Faker::Number.between(from: 1500.00, to: 5000.00).to_f.round(2),
      account_type: 'checking',
      user: user
    )

    accounts << account

    # Set the starting balance transaction date to be the first transaction
    t = account.transactions.first
    t.trx_date = 91.days.ago.to_s
    t.save(validate: false)
  end

  # Credit
  5.times do

    # Ensure that an account name isn't repeated (unique constraint per user)
    account_name = (credit_account_names - selected_accounts).sample
    selected_accounts << account_name

    account = Account.create!(
      name: account_name,
      last_four: Faker::Number.number(digits: 4).to_i,
      starting_balance: 0,
      credit_limit: Faker::Number.between(from: 5000.00, to: 20000.00).to_f.round(2),
      interest_rate: Faker::Number.between(from: 10.00, to: 25.00).to_f.round(2),
      account_type: 'credit',
      user: user
    )

    accounts << account

    # Set the starting balance transaction date to be the first transaction
    t = account.transactions.first
    t.trx_date = 91.days.ago.to_s
    t.save(validate: false)
  end

  # Savings
  1.times do

    # Ensure that an account name isn't repeated (unique constraint per user)
    account_name = (savings_account_names - selected_accounts).sample
    selected_accounts << account_name

    account = Account.create!(
      name: account_name,
      last_four: Faker::Number.number(digits: 4).to_i,
      starting_balance: Faker::Number.between(from: 10000.00, to: 50000.00).to_f.round(2),
      interest_rate: Faker::Number.between(from: 0.30, to: 1.00).to_f.round(2),
      account_type: 'savings',
      user: user
    )

    accounts << account

    # Set the starting balance transaction date to be the first transaction
    t = account.transactions.first
    t.trx_date = 91.days.ago.to_s
    t.save(validate: false)
  end

  # Cash
  1.times do

    # Ensure that an account name isn't repeated (unique constraint per user)
    account_name = (cash_account_names - selected_accounts).sample
    selected_accounts << account_name

    account = Account.create!(
      name: account_name,
      last_four: Faker::Number.number(digits: 4).to_i,
      starting_balance: Faker::Number.between(from: 500.00, to: 15000.00).to_f.round(2),
      account_type: 'cash',
      user: user
    )

    accounts << account

    # Set the starting balance transaction date to be the first transaction
    t = account.transactions.first
    t.trx_date = 91.days.ago.to_s
    t.save(validate: false)
  end
end

# Create Transactions
accounts.each do |account|
  # Create 100 debit transactions for each Account
  100.times do
    Transaction.create!(
      trx_date: Faker::Date.backward(days: 90),
      description: trx_debit_desc.sample,
      amount: Faker::Number.between(from: 1.00, to: 50.00).to_f.round(2),
      trx_type: 'debit',
      skip_pending_default: true,
      account: account
    )
  end

  # Create 10 credit transactions for each Account
  10.times do
    Transaction.create!(
      trx_date: Faker::Date.backward(days: 90),
      description: trx_credit_desc.sample,
      amount: Faker::Number.between(from: 1.00, to: 5.00).to_f.round(2),
      trx_type: 'credit',
      skip_pending_default: true,
      account: account
    )
  end

  # Create 10 transactions with multiple attachments for the first account only (for migration testing)
  if account == accounts.first
    10.times do |i|
      t = Transaction.create!(
            trx_date: Faker::Date.backward(days: 1),
            description: "Migration Test Transaction #{i + 1}",
            amount: Faker::Number.between(from: 1.00, to: 50.00).to_f.round(2),
            trx_type: 'debit',
            skip_pending_default: true,
            account: account
          )
      
      # Attach multiple files to demonstrate multiple attachments support
      # Primary receipt image
      t.attachments.attach(
        io: File.open('app/assets/images/logo.png'), 
        filename: "receipt-#{i + 1}.png", 
        content_type: 'image/png'
      )
      
      # Additional supporting documents (simulate multiple attachments)
      if i % 3 == 0  # Every 3rd transaction gets 2 additional attachments
        t.attachments.attach(
          io: File.open('app/assets/images/logo.png'), 
          filename: "supporting-doc-#{i + 1}-1.png", 
          content_type: 'image/png'
        )
        t.attachments.attach(
          io: File.open('app/assets/images/logo.png'), 
          filename: "supporting-doc-#{i + 1}-2.png", 
          content_type: 'image/png'
        )
      elsif i % 2 == 0  # Every 2nd transaction gets 1 additional attachment
        t.attachments.attach(
          io: File.open('app/assets/images/logo.png'), 
          filename: "supporting-doc-#{i + 1}.png", 
          content_type: 'image/png'
        )
      end
    end
  end

  # Create 2 pending transactions
  2.times do
    Transaction.create!(
      trx_date: Faker::Date.backward(days: 15),
      description: 'Pending Test Transaction',
      amount: Faker::Number.between(from: 1.00, to: 50.00).to_f.round(2),
      trx_type: 'debit',
      pending: true,
      account: account
    )
  end

  # Create 2 stashes
  selected_stashes = []
  2.times do
    # Ensure that an stash name isn't repeated for the account
    stash_name = (stash_names - selected_stashes).sample
    selected_stashes << stash_name

    stashes << Stash.create!(
      name: stash_name,
      description: 'This is an example stash.',
      goal: Faker::Number.between(from: 500.00, to: 10000.00).to_f.round(2),
      account: account
    )
  end
end

# Add stash entries
stashes.each do |stash|
  StashEntry.create!(
    stash_entry_date: Faker::Date.backward(days: 1),
    amount: 150.00,
    stash_action: 'add',
    stash: stash
  )

  StashEntry.create!(
    stash_entry_date: Faker::Date.backward(days: 1),
    amount: 50.00,
    stash_action: 'remove',
    stash: stash
  )
end

# Account.create!(
#   name: Faker::Bank.unique.name.titlecase,
#   last_four: Faker::Number.number(digits: 4).to_i,
#   starting_balance: 3000.00,
#   user_id: 1
# )

# 5.times do
#   t = Transaction.create!(
#         trx_date: Faker::Date.between(from: 10.days.from_now, to: 15.days.from_now),
#         description: Faker::Name.name,
#         amount: Faker::Number.between(from: 0.01, to: 150.00).to_f.round(2),
#         trx_type: trx_type.sample,
#         account_id: 1
#       )
#   t.attachments.attach(io: File.open('app/assets/images/logo.png'), filename: 'logo.png')
# end

# 1000.times do
#   Transaction.create!(
#     trx_date: Faker::Date.forward(days: 10),
#     description: Faker::Name.name,
#     amount: Faker::Number.between(from: 0.01, to: 150.00).to_f.round(2),
#     trx_type: trx_type.sample,
#     account_id: 1
#   )
# end

# 5.times do
#   v = Transaction.create!(
#         trx_date: Faker::Date.between(from: 10.days.from_now, to: 15.days.from_now),
#         description: Faker::Name.name,
#         amount: Faker::Number.between(from: 0.01, to: 150.00).to_f.round(2),
#         trx_type: trx_type.sample,
#         account_id: 1
#       )
#   v.attachments.attach(io: File.open('app/assets/images/logo.png'), filename: 'logo.png')
# end

# 20.times do
#   accounts << Account.create!(
#     name: Faker::Bank.unique.name.titlecase,
#     last_four: Faker::Number.number(digits: 4).to_i,
#     starting_balance: Faker::Number.between(from: 1500.00, to: 9000.00).to_f.round(2),
#     user: users.sample
#   )
# end

# 2000.times do
#   transactions << Transaction.create!(
#     trx_date: Faker::Date.forward(days: 30),
#     description: Faker::Name.name,
#     amount: Faker::Number.between(from: 0.01, to: 250.00).to_f.round(2),
#     trx_type: trx_type.sample,
#     account: accounts.sample
#   )
# end