tconsole
======

tconsole is a testing console for Rails. It allows you to issue commands
concerning what tests to run, and see their test output. It's also got a
helpful reload command for when your Rails environment needs to be
restarted.

tconsole has only been tested with Rails 3 with Ruby 1.9.3 and 1.8.7 with MiniTest as the testing framework (the Rails default) on a Mac, but in theory it should work with pretty much any Unixy operating system (tconsole uses fork a good bit).

Why use tconsole?
------

* A large amount of time is wasted loading the Rails environment each time you run the Rails testing rake tasks. tconsole loads the environment when you start the console and whenever you reload the environment, but doesn't have to reload the environment for each test execution.
* The Rails rake task syntax `bundle exec rake test:units TEST=test/unit/user_test.rb` can be pretty verbose when you're running specific tests. Yeah, there are tricks you can use to shorten things up, but still, that's crazy long. tconsole lets you just type `test/unit/user_test.rb` to get that specific test file to run. I'm working on fuzzy matching, too, so that you can just type 'user' and get the user test to run.

What about Spork?
------
[Spork](https://github.com/sporkrb/spork)'s really cool, and it was my primary motivation behind writing tconsole, but I've always felt like having an extra console open for my spork server and another to run my commands is a bit heavy for what I want to do. Beyond that, I couldn't ever figure out how to get Spork to work with test/unit, and since me and DHH are the only two people who still use test/unit I figured it was up to me to come up with something that worked great. If Spork's your cup of tea, though, stop reading this and use what you like.

What about rspec?
------
I'm not sure if tconsole will ever support rspec or not. I love the idea
of adding support for rspec, but I also don't use rspec all that often,
so it likely wouldn't be very well tested. If enough people fuss at me,
or if someone were willing to add and maintain rspec support I'd definitely be
willing to merge it in, though.

Installing tconsole
------
	gem install tconsole

Prereleases of tconsole come out pretty frequently. You can install the latest prerelease version with:

	gem install tconsole --pre

How to use tconsole
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

You can go one bit deeper and just run a particular test in that file as
well:

	> UserTest#test_that_user_is_healthy

You can list more than just one class or class and method to run, and
tconsole will run them all.

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
	0.00077s PostTest#test_post_should_have_a_body

If you update your environment, maybe by editing your Gemfile or changing one of your application's configuration files, you can use the `reload` command to reload the entire environment:

	> reload

And then finally, you can run the `exit` command to quit:

	> exit

Reporting Issues and Contributing
------

Feel free to report issues in the issue tracker at https://github.com/commondream/tconsole/issues. Be sure to include the versions of Ruby, Rails, and your operating system. For bonus points, fork the project and send me a pull request with the fix for the issue you're seeing.

tconsole is just a quick idea I had that I wanted to spike out, so there aren't any tests yet. Hopefully that will change in the near future!

License
-----
Copyright (c) 2012 Alan Johnson

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
