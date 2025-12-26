namespace :categories do
  desc "Backfill categories for uncategorized transactions. Options: LIMIT=100, FORCE=true, DRY_RUN=true"
  task backfill: :environment do
    limit = ENV.fetch("LIMIT", nil)&.to_i
    force = ActiveModel::Type::Boolean.new.cast(ENV["FORCE"])
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV["DRY_RUN"])

    scope = Transaction.all
    scope = scope.where(category_id: nil) unless force
    scope = scope.limit(limit) if limit&.positive?

    puts "Configuration: FORCE=#{force || 'false'}, DRY_RUN=#{dry_run || 'false'}, LIMIT=#{limit || 'none'}"
    puts "Processing #{scope.count} transactions..."

    stats = {
      total: 0,
      updated: 0,
      low_confidence: 0,
      no_suggestion: 0,
      errors: 0
    }

    suggester_cache = {}

    # find_each ignores limit, so we use each if a limit is present
    iterator = limit&.positive? ? scope.to_a : scope.find_each

    iterator.each do |transaction|
      stats[:total] += 1
      begin
        user = transaction.account&.user
        unless user
          puts "[TRX #{transaction.id}] Error: No user/account associated"
          stats[:errors] += 1
          next
        end

        suggester = suggester_cache[user.id] ||= CategorySuggester.new(user: user)
        categories_count = Category.for_user(user).count
        lookups_count = CategoryLookup.for_user(user).count

        print "[TRX #{transaction.id}] '#{transaction.description.truncate(30)}' (Cats: #{categories_count}, Lookups: #{lookups_count}) -> "
        
        suggestion = suggester.suggest(transaction.description)
        
        if suggestion&.category
          confidence_pct = (suggestion.confidence * 100).round
          if dry_run
            puts "WOULD UPDATE to #{suggestion.category.name} (#{confidence_pct}% confidence, source: #{suggestion.source})"
            stats[:updated] += 1
          elsif suggestion.confidence >= 0.5
            transaction.update_columns(category_id: suggestion.category.id, updated_at: Time.current)
            puts "UPDATED to #{suggestion.category.name} (#{confidence_pct}% confidence, source: #{suggestion.source})"
            stats[:updated] += 1

            # If it was an AI suggestion, cache it in CategoryLookup to reduce future AI calls
            if suggestion.source == :ai
              CategoryLookup.upsert_for(
                user: user,
                category: suggestion.category,
                description: transaction.description
              )
            end
          else
            puts "SKIPPED: Low confidence (#{confidence_pct}%, source: #{suggestion.source})"
            stats[:low_confidence] += 1
          end
        else
          puts "SKIPPED: No suggestion found"
          stats[:no_suggestion] += 1
        end
      rescue => e
        puts "ERROR: #{e.message}"
        stats[:errors] += 1
      end
    end

    puts "\nBackfill Complete!"
    puts "------------------"
    puts "Total Processed: #{stats[:total]}"
    puts "Updated:         #{stats[:updated]}"
    puts "Low Confidence:  #{stats[:low_confidence]}"
    puts "No Suggestion:   #{stats[:no_suggestion]}"
    puts "Errors:          #{stats[:errors]}"
  end

  desc "Build category_lookups cache from existing categorized transactions. Options: LIMIT=1000"
  task backfill_lookups: :environment do
    limit = ENV.fetch("LIMIT", nil)&.to_i
    scope = Transaction.includes(:account, :category).where.not(category_id: nil)
    scope = scope.limit(limit) if limit&.positive?

    puts "Caching #{scope.count} categorized transactions into category_lookups..."

    scope.find_each do |transaction|
      next unless transaction.account&.user && transaction.category

      CategoryLookup.upsert_for(
        user: transaction.account.user,
        category: transaction.category,
        description: transaction.description
      )
    end

    puts "Done."
  end

  desc "Seed default global categories"
  task seed_defaults: :environment do
    defaults = [
      "Groceries", "Dining", "Utilities", "Housing",
      "Auto", "Transportation", "Fuel", "Health", "Insurance",
      "Entertainment", "Travel", "Transfer", "Income", "Savings",
      "Investments", "Subscriptions", "Education", "Gifts", "Miscellaneous",
      "Family", "Taxes", "Credit Card Payment", "Investments"
    ]

    puts "Seeding #{defaults.size} default global categories..."

    defaults.each do |name|
      category = Category.find_or_create_by!(name: name, kind: :global)
      if category.previously_new_record?
        puts "Created: #{name}"
      else
        puts "Exists:  #{name}"
      end
    end

    puts "Done."
  end

  desc "Assign Transfer category to all transfer transactions missing a category"
  task backfill_transfers: :environment do
    transfer_category = Category.transfer_category
    updated = Transaction.where(transfer: true, category_id: nil)
                         .update_all(category_id: transfer_category.id)
    puts "Updated #{updated} transfer transactions"
  end
end

