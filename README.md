![Devise Logo](https://raw.github.com/heartcombo/devise/main/devise.png)

Devise is a flexible authentication solution for Rails based on Warden. It:

* Is Rack based;
* Is a complete MVC solution based on Rails engines;
* Allows you to have multiple models signed in at the same time;
* Is based on a modularity concept: use only what you really need.

It's composed of 10 modules:

* [Database Authenticatable](https://www.rubydoc.info/gems/devise/Devise/Models/DatabaseAuthenticatable): hashes and stores a password in the database to validate the authenticity of a user while signing in. The authentication can be done both through POST requests or HTTP Basic Authentication.
* [Omniauthable](https://www.rubydoc.info/gems/devise/Devise/Models/Omniauthable): adds OmniAuth (https://github.com/omniauth/omniauth) support.
* [Confirmable](https://www.rubydoc.info/gems/devise/Devise/Models/Confirmable): sends emails with confirmation instructions and verifies whether an account is already confirmed during sign in.
* [Recoverable](https://www.rubydoc.info/gems/devise/Devise/Models/Recoverable): resets the user password and sends reset instructions.
* [Registerable](https://www.rubydoc.info/gems/devise/Devise/Models/Registerable): handles signing up users through a registration process, also allowing them to edit and destroy their account.
* [Rememberable](https://www.rubydoc.info/gems/devise/Devise/Models/Rememberable): manages generating and clearing a token for remembering the user from a saved cookie.
* [Trackable](https://www.rubydoc.info/gems/devise/Devise/Models/Trackable): tracks sign in count, timestamps and IP address.
* [Timeoutable](https://www.rubydoc.info/gems/devise/Devise/Models/Timeoutable): expires sessions that have not been active in a specified period of time.
* [Validatable](https://www.rubydoc.info/gems/devise/Devise/Models/Validatable): provides validations of email and password. It's optional and can be customized, so you're able to define your own validations.
* [Lockable](https://www.rubydoc.info/gems/devise/Devise/Models/Lockable): locks an account after a specified number of failed sign-in attempts. Can unlock via email or after a specified time period.

## Table of Contents

<!-- TOC depthFrom:1 depthTo:6 withLinks:1 orderedList:0 -->

- [Information](#information)
	- [The Devise wiki](#the-devise-wiki)
	- [Bug reports](#bug-reports)
	- [StackOverflow and Mailing List](#stackoverflow-and-mailing-list)
	- [RDocs](#rdocs)
	- [Example applications](#example-applications)
	- [Extensions](#extensions)
	- [Supported Ruby / Rails versions](#supported-ruby--rails-versions)
	- [Contributing](#contributing)
- [Starting with Rails?](#starting-with-rails)
- [Getting started](#getting-started)
	- [Controller filters and helpers](#controller-filters-and-helpers)
	- [Configuring Models](#configuring-models)
	- [Strong Parameters](#strong-parameters)
	- [Configuring views](#configuring-views)
	- [Configuring controllers](#configuring-controllers)
	- [Configuring routes](#configuring-routes)
	- [I18n](#i18n)
	- [Test helpers](#test-helpers)
	- [Controller tests](#controller-tests)
	- [Integration tests](#integration-tests)
	- [OmniAuth](#omniauth)
	- [Configuring multiple models](#configuring-multiple-models)
	- [Active Job Integration](#active-job-integration)
	- [Password reset tokens and Rails logs](#password-reset-tokens-and-rails-logs)
	- [Other ORMs](#other-orms)
	- [Amazon DynamoDB](#amazon-dynamodb)
	- [Rails API mode](#rails-api-mode)
- [Additional information](#additional-information)
	- [Warden](#warden)
- [License](#license)

<!-- /TOC -->



## Information

### The Devise wiki

The Devise Wiki has lots of additional information about Devise including many "how-to" articles and answers to the most frequently asked questions. Please browse the Wiki after finishing this README:

https://github.com/heartcombo/devise/wiki

### Bug reports

If you discover a problem with Devise, we would like to know about it. However, we ask that you please review these guidelines before submitting a bug report:

https://github.com/heartcombo/devise/wiki/Bug-reports

If you have discovered a security related bug, please do *NOT* use the GitHub issue tracker. Send an email to heartcombo.oss@gmail.com.

### StackOverflow and Mailing List

If you have any questions, comments, or concerns, please use StackOverflow instead of the GitHub issue tracker:

https://stackoverflow.com/questions/tagged/devise

The deprecated mailing lists can still be read on:

https://groups.google.com/group/plataformatec-devise
https://groups.google.com/group/heartcombo

### RDocs

You can view the Devise documentation in RDoc format here:

https://rubydoc.info/github/heartcombo/devise/main/frames

If you need to use Devise with previous versions of Rails, you can always run "gem server" from the command line after you install the gem to access the old documentation.

### Example applications

There are a few example applications available on GitHub that demonstrate various features of Devise with different versions of Rails. You can view them here:

https://github.com/heartcombo/devise/wiki/Example-Applications

### Extensions

Our community has created a number of extensions that add functionality above and beyond what is included with Devise. You can view a list of available extensions and add your own here:

https://github.com/heartcombo/devise/wiki/Extensions

### Supported Ruby / Rails versions

We intend to maintain support for all Ruby / Rails versions that haven't reached end-of-life.

For more information about specific versions please check [Ruby](https://www.ruby-lang.org/en/downloads/branches/)
and [Rails](https://guides.rubyonrails.org/maintenance_policy.html) maintenance policies, and our test matrix.

### Contributing

We hope that you will consider contributing to Devise. Please read this short overview for some information about how to get started:

https://github.com/heartcombo/devise/wiki/Contributing

You will usually want to write tests for your changes.  To run the test suite, go into Devise's top-level directory and run `bundle install` and `bin/test`.
Devise works with multiple Ruby and Rails versions, and ActiveRecord, Mongoid and DynamoDB ORMs, which means you can run the test suite with some modifiers: `DEVISE_ORM` and `BUNDLE_GEMFILE`.

#### DEVISE_ORM
Since Devise supports ActiveRecord, Mongoid and DynamoDB, we rely on this variable to run specific code for each ORM.
The default value of `DEVISE_ORM` is `active_record`. To run the tests for Mongoid, you can pass `mongoid`:
```
DEVISE_ORM=mongoid bin/test

==> Devise.orm = :mongoid
```
When running the tests for Mongoid, you will need to have a MongoDB server (version 2.0 or newer) running on your system.

DynamoDB is tested once per supported library, with `DEVISE_ORM=dynamoid` and `DEVISE_ORM=aws_record`. These need [DynamoDB Local](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html) (or any DynamoDB-compatible endpoint), by default on `http://localhost:8000`; set `DYNAMODB_ENDPOINT` to use another one. Tables are created with a per-run prefix and dropped when the run ends.
```bash
docker run -d -p 8000:8000 amazon/dynamodb-local
DEVISE_ORM=dynamoid bin/test
DEVISE_ORM=aws_record bin/test
```
The tests specific to the DynamoDB adapter live in `test/dynamodb` and are skipped for the other ORMs.

Please note that the command output will show the variable value being used.

#### BUNDLE_GEMFILE
We can use this variable to tell bundler what Gemfile it should use (instead of the one in the current directory).
Inside the [gemfiles](https://github.com/heartcombo/devise/tree/main/gemfiles) directory, we have one for each version of Rails we support. When you send us a pull request, it may happen that the test suite breaks using some of them. If that's the case, you can simulate the same environment using the `BUNDLE_GEMFILE` variable.
For example, if the tests broke using Ruby 3.4 and Rails 8.0, you can do the following:
```bash
chruby 3.4.0 # or rbenv shell 3.4.0, or rvm use 3.4.0, etc.
BUNDLE_GEMFILE=gemfiles/Gemfile-rails-8-0 bundle install
BUNDLE_GEMFILE=gemfiles/Gemfile-rails-8-0 bin/test
```

You can also combine both of them if the tests broke for Mongoid:
```bash
BUNDLE_GEMFILE=gemfiles/Gemfile-rails-8-0 bundle install
BUNDLE_GEMFILE=gemfiles/Gemfile-rails-8-0 DEVISE_ORM=mongoid bin/test
```

### Running tests
Devise uses [minitest](https://github.com/seattlerb/minitest) as test framework.

* Running all tests:
```bash
bin/test
```

* Running tests for an specific file:
```bash
bin/test test/models/trackable_test.rb
```

* Running a specific test given a line number or a regex:
```bash
bin/test test/models/trackable_test.rb:16
bin/test test/models/trackable_test.rb -n '/update.*record/'
```

## Starting with Rails?

If you are building your first Rails application, we recommend you *do not* use Devise. Devise requires a good understanding of the Rails Framework. In such cases, we advise you to start a simple authentication system from scratch. Here's a few resources that should help you get started:

* Michael Hartl's online book: https://www.railstutorial.org/book/modeling_users
* Ryan Bates' Railscasts: http://railscasts.com/episodes/250-authentication-from-scratch and http://railscasts.com/episodes/250-authentication-from-scratch-revised
* Codecademy's Ruby on Rails: Authentication and Authorization: https://www.codecademy.com/learn/rails-auth

Once you have solidified your understanding of Rails and authentication mechanisms, we assure you Devise will be very pleasant to work with. :smiley:

## Getting started

Devise 5 works with Rails 7 onwards. Run:

```sh
bundle add devise
```

Next, you need to run the generator:

```console
rails generate devise:install
```

At this point, a number of instructions will appear in the console. Among these instructions, you'll need to set up the default URL options for the Devise mailer in each environment. Here is a possible configuration for `config/environments/development.rb`:

```ruby
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

The generator will install an initializer which describes ALL of Devise's configuration options. It is *imperative* that you take a look at it. When you are done, you are ready to add Devise to any of your models using the generator.


In the following command you will replace `MODEL` with the class name used for the application’s users (it’s frequently `User` but could also be `Admin`). This will create a model (if one does not exist) and configure it with the default Devise modules. The generator also configures your `config/routes.rb` file to point to the Devise controller.

```console
rails generate devise MODEL
```

Next, check the MODEL for any additional configuration options you might want to add, such as confirmable or lockable. If you add an option, be sure to inspect the migration file (created by the generator if your ORM supports them) and uncomment the appropriate section.  For example, if you add the confirmable option in the model, you'll need to uncomment the Confirmable section in the migration.

Then run `rails db:migrate`

You should restart your application after changing Devise's configuration options (this includes stopping spring). Otherwise, you will run into strange errors, for example, users being unable to login and route helpers being undefined.

### Controller filters and helpers

Devise will create some helpers to use inside your controllers and views. To set up a controller with user authentication, just add this before_action (assuming your devise model is 'User'):

```ruby
before_action :authenticate_user!
```

For Rails 5, note that `protect_from_forgery` is no longer prepended to the `before_action` chain, so if you have set `authenticate_user` before `protect_from_forgery`, your request will result in "Can't verify CSRF token authenticity." To resolve this, either change the order in which you call them, or use `protect_from_forgery prepend: true`.

If your devise model is something other than User, replace "_user" with "_yourmodel". The same logic applies to the instructions below.

To verify if a user is signed in, use the following helper:

```ruby
user_signed_in?
```

For the current signed-in user, this helper is available:

```ruby
current_user
```

You can access the session for this scope:

```ruby
user_session
```

After signing in a user, confirming the account or updating the password, Devise will look for a scoped root path to redirect to. For instance, when using a `:user` resource, the `user_root_path` will be used if it exists; otherwise, the default `root_path` will be used. This means that you need to set the root inside your routes:

```ruby
root to: 'home#index'
```

You can also override `after_sign_in_path_for` and `after_sign_out_path_for` to customize your redirect hooks.

Notice that if your Devise model is called `Member` instead of `User`, for example, then the helpers available are:

```ruby
before_action :authenticate_member!

member_signed_in?

current_member

member_session
```

### Configuring Models

The Devise method in your models also accepts some options to configure its modules. For example, you can choose the cost of the hashing algorithm with:

```ruby
devise :database_authenticatable, :registerable, :confirmable, :recoverable, stretches: 13
```

Besides `:stretches`, you can define `:pepper`, `:encryptor`, `:confirm_within`, `:remember_for`, `:timeout_in`, `:unlock_in` among other options. For more details, see the initializer file that was created when you invoked the "devise:install" generator described above. This file is usually located at `/config/initializers/devise.rb`.

### Strong Parameters

The Parameter Sanitizer API has changed for Devise 4 :warning:

*For previous Devise versions see https://github.com/heartcombo/devise/tree/3-stable#strong-parameters*

When you customize your own views, you may end up adding new attributes to forms. Rails 4 moved the parameter sanitization from the model to the controller, causing Devise to handle this concern at the controller as well.

There are just three actions in Devise that allow any set of parameters to be passed down to the model, therefore requiring sanitization. Their names and default permitted parameters are:

* `sign_in` (`Devise::SessionsController#create`) - Permits only the authentication keys (like `email`)
* `sign_up` (`Devise::RegistrationsController#create`) - Permits authentication keys plus `password` and `password_confirmation`
* `account_update` (`Devise::RegistrationsController#update`) - Permits authentication keys plus `password`, `password_confirmation` and `current_password`

In case you want to permit additional parameters (the lazy way™), you can do so using a simple before action in your `ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username])
  end
end
```

The above works for any additional fields where the parameters are simple scalar types. If you have nested attributes (say you're using `accepts_nested_attributes_for`), then you will need to tell devise about those nestings and types:

```ruby
class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, address_attributes: [:country, :state, :city, :area, :postal_code]])
  end
end
```

Devise allows you to completely change Devise defaults or invoke custom behavior by passing a block:

To permit simple scalar values for username and email, use this

```ruby
def configure_permitted_parameters
  devise_parameter_sanitizer.permit(:sign_in) do |user_params|
    user_params.permit(:username, :email)
  end
end
```

If you have some checkboxes that express the roles a user may take on registration, the browser will send those selected checkboxes as an array. An array is not one of Strong Parameters' permitted scalars, so we need to configure Devise in the following way:

```ruby
def configure_permitted_parameters
  devise_parameter_sanitizer.permit(:sign_up) do |user_params|
    user_params.permit({ roles: [] }, :email, :password, :password_confirmation)
  end
end
```
For the list of permitted scalars, and how to declare permitted keys in nested hashes and arrays, see

https://github.com/rails/strong_parameters#nested-parameters

If you have multiple Devise models, you may want to set up a different parameter sanitizer per model. In this case, we recommend inheriting from `Devise::ParameterSanitizer` and adding your own logic:

```ruby
class User::ParameterSanitizer < Devise::ParameterSanitizer
  def initialize(*)
    super
    permit(:sign_up, keys: [:username, :email])
  end
end
```

And then configure your controllers to use it:

```ruby
class ApplicationController < ActionController::Base
  protected

  def devise_parameter_sanitizer
    if resource_class == User
      User::ParameterSanitizer.new(User, :user, params)
    else
      super # Use the default one
    end
  end
end
```

The example above overrides the permitted parameters for the user to be both `:username` and `:email`. The non-lazy way to configure parameters would be by defining the before filter above in a custom controller. We detail how to configure and customize controllers in some sections below.

### Configuring views

We built Devise to help you quickly develop an application that uses authentication. However, we don't want to be in your way when you need to customize it.

Since Devise is an engine, all its views are packaged inside the gem. These views will help you get started, but after some time you may want to change them. If this is the case, you just need to invoke the following generator, and it will copy all views to your application:

```console
rails generate devise:views
```

If you have more than one Devise model in your application (such as `User` and `Admin`), you will notice that Devise uses the same views for all models. Fortunately, Devise offers an easy way to customize views. All you need to do is set `config.scoped_views = true` inside the `config/initializers/devise.rb` file.

After doing so, you will be able to have views based on the role like `users/sessions/new` and `admins/sessions/new`. If no view is found within the scope, Devise will use the default view at `devise/sessions/new`. You can also use the generator to generate scoped views:

```console
rails generate devise:views users
```

If you would like to generate only a few sets of views, like the ones for the `registerable` and `confirmable` module,
you can pass a list of views to the generator with the `-v` flag.

```console
rails generate devise:views -v registrations confirmations
```

### Configuring controllers

If the customization at the views level is not enough, you can customize each controller by following these steps:

1. Create your custom controllers using the generator which requires a scope:

    ```console
    rails generate devise:controllers [scope]
    ```

    If you specify `users` as the scope, controllers will be created in `app/controllers/users/`.
    And the sessions controller will look like this:

    ```ruby
    class Users::SessionsController < Devise::SessionsController
      # GET /resource/sign_in
      # def new
      #   super
      # end
      ...
    end
    ```
    Use the `-c` flag to specify one or more controllers, for example: `rails generate devise:controllers users -c sessions`

2. Tell the router to use this controller:

    ```ruby
    devise_for :users, controllers: { sessions: 'users/sessions' }
    ```

3. Recommended but not required: copy (or move) the views from `devise/sessions` to `users/sessions`. Rails will continue using the views from `devise/sessions` due to inheritance if you skip this step, but having the views matching the controller(s) keeps things consistent.

4. Finally, change or extend the desired controller actions.

    You can completely override a controller action:

    ```ruby
    class Users::SessionsController < Devise::SessionsController
      def create
        # custom sign-in code
      end
    end
    ```

    Or you can simply add new behavior to it:

    ```ruby
    class Users::SessionsController < Devise::SessionsController
      def create
        super do |resource|
          BackgroundWorker.trigger(resource)
        end
      end
    end
    ```

    This is useful for triggering background jobs or logging events during certain actions.

Remember that Devise uses flash messages to let users know if sign in was successful or unsuccessful. Devise expects your application to call `flash[:notice]` and `flash[:alert]` as appropriate. Do not print the entire flash hash, print only specific keys. In some circumstances, Devise adds a `:timedout` key to the flash hash, which is not meant for display. Remove this key from the hash if you intend to print the entire hash.

### Configuring routes

Devise also ships with default routes. If you need to customize them, you should probably be able to do it through the devise_for method. It accepts several options like :class_name, :path_prefix and so on, including the possibility to change path names for I18n:

```ruby
devise_for :users, path: 'auth', path_names: { sign_in: 'login', sign_out: 'logout', password: 'secret', confirmation: 'verification', unlock: 'unblock', registration: 'register', sign_up: 'cmon_let_me_in' }
```

Be sure to check `devise_for` [documentation](https://www.rubydoc.info/gems/devise/ActionDispatch/Routing/Mapper#devise_for-instance_method) for details.

If you have the need for more deep customization, for instance to also allow "/sign_in" besides "/users/sign_in", all you need to do is create your routes normally and wrap them in a `devise_scope` block in the router:

```ruby
devise_scope :user do
  get 'sign_in', to: 'devise/sessions#new'
end
```

This way, you tell Devise to use the scope `:user` when "/sign_in" is accessed. Notice `devise_scope` is also aliased as `as` in your router.

Please note: You will still need to add `devise_for` in your routes in order to use helper methods such as `current_user`.

```ruby
devise_for :users, skip: :all
```

### Hotwire/Turbo

Devise integrates with Hotwire/Turbo by treating such requests as navigational, and configuring certain responses for errors and redirects to match the expected behavior. New apps are generated with the following response configuration by default, and existing apps may opt-in by adding the config to their Devise initializers:

```ruby
Devise.setup do |config|
  # ...
  # When using Devise with Hotwire/Turbo, the http status for error responses
  # and some redirects must match the following. The default in Devise for existing
  # apps is `200 OK` and `302 Found` respectively, but new apps are generated with
  # these new defaults that match Hotwire/Turbo behavior.
  # Note: These might become the new default in future versions of Devise.
  config.responder.error_status = :unprocessable_content # for Rack 3.1 or higher
  # config.responder.error_status = :unprocessable_entity # for Rack 3.0 or lower
  config.responder.redirect_status = :see_other
end
```

**Important**: these custom responses require the `responders` gem version to be `3.1.0` or higher, please make sure you update it if you're going to use this configuration. Check [this upgrade guide](https://github.com/heartcombo/devise/wiki/How-To:-Upgrade-to-Devise-4.9.0-[Hotwire-Turbo-integration]) for more info.

_Note_: the above statuses configuration may become the default for Devise in a future release.

There are a couple other changes you might need to make in your app to work with Hotwire/Turbo, if you're migrating from rails-ujs:

* The `data-confirm` option that adds a confirmation modal to buttons/forms before submission needs to change to `data-turbo-confirm`, so that Turbo handles those appropriately.
* The `data-method` option that sets the request method for link submissions needs to change to `data-turbo-method`. This is not necessary for `button_to` or `form`s since Turbo can handle those.

If you're setting up Devise to sign out via `:delete`, and you're using links (instead of buttons wrapped in a form) to sign out with the `method: :delete` option, they will need to be updated as described above. (Devise does not provide sign out links/buttons in its shared views.)

Make sure to inspect your views looking for those, and change appropriately.

### I18n

Devise uses flash messages with I18n, in conjunction with the flash keys :notice and :alert. To customize your app, you can set up your locale file:

```yaml
en:
  devise:
    sessions:
      signed_in: 'Signed in successfully.'
```

You can also create distinct messages based on the resource you've configured using the singular name given in routes:

```yaml
en:
  devise:
    sessions:
      user:
        signed_in: 'Welcome user, you are signed in.'
      admin:
        signed_in: 'Hello admin!'
```

The Devise mailer uses a similar pattern to create subject messages:

```yaml
en:
  devise:
    mailer:
      confirmation_instructions:
        subject: 'Hello everybody!'
        user_subject: 'Hello User! Please confirm your email'
      reset_password_instructions:
        subject: 'Reset instructions'
```

Take a look at our locale file to check all available messages. You may also be interested in one of the many translations that are available on our wiki:

https://github.com/heartcombo/devise/wiki/I18n

Caution: Devise Controllers inherit from ApplicationController. If your app uses multiple locales, you should be sure to set I18n.locale in ApplicationController.

### Test helpers

Devise includes some test helpers for controller and integration tests.
In order to use them, you need to include the respective module in your test
cases/specs.

### Controller tests

Controller tests require that you include `Devise::Test::IntegrationHelpers` on
your test case or its parent `ActionController::TestCase` superclass.
For Rails versions prior to 5, include `Devise::Test::ControllerHelpers` instead, since the superclass
for controller tests was changed to ActionDispatch::IntegrationTest
(for more details, see the [Integration tests](#integration-tests) section).

```ruby
class PostsControllerTest < ActionController::TestCase
  include Devise::Test::IntegrationHelpers # Rails >= 5
end
```

```ruby
class PostsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers # Rails < 5
end
```

If you're using RSpec, you can put the following inside a file named
`spec/support/devise.rb` or in your `spec/spec_helper.rb` (or
`spec/rails_helper.rb` if you are using `rspec-rails`):

```ruby
RSpec.configure do |config|
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :view
end
```

Just be sure that this inclusion is made *after* the `require 'rspec/rails'` directive.

Now you are ready to use the `sign_in` and `sign_out` methods on your controller
tests:

```ruby
sign_in @user
sign_in @user, scope: :admin
```

If you are testing Devise internal controllers or a controller that inherits
from Devise's, you need to tell Devise which mapping should be used before a
request. This is necessary because Devise gets this information from the router,
but since controller tests do not pass through the router, it needs to be stated
explicitly. For example, if you are testing the user scope, simply use:

```ruby
test 'GET new' do
  # Mimic the router behavior of setting the Devise scope through the env.
  @request.env['devise.mapping'] = Devise.mappings[:user]

  # Use the sign_in helper to sign in a fixture `User` record.
  sign_in users(:alice)

  get :new

  # assert something
end
```

### Integration tests

Integration test helpers are available by including the
`Devise::Test::IntegrationHelpers` module.

```ruby
class PostsTests < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
```

Now you can use the following `sign_in` and `sign_out` methods in your integration
tests:

```ruby
sign_in users(:bob)
sign_in users(:bob), scope: :admin

sign_out :user
```

RSpec users can include the `IntegrationHelpers` module on their `:feature` specs.

```ruby
RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :feature
end
```

Unlike controller tests, integration tests do not need to supply the
`devise.mapping` `env` value, as the mapping can be inferred by the routes that
are executed in your tests.

You can read more about testing your Rails controllers with RSpec in the wiki:

* https://github.com/heartcombo/devise/wiki/How-To:-Test-controllers-with-Rails-(and-RSpec)

### OmniAuth

Devise comes with OmniAuth support out of the box to authenticate with other providers. To use it, simply specify your OmniAuth configuration in `config/initializers/devise.rb`:

```ruby
config.omniauth :github, 'APP_ID', 'APP_SECRET', scope: 'user,public_repo'
```

You can read more about OmniAuth support in the wiki:

* https://github.com/heartcombo/devise/wiki/OmniAuth:-Overview

### Configuring multiple models

Devise allows you to set up as many Devise models as you want. If you want to have an Admin model with just authentication and timeout features, in addition to the User model above, just run:

```ruby
# Create a migration with the required fields
create_table :admins do |t|
  t.string :email
  t.string :encrypted_password
  t.timestamps null: false
end

# Inside your Admin model
devise :database_authenticatable, :timeoutable

# Inside your routes
devise_for :admins

# Inside your protected controller
before_action :authenticate_admin!

# Inside your controllers and views
admin_signed_in?
current_admin
admin_session
```

Alternatively, you can simply run the Devise generator.

Keep in mind that those models will have completely different routes. They **do not** and **cannot** share the same controller for sign in, sign out and so on. In case you want to have different roles sharing the same actions, we recommend that you use a role-based approach, by either providing a role column or using a dedicated gem for authorization.

### Active Job Integration

If you are using Active Job to deliver Action Mailer messages in the
background through a queuing back-end, you can send Devise emails through your
existing queue by overriding the `send_devise_notification` method in your model.

```ruby
def send_devise_notification(notification, *args)
  devise_mailer.send(notification, self, *args).deliver_later
end
```

### Password reset tokens and Rails logs

If you enable the [Recoverable](https://www.rubydoc.info/gems/devise/Devise/Models/Recoverable) module, note that a stolen password reset token could give an attacker access to your application. Devise takes effort to generate random, secure tokens, and stores only token digests in the database, never plaintext. However the default logging behavior in Rails can cause plaintext tokens to leak into log files:

1. Action Mailer logs the entire contents of all outgoing emails to the DEBUG level. Password reset tokens delivered to users in email will be leaked.
2. Active Job logs all arguments to every enqueued job at the INFO level. If you configure Devise to use `deliver_later` to send password reset emails, password reset tokens will be leaked.

Rails sets the production logger level to INFO by default. Consider changing your production logger level to WARN if you wish to prevent tokens from being leaked into your logs. In `config/environments/production.rb`:

```ruby
config.log_level = :warn
```


### Other ORMs

Devise supports ActiveRecord (default), Mongoid and Amazon DynamoDB. To select another ORM, simply require it in the initializer file.

### Amazon DynamoDB

Devise can store your models in [Amazon DynamoDB](https://aws.amazon.com/dynamodb/) using either of these libraries:

| Library | `config.dynamodb_library` | Gem |
| --- | --- | --- |
| [Dynamoid](https://github.com/Dynamoid/dynamoid) | `:dynamoid` (default) | `gem "dynamoid", "~> 3.10"` |
| [aws-record](https://github.com/aws/aws-sdk-ruby-record) | `:aws_record` | `gem "aws-record", "~> 2.13"` |

The following modules are supported: `database_authenticatable`, `rememberable`, `validatable`, `confirmable`, `trackable`, `recoverable` and `lockable`. `registerable`, `timeoutable` and `omniauthable` also work, since they need nothing more from the database; Devise's whole test suite, including these modules, runs against both libraries.

A sample application is available in [examples/dynamodb_app](examples/dynamodb_app).

#### Setup

1. Add Devise and the library you chose to your Gemfile and run `bundle install`:

   ```ruby
   gem "devise"
   gem "dynamoid" # or gem "aws-record"
   ```

2. Install Devise with the DynamoDB ORM. Pass `--dynamodb-library=aws_record` to use aws-record:

   ```console
   rails generate devise:install --orm=dynamodb
   ```

   This writes the library choice to `config/initializers/devise.rb`. The setting must come before the `require`:

   ```ruby
   config.dynamodb_library = :dynamoid
   require 'devise/orm/dynamodb'
   ```

3. Configure the library's connection as usual, in an initializer that runs before your models are loaded (for example `config/initializers/dynamodb.rb`). For DynamoDB Local in development:

   ```ruby
   # Dynamoid
   Dynamoid.configure do |config|
     config.namespace = "myapp_#{Rails.env}"
     config.endpoint = "http://localhost:8000" unless Rails.env.production?
     config.region = "us-east-1"
   end

   # aws-record
   Aws.config.update(region: "us-east-1", endpoint: "http://localhost:8000") unless Rails.env.production?
   ```

4. Generate the model. To make `rails generate devise` produce DynamoDB models, set the generator ORM in `config/application.rb` (`:dynamodb` uses `Devise.dynamodb_library`; `:dynamoid` or `:aws_record` pick a library explicitly):

   ```ruby
   config.generators.orm :dynamodb
   ```

   ```console
   rails generate devise User
   # or, without changing config.generators:
   rails generate dynamodb:devise User --library=dynamoid
   ```

   DynamoDB has no migrations, so the generator declares Devise's fields directly in the model, with the fields of optional modules commented out, as the Mongoid generator does. Uncomment the fields of the modules you enable.

5. Create the tables:

   ```console
   rails devise:dynamodb:create
   ```

#### Rake tasks

| Task | Description |
| --- | --- |
| `rails devise:dynamodb:create` | Creates the tables of all Devise DynamoDB models that do not exist yet, including their global secondary indexes. |
| `rails devise:dynamodb:status` | Lists each Devise model with its table name, whether it exists, and its global secondary indexes. |
| `rails devise:dynamodb:drop` | Drops those tables. Refuses to run in production unless `DISABLE_DATABASE_ENVIRONMENT_CHECK=1`. |

Models that share a table (subclasses, or models configured with the same table name) are handled once. Tables are created with on-demand (`PAY_PER_REQUEST`) billing for aws-record models, and with the model's `table` options (e.g. `capacity_mode: :on_demand`) for Dynamoid models. You can also manage tables yourself, for example with CloudFormation or Terraform.

#### Model requirements

* The table must have a **partition key only**, no sort (range) key. Devise looks records up by a single id (sessions, remember me cookies, `to_key`). A model with a sort key raises `Devise::Orm::Dynamodb::UnsupportedSchemaError`. The partition key does not have to be called `id`: Devise adds a read-only `id` returning it.
* New records get a random UUID partition key if none is set (string partition keys only).
* **Add a global secondary index on every attribute you authenticate with** (by default `email`), as the generator does. Devise looks users up by these attributes on sign in, password reset, confirmation, unlock and in the uniqueness validation. With an index those lookups are a Query; without one they need a full table Scan (see [Lookups](#lookups)). The index partition key must be the attribute itself, and the projection can be keys only.
* With aws-record, declare time attributes with `formatter: Devise::Orm::Dynamodb::TimeFormatter`. aws-record's default formatter drops sub-second precision, which affects remember me cookies.

#### How it maps to Active Record behaviour

The goal is for Devise to behave on DynamoDB as it does on Active Record. In particular:

* **Email uniqueness.** `:validatable` adds `validates_uniqueness_of :email, allow_blank: true, case_sensitive: true, if: :devise_will_save_change_to_email?`, exactly as on Active Record. The validator looks the email up through the email index (or a strongly consistent Scan without one), ignores the record being validated, checks the whole table (including other classes sharing it, as Active Record does for STI), and adds the same `:taken` error ("has already been taken"). It also supports `:scope`, `:message`, `:allow_nil`, `:allow_blank`, `:if` and `:unless`, and can be used in your own models (`validates_uniqueness_of :username` or `validates :username, uniqueness: true`).
* **Case-insensitive and whitespace-stripped keys** (`config.case_insensitive_keys`, `config.strip_whitespace_keys`) work as on any ORM: Devise normalizes values before saving and before looking records up.
* **Dirty tracking** used by Devise (email change notifications, password change notifications, reconfirmation, clearing the reset password token when the email or password changes) is mapped onto Dynamoid's dirty tracking, and onto an equivalent implemented by Devise for aws-record.
* **Reconfirmable race condition** ([#5783](https://github.com/heartcombo/devise/pull/5783)): `unconfirmed_email` is always written when an email change is postponed, even if its value did not change in memory.
* **Lockable** increments `failed_attempts` with an atomic DynamoDB `ADD` update, like Active Record's `increment_counter`.
* **Callbacks**: Devise's `before_create`, `after_create`, `before_update` and `after_update` callbacks run as on Mongoid. Confirmation emails are sent from `after_create`/`after_update`, since DynamoDB has no transactions to commit.
* **Partial updates**: saving a persisted record only writes the attributes that changed, and only if the item still exists: saving a record that was deleted in the meantime returns `false` (`save!` raises) instead of recreating it.
* **Single table inheritance**: subclasses of a Devise model share its table. Declare a `type` attribute on the parent (`field :type, :string` with Dynamoid, `string_attr :type` with aws-record) to record each item's class; lookups by a subclass then only return items of that subclass (or its own subclasses), and the parent sees all of them, as with Active Record STI. Items without a type are visible to every class.
* **Serialization**: `to_json`, `serializable_hash` and `inspect` hide Devise's sensitive attributes, as on the other ORMs.
* **aws-record models** get the parts of the Active Record API that Devise and its controllers rely on: ActiveModel validations and validation callbacks, `save`/`create`/`update` callbacks, `save(validate: false)`, `create`/`create!`, `update(attributes)`, `update_attribute`, `reload`, `destroy`, `persisted?`/`new_record?`, `changed?`/`changes`/`previous_changes`, `<attribute>_changed?`, `<attribute>?`, `to_key`/`to_param`, JSON serialization, equality by partition key, and automatic `created_at`/`updated_at` if those attributes are declared.

#### Lookups

DynamoDB can only find items efficiently by primary key or through an index, so the adapter plans each Devise lookup:

1. If the conditions include the partition key (or `id`), it uses a `GetItem`.
2. Otherwise, if one of the conditions is on the partition key of a global secondary index (with a non-blank string value), it Queries the index and re-reads each candidate with a strongly consistent `GetItem`. Global secondary indexes are eventually consistent: the re-read discards stale matches, but an item written a moment ago may not be in the index yet (see [Differences from Active Record](#differences-from-active-record-and-limitations)).
3. Otherwise it falls back to a strongly consistent `Scan` with a filter expression, and logs a warning the first time each model is queried by a given set of attributes:

   ```
   [Devise] User: looking up records by unlock_token requires a full table Scan. Add a global secondary index ...
   ```

Every candidate is then checked against all the conditions, so the result is the same whichever plan is used. Lookups by token (`confirmation_token`, `reset_password_token`, `unlock_token`) use a Scan unless you index those attributes too. That is fine for small tables; for large ones, add an index on the token attributes of the modules you use.

The adapter's log output goes to `Rails.logger`. You can redirect it with `Devise::Orm::Dynamodb.logger = Logger.new(...)`.

#### Differences from Active Record and limitations

These behaviours cannot be mapped 1:1 onto DynamoDB:

* **Uniqueness is not atomic.** Like `validates_uniqueness_of` on Active Record *without* a unique index, the check and the write are separate operations, so two concurrent sign ups with the same email can both succeed. In addition, global secondary indexes are eventually consistent (usually well under a second), so a lookup through the email index can miss an item written just before, which widens that window from "concurrent" to "within moments of each other". DynamoDB has no unique secondary indexes. If you need a hard guarantee, write an additional item keyed by the email (for example in a `user_emails` table) with a conditional put (`attribute_not_exists`) inside a transaction together with the user.
* **Eventually consistent index lookups.** For the same reason, signing in or requesting a password reset within moments of signing up or changing an email can fail to find the account. Lookups by id (sessions, remember me) and Scans are strongly consistent.
* **No transactions around saves.** `after_commit` callbacks do not exist; Devise sends confirmation emails from `after_create`/`after_update` (as on Mongoid), so an email can be sent even if a later callback in the same save fails.
* **`case_sensitive: false` is not supported** by the uniqueness validator (it raises `ArgumentError`). DynamoDB has no case-insensitive comparison. Use `config.case_insensitive_keys` (on by default for `email`), which stores and looks up normalized values.
* **Empty strings are stored as missing attributes.** Dynamoid does this by default (`store_empty_string_as_nil`), and the aws-record integration does the same because DynamoDB rejects empty strings in index keys. Such values read back as `nil`, and lookups treat `""` and `nil` as equal.
* **Ordering, limits and offsets** passed to `to_adapter.find_all` are applied in memory after reading all matching items. Devise itself does not use them.
* **Lookups by unindexed attributes Scan the whole table**, as described above. Scans read every item, and cost and latency grow with table size.
* **Sort (range) keys** are not supported on Devise models (see [Model requirements](#model-requirements)).
* **Subclasses without a `type` attribute** can read every item of the shared table (like Active Record STI on a table without a `type` column). Add the attribute whenever several Devise scopes map to classes sharing a table, for example `Admin < User`.
* **Lookups on undeclared attributes raise** `Devise::Orm::Dynamodb::UnknownAttributeError`, whereas Active Record raises a database error. For example, `config.request_keys = [:subdomain]` requires a `subdomain` attribute on the model.
* **Timestamps with aws-record** are kept to the microsecond only with `Devise::Orm::Dynamodb::TimeFormatter`. Dynamoid stores times as epoch numbers by default.
* **aws-record models are not full ActiveModel models.** The compatibility layer covers what Devise needs; other Active Record features (associations, scopes, `where`, `find_by`, `update_all`, ...) are not provided.

### Rails API Mode

Rails 5+ has a built-in [API Mode](https://edgeguides.rubyonrails.org/api_app.html) which optimizes Rails for use as an API (only). Devise is _somewhat_ able to handle applications that are built in this mode without additional modifications in the sense that it should not raise exceptions and the like. But some issues may still arise during `development`/`testing`, as we still don't know the full extent of this compatibility. (For more information, see [issue #4947](https://github.com/heartcombo/devise/issues/4947/))

#### Supported Authentication Strategies
API-only applications don't support browser-based authentication via cookies, which is devise's default. Yet, devise can still provide authentication out of the box in those cases with the `http_authenticatable` strategy, which uses HTTP Basic Auth and authenticates the user on each request. (For more info, see this wiki article for [How To: Use HTTP Basic Authentication](https://github.com/heartcombo/devise/wiki/How-To:-Use-HTTP-Basic-Authentication))

The devise default for HTTP Auth is disabled, so it will need to be enabled in the devise initializer for the database strategy:

```ruby
config.http_authenticatable = [:database]
```

This restriction does not limit you from implementing custom warden strategies, either in your application or via gem-based extensions for devise.
A common authentication strategy for APIs is token-based authentication. For more information on extending devise to support this type of authentication and others, see the wiki article for [Simple Token Authentication Examples and alternatives](https://github.com/heartcombo/devise/wiki/How-To:-Simple-Token-Authentication-Example#alternatives) or this blog post on [Custom authentication methods with Devise](https://blog.plataformatec.com.br/2019/01/custom-authentication-methods-with-devise/).

#### Testing
API Mode changes the order of the middleware stack, and this can cause problems for `Devise::Test::IntegrationHelpers`. This problem usually surfaces as an ```undefined method `[]=' for nil:NilClass``` error when using integration test helpers, such as `#sign_in`. The solution is simply to reorder the middlewares by adding the following to test.rb:

```ruby
Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Cookies
Rails.application.config.middleware.insert_before Warden::Manager, ActionDispatch::Session::CookieStore
```

For a deeper understanding of this, review [this issue](https://github.com/heartcombo/devise/issues/4696).

Additionally be mindful that without views supported, some email-based flows from Confirmable, Recoverable and Lockable are not supported directly at this time.

## Additional information

### Warden

Devise is based on Warden, which is a general Rack authentication framework created by Daniel Neighman. We encourage you to read more about Warden here:

https://github.com/wardencommunity/warden

## License

MIT License.
Copyright 2020-CURRENT Rafael França, Carlos Antonio da Silva.
Copyright 2009-2019 Plataformatec.

The Devise logo is licensed under [Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License](https://creativecommons.org/licenses/by-nc-nd/4.0/).
