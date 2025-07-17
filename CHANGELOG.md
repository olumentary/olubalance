# Changelog

All notable changes to olubalance will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] changes

## [v1.10.0] - 2025-07-17

### New

- Inline editing of transactions from the transactions table
- Transactions will automatically be marked as pending when created
- Transactions must be manually reviewed to remove the pending status
- Quick receipt feature - upload a receipt from the home screen and create a shell transaction from mobile that can be updated and reviewed later
- Transaction description typeahead search/autofill
- Transaction UI improvements, including sticky header and grouping by transaction date

### Chores

- Upgrade to Rails 8.0
- Upgrade to Ruby 3.3.5
- Upgrade to Node 22.x
- Upgrade to Bulma 1.0
- Update gems and node packages

## [v1.9.0] - 2024-10-31

### Changed

- Removed Stimulus Reflex
- Reworked transaction sorting and searching, as well as pagination using Hotwire

### Fixed

- Fix display issue with stashes section on transaction page
- Fix issue running test suite caused by Postgres parameter in structure.sql

### Chores

- Upgrade to Rails 7.2
- Upgrade to Ruby 3.3.0
- Update gems and node packages

## [v1.8.5] - 2022-12-13

### Changed

- Disabled user registrations. This project is planned to be sunset in the near future.

## [v1.8.4] - 2021-08-14

### Fixed

- Fix ordering of transactions on summary page

## [v1.8.3] - 2021-08-13

### New

- Added a Summary Mailer to allow emailing of the daily summary report

### Chores

- Update all dependencies

## [v1.8.2] - 2021-07-31

### Fixed

- Re-added Stimulus Reflex dependencies that were erroneously removed due to a bad merge

### Chores

- Update all dependencies

## [v1.8.1] - 2021-07-24

### New

- A daily summary page has been added to quickly see all accounts with a list of transactions added in the current day, all pending transactions, and stash balances

### Chores

- Upgrade to Ruby 3.0.1
- Upgrade to Rails 6.1.4
- Update all dependencies

## [v1.8.0] - 2020-01-06

### New

- Accounts can now have an account type, which allows you to specify if the account is a Checking, Savings, Credit Card, or Cash account.
  - As a result, accounts are now organized by account type on the main screen
  - Additionally, for Credit and Savings accounts you can specify Interest Rate (as well as Credit Limit for Credit Cards), which will be displayed on the account cards and in the transactions list.
- Transfer feature added - for Checking, Savings, and Cash account types, you will now have the option to perform a transfer into another account. Doing so will automatically create the appropriate debit/credit transactions in the source and target accounts.

### Changed

- Stash UI has been revamped and hopefully will be nicer to use :)
- Transactions index page has minor UI improvements
- When uploading a receipt/attachment to a transaction, a loading indicator will now be displayed to indicate something is happening while you wait.

### Chores

- Upgrade to Ruby 3.0.0
- Upgrade to Rails 6.1.0
- Update all dependencies
- Tests have been cleaned up
- New tests created for Stashes and Stash Entries

## [v1.7.3] - 2020-08-27

### New

- User registration form now contains honeypot field. This is to further prevent spam registrations.

### Changed

- Dependencies updated

## [v1.7.2] - 2020-08-18

### New

- User registration now requires passing reCAPTCHA. This is to further prevent spam registrations.

## [v1.7.1] - 2020-08-17

### New

- User registration, and current user email changes now require email confirmation. This is to prevent false registrations from bots.
- Version number has been added to footer

### Changed

- Transaction attachment interface improved to display the filename of the current attachment, as well as corrections to a text overflow issue with long attachment filenames.
- Favicon has been updated

### Fixed

- User sign-out no longer causes an error
- Transactions with long descriptions now display better on mobile

## [v1.7.0] - 2020-08-06

### New

- Transaction sorting has been added on the date and description fields
- Transaction search has been improved and now provides instant results as you type

### Fixed

- Bulma Toast notifications become stuck on screen. Fixes #67
- When deleting a Stash, any stashed money should now be returned to the parent account. Fixes #99
- Pagination issues have been fixed

### Changed

- Many UI improvements to the transaction list header on both desktop and mobile

### Under the hood

- Assets pipeline dropped in favor of webpacker
- StimulusJS and StimulusReflex have been added
- Add pending rubocop cops
- Massive improvement to seeds file
- Navbar now displays the rails environment (non-production only)
- Upgrade to Fontawesome 5
- Dependencies updated

## [v1.6.4] - 2020-05-17

### Fixed

- Account Starting Balance field now allows decimals. Fixes #82

### Changed

- Gems and Yarn dependencies updated

## [v1.6.3] - 2020-04-17

### Fixed

- An issue with the date picker in Chrome has been fixed by removing bulma-calendar and replacing with a normal date picker field.
- New transactions now default to Debit.

