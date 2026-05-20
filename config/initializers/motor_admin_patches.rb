# frozen_string_literal: true

# motor-admin 0.5.0 monkey-patches ActiveRecord::Associations::AliasTracker
# with an older two-arg initialize (connection, aliases) that pre-dates Rails 7.
# Rails 8.1 calls `new(connection.table_alias_length, aliases)`, passing an
# integer as the first argument. The motor patch then never sets
# @table_alias_length, and downstream calls to `truncate` crash on `nil - 2`.
#
# This re-opens AliasTracker after motor-admin loads and restores the Rails 8.1
# initialize signature while preserving the @relation_trail attribute motor uses.
Rails.application.config.after_initialize do
  ActiveRecord::Associations::AliasTracker.class_eval do
    def initialize(table_alias_length, aliases)
      @aliases = aliases
      @table_alias_length = table_alias_length
      @relation_trail = {}
    end
  end
end
