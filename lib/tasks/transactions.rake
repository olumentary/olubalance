# frozen_string_literal: true

namespace :transactions do
  desc 'Sets the locked flag to true for all Starting Balance transactions'
  task lock_starting_balance: :environment do
    Transaction.where(description: 'Starting Balance').each do |t|
      t.update_attribute :locked, true
    end
  end

  desc 'Links existing transfer transactions that are missing counterpart_transaction_id (use DRY_RUN=true for dry-run mode)'
  task link_transfer_transactions: :environment do
    dry_run = ENV['DRY_RUN'] == 'true'
    
    if dry_run
      puts "=== DRY RUN MODE - No changes will be made ==="
    end
    puts "Starting to link transfer transactions..."
    
    # Find all unlinked transfer transactions
    unlinked_transfers = Transaction.where(transfer: true, counterpart_transaction_id: nil)
                                     .includes(:account)
                                     .order(:created_at)
    
    total_count = unlinked_transfers.count
    puts "Found #{total_count} unlinked transfer transactions"
    
    linked_count = 0
    skipped_count = 0
    no_match_count = 0
    error_count = 0
    
    unlinked_transfers.each do |transaction|
      next if transaction.counterpart_transaction_id.present?
      
      begin
        # Parse description to extract account name and direction
        match = transaction.description.match(/\ATransfer (to|from) (.+)\z/)
        unless match
          puts "  Warning: Transaction ##{transaction.id} has invalid description format: '#{transaction.description}'"
          skipped_count += 1
          next
        end
        
        direction = match[1] # "to" or "from"
        account_name = match[2].strip
        
        # Find the account mentioned in the description
        account = Account.find_by(name: account_name, user_id: transaction.account.user_id)
        unless account
          puts "  Warning: Transaction ##{transaction.id} references account '#{account_name}' which doesn't exist for user"
          skipped_count += 1
          next
        end
        
        # Determine what we're looking for
        # If this is "Transfer to X", we need "Transfer from X" on account X
        # If this is "Transfer from X", we need "Transfer to X" on account X
        opposite_direction = direction == "to" ? "from" : "to"
        expected_description = "Transfer #{opposite_direction} #{transaction.account.name}"
        
        # Find potential matches
        # Same user, opposite direction, same absolute amount, created_at within ±1 day
        date_range = transaction.created_at - 1.day..transaction.created_at + 1.day
        
        candidates = Transaction.where(
          transfer: true,
          counterpart_transaction_id: nil,
          account_id: account.id,
          description: expected_description
        ).where(
          created_at: date_range
        ).where(
          "ABS(amount) = ?", transaction.amount.abs
        ).where.not(
          id: transaction.id
        )
        
        if candidates.empty?
          puts "  No match found for Transaction ##{transaction.id} (#{transaction.description})"
          no_match_count += 1
          next
        end
        
        # Select best match (closest created_at timestamp)
        best_match = candidates.min_by { |c| (c.created_at - transaction.created_at).abs }
        
        # Link the transactions (unless dry-run)
        if dry_run
          puts "  [DRY RUN] Would link Transaction ##{transaction.id} (#{transaction.description}) with Transaction ##{best_match.id} (#{best_match.description})"
        else
          transaction.update_column(:counterpart_transaction_id, best_match.id)
          best_match.update_column(:counterpart_transaction_id, transaction.id)
          puts "  Linked Transaction ##{transaction.id} (#{transaction.description}) with Transaction ##{best_match.id} (#{best_match.description})"
        end
        linked_count += 1
        
      rescue StandardError => e
        puts "  Error processing Transaction ##{transaction.id}: #{e.message}"
        error_count += 1
      end
    end
    
    puts "\nSummary:"
    puts "  Total processed: #{total_count}"
    if dry_run
      puts "  Would link: #{linked_count} pairs (#{linked_count * 2} transactions)"
    else
      puts "  Successfully linked: #{linked_count} pairs (#{linked_count * 2} transactions linked in pairs)"
    end
    puts "  No match found: #{no_match_count}"
    puts "  Skipped (invalid format/missing account): #{skipped_count}"
    puts "  Errors: #{error_count}"
    if dry_run
      puts "\n=== DRY RUN COMPLETE - No changes were made ==="
      puts "Run without DRY_RUN=true to apply changes"
    end
    puts "Done!"
  end
end
