tconsole
======

tconsole is a testing console for Rails. It allows you to issue commands
concerning what tests to run, and see their test output. It's also got a
helpful reload command for when your Rails environment needs to be
restarted.

tconsole has only been tested with Rails 3 with Ruby 1.9.3 with MiniTest as the testing framework (the Rails default) on a Mac. This is super mega alpha at this point, so your mileage may vary. I'd love to hear how it works for you, though!

Why use tconsole?
------

* A large amount of time is wasted loading the Rails environment each time you run the Rails testing rake tasks. tconsole loads the environment when you start the console and whenever you reload the environment, but doesn't have to reload the environment for each test execution.
* The Rails rake task syntax `bundle exec rake test:units TEST=test/unit/user_test.rb` can be pretty verbose when you're running specific tests. Yeah, there are tricks you can use to shorten things up, but still, that's crazy long. tconsole lets you just type `test/unit/user_test.rb` to get that specific test file to run. I'm working on fuzzy matching, too, so that you can just type 'user' and get the user test to run.

What about Spork?
------
Spork's really cool, but I've always felt like using DRb and having extra consoles open feels a bit heavy for what I want to do. Beyond that, I couldn't ever figure out how to get Spork to work with test/unit, and since me and DHH are the only two people who still use test/unit someone's got to carry the torch for test/unit awesomeness. Really, though, if Spork's your cup of tea, stop reading this and use what you like.

Installing tconsole
------
	gem install tconsole --pre

How to use tconsole
------
In your shell of choice, cd into your Rails project's directory and then run the `tconsole` command to fire up the console. You should see something like this:

	tconsole
	
	Loading your Rails environment...
	Environment loaded in 7.160264s.
	
	> 
	
Now that you're in the console, let's test out the all command! Running all from the console runs all of your unit, functional, and integration tests:

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
         
You can also focus in on just the tests in a given filename by entering a test file name into tconsole:

	> test/unit/user_test.rb
	
If you update your environment, maybe by editing your Gemfile or changing one of your application's configuration files, you can use the `reload` command to reload the entire environment:

	> reload
	
And then finally, you can run the `exit` command to quit:

	> exit
	
Reporting Issues and Contributing
------

Feel free to report issues in the issue tracker at https://github.com/commondream/tconsole/issues. For bonus points, fork the project and send me a pull request with the fix for the issue you're seeing.

tconsole is just a quick idea I had that I wanted to spike out, so there aren't any tests yet. Hopefully that will change in the near future!