### Changed

- Gems and Yarn dependencies updated

## [v1.6.2] - 2020-04-17

### Changed

- Gems and Yarn dependencies updated

## [v1.6.1] - 2020-03-08

### Changed

- puma bumped to 4.3.3
- nokogiri bumped to 1.10.8
- Other gems updated

## [v1.6.0] - 2020-02-05

### Added

- Account Stash feature added to assist in putting money aside and out of site for planned expenses.
- Transaction locking feature was implemented and enabled for starting balance transactions as well as stash-related transactions

### Changed

- Bulma version bumped to 0.8.0
- Ruby version bumped to 2.6.5
- Bundler version bumped to 2.0.2
- will_paginate gem swapped for pagy gem
- Transactions screen now displays total Pending transactions and total Stashed balance

## [v1.5.0] - 2019-12-19

### Changed

- Ruby version updated to 2.6.4
- Rails version updated to 6.0.2.1
- Other gems updated
- Github pages disabled (for now)
- Updated README with much more information

## [v1.4.5] - 2019-12-16

### Fixed

- Fixed broken Fontawesome icons by reverting to using Fontawesome 4.7 via the `font-awesome-rails` gem

## [v1.4.2] - 2019-12-16

### Fixed

- Fix for `config.assets.js_compressor` setting

## [v1.4.1] - 2019-12-16

### Fixed

- Bump Devise to 4.7.1
- Bump Puma to 4.3.1

## [v1.4.0] - 2019-12-16

### Changed

- olubalance has been redesigned! The codebase has had a thorough first-pass to optimize and clean up views, partials, and models. More improvements to come!

### Added

- Transactions can now be flagged as "Pending". Pending transactions will appear at the top of the transaction list and are useful for marking transactions that don't post the same day of the transaction, such as when writing a check. Pending transactions will also update your overall account balance so you can keep track of what your actual account balance is.
- RSpec model and request specs have been added to test basic functionality and will continue to be built upon for future releases

## [v1.3.2] - 2019-06-27

### Fixed

- Updated Paperclip attachment migration rake task to handle errors and report them for manual clean-up
- Updated Transaction show view to display a generic file icon for non-image attachments, since extra effort is required to generate thumbnails for those with ActiveStorage.

## [v1.3.0] - 2019-06-25

### Changed

- Migration of code and attachment objects from Paperclip to ActiveStorage

## [v1.2.3] - 2019-06-25

### Changed

- Ruby version updated to 2.6.3
- Rails version updated to 5.2.3
- Other gems updated

### Removed

- Removed Account Documents attachment type. This is not a well known or used feature, so it will be reintroduced at a later time.

## [v1.2.2] - 2019-05-19

### Fixed

