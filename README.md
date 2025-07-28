# [olubalance](https://www.olubalance.com)

#### A personal finance tool designed to help balance and reconcile your accounts. 

---

## What is olubalance?

### Intro

Having accumulated a considerable amount of debt a few years ago, and in need for a better way of tracking my family finances than using a spreadsheet, I decided to look into building my own solution. I had dabbled in Ruby on Rails briefly before and enjoyed it so took this opportunity to really dive in and build a full featured application. olubalance is constantly growing and I hope if you find it you'll enjoy it as much as I have enjoyed building it!

### Features

#### Basics
olubalance is meant to be used as an online checkbook register (remember when people used to "balance their checkbooks"?). The idea is that you enter transactions as you spend or earn and know exactly how much is in your account at any given time.

#### Avoid surprises
If you rely on online banking, you can sometimes be surprised when pending transactions post, or that check you wrote 3 weeks ago and forgot about until it's too late.  By using olubalance to track your finances, you can mitigate these surprises and stay on track! There is even a feature to mark transactions as pending so that you can keep an eye on those transactions in your regular online banking account. In olubalance, pending transactions are reflected in your account balance (unlike online banking)... yay!

#### Record keeping
One other fantastic feature is the ability to attach receipts to your transactions.  From a mobile device, it's as easy as snapping a photo of your receipt when you create a transaction and it will be saved where it needs to be for future reference.  Attachments can be either image files or PDF files (for online bill payments). This is a great way to keep record of where your money goes in case you ever need proof of it in the future.

#### Privacy matters

olubalance cannot and will not ever connect to your bank account. This is unlike other financial tools that "sync" your transactions from your online banking account.  With olubalance, you will be the only party to add or remove transactions within the app.  

#### Mobile Authentication

olubalance supports persistent login for mobile devices, including iOS app shortcuts. When you create an app shortcut on your iPhone, the application will automatically remember your login for 2 weeks, so you won't need to re-authenticate every time you tap the shortcut icon.

**Features:**
- Automatic "Remember me" for mobile devices
- 2-week session persistence
- Optimized for iOS app shortcuts
- Secure cookie-based authentication

#### License

olubalance is free and open source, and licensed under the [MIT License](https://github.com/odinsride/olubalance/blob/master/LICENSE). Feel free to build and deploy on your own server as you see fit (I recommend Dokku with the PostgreSQL Plugin)! See the license link for further details regarding terms of use.

---

## Screenshots

###### Accounts
![image](https://i.imgur.com/eyi8Swq.png)

###### Transactions
![image](https://i.imgur.com/8BLHzkA.png)

###### Transaction Form
![image](https://i.imgur.com/JV8oPma.png)

###### Transaction Details (with Receipt)
![image](https://i.imgur.com/OHsz0a5.png)

---

## Building / Contributing

Basic instructions for building olubalance on your local system

### Dependencies

* Ruby 2.6.4
* Rails 6.0.2.1
* PostgreSQL 12
* ImageMagick
* Your own Amazon S3 Storage Credentials (or change the config to use local storage)

Once dependencies have been met:

1. Create Postgres User, set a password
2. Run `bundle install`
3. Save the file `application.yml.sample` to `application.yml`
4. Set the configuration values in `application.yml` as you wish
5. Run `rails db:create`
6. Run `rails db:migrate`
7. Run `rails db:seed` if you wish to seed the database with sample data.
8. Boot up your rails server (`rails s`), and browse to `localhost:3000` in a web browser!

---

## Looking for Help?

Feel free to file an issue on the project and I'll do my best to accomodate! :)