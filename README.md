## I'm no longer maintaining TConsole. If you're interested in maintaing the project, email me and let me know.

TConsole
======

TConsole is a testing console for Rails. It allows you to issue commands
concerning what tests to run, and see their test output. It's also got a
helpful reload command for when your Rails environment needs to be
restarted.

TConsole should work in pretty much any Unix environment and will work with apps running Ruby 1.9. It can be run on pretty much any test suite that uses MiniTest, including Rails test suites.

See it in Action
------
There's a quick screencast on Vimeo about TConsole's basic features: [Meet TConsole!](https://vimeo.com/37641415)

Why use TConsole?
------

* A large amount of time is wasted loading the Rails environment each time you run the Rails testing rake tasks. TConsole loads the environment when you start the console and whenever you reload the environment, but doesn't have to reload the environment for each test execution.
* The Rails rake task syntax `bundle exec rake test:units TEST=test/unit/user_test.rb` can be pretty verbose when you're running specific tests. Yeah, there are tricks you can use to shorten things up, but still, that's crazy long. tconsole lets you just type `test/unit/user_test.rb` to get that specific test file to run. With TConsole  you can just type `UserTest` and the test runs!
* TConsole makes it dead simple to review how long your tests are taking to run and pinpoint your slowest running tests.
* Re-running failed tests is as easy as typing `!failed` with TConsole.

What about Spork?
------
[Spork](https://github.com/sporkrb/spork)'s really cool, and it was my primary motivation behind writing tconsole, but I've always felt like having an extra console open for my spork server and another to run my commands is a bit heavy for what I want to do. Beyond that, I couldn't ever figure out how to get Spork to work with test/unit, and since me and DHH are the only two people who still use test/unit I figured it was up to me to come up with something that worked great. If Spork's your cup of tea, though, stop reading this and use what you like.

What about rspec?
------
We've decided to focus on integrating with MiniTest as tightly as possible, rather than worrying about rspec support.

Installing TConsole
------
    gem install tconsole

Prereleases of TConsole come out pretty frequently. You can install the latest prerelease version with:

    gem install tconsole --pre
    
If you're using bundler, you probably want to simply add TConsole to your Gemfile:

    gem "tconsole"

How to use TConsole
------
In your shell of choice, cd into your Rails project's directory and then run `bundle exec tconsole` to fire up the console. You should see something like this:

	bundle exec tconsole

	Loading your Rails environment...
	Environment loaded in 7.160264s.

	>

Now that you're in the console, let's test out the `all` command! Running `all` from the console runs all of your unit, functional, and integration tests:

	> all
	Running tests...

	Run options:

	# Running tests:

	....................................................................................

	Finished tests in 6.054574s, 6.4999 tests/s, 10.5822 assertions/s.

	39 tests, 45 assertions, 0 failures, 0 errors, 0 skips

	Test time (including load): 82.806741s

	>

If you want to focus in on a particular subset of your tests, like units, functionals, or integration, just enter that keyword:

    > units

    > functionals

    > integration

You can also specify to run all tests in a specific class:

    > UserTest

You can dig a bit deeper and just run a particular test in that file as
well:

    > UserTest#test_that_user_is_healthy

You can list more than just one class or class and method to run, and
TConsole will run them all.

    > UserTest InvoiceTest SubscriptionTest#test_that_renew_renews_the_subscription

There are a few special ! commands that use data from past test runs. The `!failed` command will rerun the set of tests that failed during the last run:

	> !failed

There's also a `!timings` command that will show you a listing of your last test run's test times, sorted to help you
improve slow tests:

	> !timings

	Timings from last run:

	0.042632s PostTest#test_new_post_should_not_be_published
	0.033892s PostTest#test_post_should_have_a_title
	0.033134s PostsControllerTest#test_can_reach_all_posts
	0.007098s PostsControllerTest#test_grabs_posts
	0.006212s PostsControllerTest#test_displays_published_posts_by_default
	0.006107s PostTest#test_post_cannot_have_an_empty_body
	0.002197s PostTest#test_post_should_have_a_publish_date_set_when_published
	0.001937s PostTest#test_post_cannot_have_an_empty_title
	0.001232s PostTest#test_post_should_have_an_initial_state
	0.001128s PostTest#test_post's_state_should_change_when_published
	0.001056s PostTest#test_returning_only_published_posts
	0.000923s PostTest#test_post_should_have_respond_to_published_appropriately
	0.000770s PostTest#test_post_should_have_a_body

You can turn on the Fail Fast feature to cause TConsole to stop running
tests as soon as the first test fails. To enable fail fast simply enter:

  > set fast on

In the console. You can disable Fail Fast again with:

  > set fast off

If you update your environment, maybe by editing your Gemfile or changing one of your application's configuration files, you can use the `reload` command to reload the entire environment:

	> reload

And then finally, you can run the `exit` command to quit:

	> exit

Command Line Options
-----

Since TConsole is primarily meant to be run as an interactive console, it
doesn't have many command line arguments, but there are a few.
TConsole also passes any parameters that it doesn't know through to be
run as its initial command. So, for example:

```
> tconsole all
```

passes `all` through as the first command to be run, so that command
would start TConsole and immediately run all tests. There's a `--once`
option that can be used if you'd simply like to run a single command by
passing it to the TConsole command in then exit.

The only other TConsole command line option is `--trace`. `--trace` is
primarily useful for diagnosing problems with TConsole.


Configuration Files
------

TConsole attempts to load a .tconsole file in your home directory
and in your project directory, in that order, to configure your preferred defaults for TConsole. In many situations you won't need to edit your TConsole configuration files to run TConsole, because it includes a sane set of defaults and attempts to auto-detect Rails applications. 

Here's a commented example configuration file:

``` ruby
TConsole::Config.run do |config|
  # Configures the directory where your tests are located
  config.test_dir = "./test"

  # Include paths that should be added to Ruby's load path
  config.include_paths = ["./test", "./lib"]

  # Paths that should be preloaded. You'll have to run the reload
  # command to reload these paths in TConsole
  config.preload_paths = ["./config/application"]

  # File sets are the named sets of files that can be executed. A file
  # set named "all" must be included.
  config.file_sets = {
    "all" => ["test/**/*_test.rb"],
    "units" => ["test/units/**/*_test.rb"]
  }

  # Fail fast specifies whether or not tests should stop executing once
  # the first failure occurs.
  config.fail_fast = true

  # Specifies code to be run before loading the environment
  config.before_load do
    ENV["RAILS_ENV"] ||= "test"
  end

  # Specifies code to be run after loading the environment
  config.after_load do
    ::Rails.application
    ::Rails::Engine.class_eval do
      def eager_load!
        # turn off eager_loading
      end
    end
  end

  # Specifies code to be run before each test execution
  config.before_test_run do
    puts "I'm about to run!!!"
  end
end
```


Reporting Issues and Contributing
------

Feel free to report issues in the issue tracker at https://github.com/commondream/tconsole/issues. Be sure to include the versions of Ruby, Rails, and your operating system. For bonus points, fork the project and send me a pull request with the fix for the issue you're seeing.

*How embarrassing?!?! A testing tool with no tests?* At first TConsole was just a bit of experimental code, so test coverage is light. I am working on improving that, though.

License
-----
Copyright (c) 2012 Alan Johnson

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