- User registration issues have been fixed (#35)
- Transaction attachments will now be renamed to `{{trx_date}}_{{description}}.{{extension}}`

## [v1.2.1] - 2019-02-24

### Fixed

- Transaction attachments were not receiving the transaction ID in the filename. This has been corrected.
- Downgraded bundler to 1.16.2 due to deployment errors

## [v1.2.0] - 2019-02-24

### Added

- Accounts can be deactivated, which hides them from the main account list. Inactive accounts can be found from the user menu and reactivated at any time. This provides a non-destructive method of archiving an account for historical purposes. Deleting accounts is no longer possible from the UI.
- A new field has been added to allow storing the last 4 digits of the account number along with an account. This can be helpful for quickly identifying an account by number.
- Transaction search based on the description field has been added.
- Account-level attachments have been added. An account may have many attachments. This is useful for storing account statements and correspondence in one location.
- Transaction autocomplete has been enabled in the description field. Autocomplete sources from a unique list of all transaction descriptions for the particular account.

### Changed

- Attachments for transactions are now renamed at upload to be formatted as `(trx_id)_(description)_(trx_date).(extension)`
- Attachment links will direct to an https URL
- Ruby version updated to 2.5.1
- Rails version updated to 5.2.2

### Fixed

- Account deletion removed, but deactivation will now deactivate the proper account.
- When editing a transaction on page N of the transaction list, after clicking update or cancel you will now be redirected back to page N instead of page 1.
- Account name should display better from the transaction list on mobile.

#### Gem Changes

- sass-rails gem replaced with sassc-rails
- pg gem updated to 1.1.4
- puma gem updated to 3.12.0
- aws-sdk gem replaced with aws-sdk-s3

[v1.2.0] will be the final feature release of olubalance as a pure Rails app. Going forward, olubalance will function as Rails API with a Vue.js frontend.

## [v1.1.3] - 2018-08-19

### Fixed

- Fixed issue with local user Time Zone. Users are now required to set their local timezone, and all dates within the application front end will reflect this timezone setting.

## [v1.1.2] - 2018-08-19

### Fixed

- Fixed issue with Transaction datepicker not loading

## [v1.1.1] - 2018-07-25

### Fixed

- Remove unnecessary devise controllers that were causing problems with deployment

## [v1.1.0] - 2018-07-24

### Added

- Major overhaul of the user interface using Material Design
- Better support for Mobile devices

### Changed

- Pagination looks nicer
- First and Last Name added to user registration

### Fixed

- Account starting balance is no longer changeable after creation

## [v1.0.2] - 2018-05-18

### Added

- Transactions can now have attachments! You can now save invoices or receipts alongside your transactions.
- Attachments are stored on Amazon S3
- Images or PDF formats are supported.

## [v1.0.1] - 2018-04-07

### Fixed

- Corrected a typo on the homepage

## v1.0.0 - 2018-04-06

### Added

- olubalance 1.0.0 is our initial release which has basic functionality for users, such as
- User signup and login
- Create, edit, and delete accounts
- Create, edit, and delete transactions within each account
- Transaction table pagination (default 25 rows per page)
- Running balance calculated at the transaction level
- Account balance will be updated automatically after user operations on transactions
- Account overview with list of all accounts and balances for each

[Unreleased]: https://github.com/odinsride/olubalance/compare/v1.10.0...develop
[v1.10.0]: https://github.com/odinsride/olubalance/compare/v1.9.0...1.10.0
[v1.9.0]: https://github.com/odinsride/olubalance/compare/v1.8.5...v1.9.0
[v1.8.5]: https://github.com/odinsride/olubalance/compare/v1.8.4...v1.8.5
[v1.8.4]: https://github.com/odinsride/olubalance/compare/v1.8.3...v1.8.4
[v1.8.3]: https://github.com/odinsride/olubalance/compare/v1.8.2...v1.8.3
[v1.8.2]: https://github.com/odinsride/olubalance/compare/v1.8.1...v1.8.2
[v1.8.1]: https://github.com/odinsride/olubalance/compare/v1.8.0...v1.8.1
[v1.8.0]: https://github.com/odinsride/olubalance/compare/v1.7.3...v1.8.0
[v1.7.3]: https://github.com/odinsride/olubalance/compare/v1.7.2...v1.7.3
[v1.7.2]: https://github.com/odinsride/olubalance/compare/v1.7.1...v1.7.2
[v1.7.1]: https://github.com/odinsride/olubalance/compare/v1.7.0...v1.7.1
[v1.7.0]: https://github.com/odinsride/olubalance/compare/v1.6.4...v1.7.0
[v1.6.4]: https://github.com/odinsride/olubalance/compare/v1.6.3...v1.6.4
[v1.6.3]: https://github.com/odinsride/olubalance/compare/v1.6.2...v1.6.3
[v1.6.2]: https://github.com/odinsride/olubalance/compare/v1.6.1...v1.6.2
[v1.6.1]: https://github.com/odinsride/olubalance/compare/v1.6.0...v1.6.1
[v1.6.0]: https://github.com/odinsride/olubalance/compare/v1.5.0...v1.6.0
[v1.5.0]: https://github.com/odinsride/olubalance/compare/v1.4.5...v1.5.0
[v1.4.5]: https://github.com/odinsride/olubalance/compare/v1.4.2...v1.4.5
[v1.4.2]: https://github.com/odinsride/olubalance/compare/v1.4.1...v1.4.2
[v1.4.1]: https://github.com/odinsride/olubalance/compare/v1.4.0...v1.4.1
[v1.4.0]: https://github.com/odinsride/olubalance/compare/v1.3.2...v1.4.0
[v1.3.2]: https://github.com/odinsride/olubalance/compare/v1.3.0...v1.3.2
[v1.3.0]: https://github.com/odinsride/olubalance/compare/v1.2.2...v1.3.0
[v1.2.2]: https://github.com/odinsride/olubalance/compare/v1.2.1...v1.2.2
[v1.2.1]: https://github.com/odinsride/olubalance/compare/v1.2.0...v1.2.1
[v1.2.0]: https://github.com/odinsride/olubalance/compare/v1.1.3...v1.2.0
[v1.1.3]: https://github.com/odinsride/olubalance/compare/v1.1.2...v1.1.3
[v1.1.2]: https://github.com/odinsride/olubalance/compare/v1.1.1...v1.1.2
[v1.1.1]: https://github.com/odinsride/olubalance/compare/v1.1.0...v1.1.1
[v1.1.0]: https://github.com/odinsride/olubalance/compare/v1.0.2...v1.1.0
[v1.0.2]: https://github.com/odinsride/olubalance/compare/v1.0.1...v1.0.2
[v1.0.1]: https://github.com/odinsride/olubalance/compare/v1.0...v1.0.1
