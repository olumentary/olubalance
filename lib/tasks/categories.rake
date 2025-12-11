namespace :categories do
  desc "Backfill categories for uncategorized transactions. Options: LIMIT=100, FORCE=true, DRY_RUN=true"
  task backfill: :environment do
    limit = ENV.fetch("LIMIT", nil)&.to_i
    force = ActiveModel::Type::Boolean.new.cast(ENV["FORCE"])
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV["DRY_RUN"])

    scope = Transaction.all
    scope = scope.where(category_id: nil) unless force
    scope = scope.limit(limit) if limit&.positive?

    puts "Processing #{scope.count} transactions..."

    suggester_cache = {}

    scope.find_each do |transaction|
      user = transaction.account.user
      suggester = suggester_cache[user.id] ||= CategorySuggester.new(user: user)

      suggestion = suggester.suggest(transaction.description)
      next unless suggestion&.category

      if dry_run
        puts "Would set transaction #{transaction.id} -> #{suggestion.category.name} (#{(suggestion.confidence * 100).round}%)"
        next
      end

      if suggestion.confidence >= 0.5
        transaction.update_columns(category_id: suggestion.category.id, updated_at: Time.current)
        puts "Updated transaction #{transaction.id} -> #{suggestion.category.name} (#{(suggestion.confidence * 100).round}%)"
      else
        puts "Skipped transaction #{transaction.id} due to low confidence (#{suggestion.confidence})"
      end
    end

    puts "Done."
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
end

