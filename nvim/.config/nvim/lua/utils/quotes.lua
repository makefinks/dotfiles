local M = {}

-- Seed randomness once on load
math.randomseed(os.time())

local quotes = {
	{
		author = "Donald Knuth",
		text = "Premature optimization is the root of all evil.",
	},
	{
		author = "Edsger Dijkstra",
		text = "Simplicity is prerequisite for reliability.",
	},
	{
		author = "Brian Kernighan",
		text = "Debugging is twice as hard as writing the code in the first place.",
	},
	{
		author = "C.A.R. Hoare",
		text = "There are two ways to write error-free programs; only the third one works.",
	},
	{
		author = "Alan Kay",
		text = "The best way to predict the future is to invent it.",
	},
	{
		author = "Linus Torvalds",
		text = "Talk is cheap. Show me the code.",
	},
	{
		author = "Grace Hopper",
		text = "A ship in port is safe, but that is not what a ship is for.",
	},
	{
		author = "Ken Thompson",
		text = "One of my most productive days was throwing away 1000 lines of code.",
	},
	{
		author = "Fred Brooks",
		text = "There is no silver bullet.",
	},
	{
		author = "Martin Fowler",
		text = "Any fool can write code that a computer can understand. Good programmers write code that humans can understand.",
	},
	{
		author = "Robert C. Martin",
		text = "The only way to make the deadline is to go fast, and the only way to go fast is to go well.",
	},
	{
		author = "Alan Perlis",
		text = "A language that doesn't affect the way you think about programming is not worth knowing.",
	},
	{
		author = "Anonymous",
		text = "99 little bugs in the code, 99 bugs in the code. Take one down, patch it around, 127 little bugs in the code.",
	},
	{
		author = "Bill Gates",
		text = "Measuring programming progress by lines of code is like measuring aircraft building progress by weight.",
	},
	{
		author = "Larry Wall",
		text = "The three chief virtues of a programmer are: Laziness, Impatience and Hubris.",
	},
	{
		author = "Bjarne Stroustrup",
		text = "There are only two kinds of languages: the ones people complain about and the ones nobody uses.",
	},
	{
		author = "Douglas Adams",
		text = "I love deadlines. I like the whooshing sound they make as they fly by.",
	},
	{
		author = "Gerald Weinberg",
		text = "If builders built buildings the way programmers wrote programs, then the first woodpecker that came along would destroy civilization.",
	},
	{
		author = "Harold Abelson & Gerald Jay Sussman",
		text = "Programs must be written for people to read, and only incidentally for machines to execute.",
	},
	{ author = "Kent Beck", text = "Make it work, make it right, make it fast." },
	{
		author = "Phil Karlton",
		text = "There are only two hard things in Computer Science: cache invalidation and naming things.",
	},
	{
		author = "David Wheeler",
		text = "Any problem in computer science can be solved by another level of indirection.",
	},
	{ author = "Kevlin Henney", text = "Except for the problem of too many layers of indirection." },
	{
		author = "Michael A. Jackson",
		text = "Rule 1 of optimization: Don't do it. Rule 2 (for experts only): Don't do it yet.",
	},
	{ author = "Richard Hamming", text = "The purpose of computing is insight, not numbers." },
	{
		author = "C.A.R. Hoare",
		text = "There are two ways of constructing a software design: make it so simple that there are obviously no deficiencies, or so complicated that there are no obvious deficiencies.",
	},
	{
		author = "Brian Kernighan",
		text = "The most effective debugging tool is careful thought, coupled with judiciously placed print statements.",
	},
	{
		author = "Donald Knuth",
		text = "Beware of bugs in the above code; I have only proved it correct, not tried it.",
	},
	{
		author = "Edsger Dijkstra",
		text = "Program testing can be used to show the presence of bugs, but never to show their absence!",
	},
	{
		author = "Edsger Dijkstra",
		text = "The computing scientist's main challenge is not to get confused by the complexities of his own making.",
	},
	{
		author = "Alan Perlis",
		text = "It is better to have 100 functions operate on one data structure than 10 functions on 10 data structures.",
	},
	{ author = "Alan Perlis", text = "Syntactic sugar causes cancer of the semicolon." },
	{
		author = "Alan Perlis",
		text = "Beware of the Turing tar-pit in which everything is possible but nothing of interest is easy.",
	},
	{ author = "Jeff Atwood", text = "The best code is no code at all." },
	{ author = "Jeff Sickel", text = "Deleted code is debugged code." },
	{ author = "Ward Cunningham", text = "The simplest thing that could possibly work." },
	{ author = "Robert C. Martin", text = "It is not enough for code to work." },
	{ author = "Robert C. Martin", text = "Don't comment bad code—rewrite it." },
	{ author = "Robert C. Martin", text = "Leave the campground cleaner than you found it." },
	{ author = "Rob Pike", text = "Measure. Don't tune for speed until you've measured, and even then don't." },
	{ author = "Rob Pike", text = "The bigger the interface, the weaker the abstraction." },
	{ author = "John Ousterhout", text = "A little copying is better than a little dependency." },
	{ author = "John Ousterhout", text = "Make simple things easy, and hard things possible." },
	{ author = "Niklaus Wirth", text = "Algorithms + Data Structures = Programs." },
	{
		author = "Alan Turing",
		text = "We can only see a short distance ahead, but we can see plenty there that needs to be done.",
	},
	{ author = "Guido van Rossum", text = "Code is read much more often than it is written." },
	{ author = "Tim Peters (The Zen of Python)", text = "Explicit is better than implicit." },
	{ author = "Sandi Metz", text = "Duplication is far cheaper than the wrong abstraction." },
	{ author = "L. Peter Deutsch", text = "To iterate is human, to recurse divine." },
	{ author = "Jon Postel", text = "Be conservative in what you send, and liberal in what you accept." },
	{
		author = "Gordon Bell",
		text = "The cheapest, fastest, and most reliable components are those that aren't there.",
	},
	{ author = "Tony Hoare", text = "I call it my billion-dollar mistake." },
	{
		author = "Douglas Hofstadter",
		text = "It always takes longer than you expect, even when you take into account Hofstadter's Law.",
	},
	{ author = "Kent Beck", text = "Optimism is an occupational hazard of programming. Feedback is the treatment." },
	{ author = "Grady Booch", text = "The function of good software is to make the complex appear to be simple." },
	{ author = "Thomas Fuchs", text = "The best error message is the one that never shows up." },
	{ author = "Josh Bloch", text = "A good API is easy to use and hard to misuse." },
	{ author = "Jez Humble & David Farley", text = "If it hurts, do it more often, and bring the pain forward." },
	{ author = "Melvin Conway", text = "Organizations design systems that mirror their communication structures." },
	{
		author = "Patrick McKenzie",
		text = "Every great developer you know got there by solving problems they were unqualified to solve until they actually did it.",
	},
	{
		author = "Linus Torvalds",
		text = "Bad programmers worry about the code. Good programmers worry about data structures and their relationships.",
	},
	{ author = "Brendan Eich", text = "Always bet on JavaScript." },
	{ author = "Dan McKinley", text = "Choose boring technology." },
	{
		author = "Hyrum Wright",
		text = "With a sufficient number of users of an API, all observable behaviors will be depended on by somebody.",
	},
	{
		author = "John Gall",
		text = "A complex system that works is invariably found to have evolved from a simple system that worked.",
	},
	{ author = "Eric S. Raymond", text = "Release early, release often." },
	{ author = "Kent Beck", text = "Make the change easy, then make the easy change." },
	{ author = "Michael Feathers", text = "Legacy code is code without tests." },
	{ author = "Chris Pine", text = "Programming isn't about what you know; it's about what you can figure out." },
	{ author = "Rich Hickey", text = "Simple is not easy." },
	{
		author = "Donald Knuth",
		text = "Science is what we understand well enough to explain to a computer. Art is everything else we do.",
	},
	{ author = "Ward Cunningham", text = "It's all talk until the code runs." },
	{ author = "Ken Thompson", text = "When in doubt, use brute force." },
	{
		author = "Antoine de Saint-Exupéry",
		text = "Perfection is achieved not when there is nothing more to add, but when there is nothing left to take away.",
	},
	{ author = "Peter Naur", text = "Programming is theory building, not just code building." },
	{ author = "Tony Hoare", text = "Inside every large program is a small program trying to get out." },
	{ author = "Ellen Ullman", text = "All software is political." },
	{ author = "Ralph Johnson", text = "Before software can be reusable it first has to be usable." },
	{ author = "Jason Fried", text = "Start making something small, then make it better." },
	{ author = "Steve McConnell", text = "Good code is its own best documentation." },
	{ author = "Yaron Minsky", text = "Make illegal states unrepresentable." },
	{
		author = "Reid Hoffman",
		text = "If you are not embarrassed by the first version of your product, you've launched too late.",
	},
	{ author = "Unknown", text = "Real programmers count from zero." },
	{ author = "Unknown", text = "Weeks of coding can save you hours of planning." },
	{ author = "Unknown", text = "It works on my machine." },
	{ author = "Unknown", text = "Fix the cause, not the symptom." },
	{ author = "Unknown", text = "Tests are the most honest form of documentation." },
	{ author = "Unknown", text = "Move fast, don’t break your users." },
	{
		author = "Harold Abelson",
		text = "No matter how slow you are, you are still executing faster than the computer can guess your intent.",
	},
	{
		author = "Tony Hoare",
		text = "Premature optimization is the root of all evil — except in real time systems.",
	},
	{ author = "Peter van der Linden", text = "The sooner you start to code, the longer the program will take." },
	{ author = "Mark Zuckerberg", text = "Move fast and break things." },
	{
		author = "Donald Knuth",
		text = "People who are more than casually interested in computers should have at least some idea of what the compiler is doing.",
	},
	{ author = "Brian Kernighan", text = "Controlling complexity is the essence of computer programming." },
	{
		author = "Dennis Ritchie",
		text = "UNIX is basically a simple operating system, but you have to be a genius to understand the simplicity.",
	},
	{
		author = "Andrew S. Tanenbaum",
		text = "The nice thing about standards is that you have so many to choose from.",
	},
	{ author = "Ben Fried", text = "If you automate a mess, you get an automated mess." },
	{ author = "George E. P. Box", text = "All models are wrong, but some are useful." },
	{ author = "Donald Reinertsen", text = "If you only quantify one thing, quantify the cost of delay." },
	{
		author = "Gene Spafford",
		text = "The only truly secure system is one that is powered off and locked in a safe— and even then I have my doubts.",
	},
	{
		author = "Tom DeMarco",
		text = "The purpose of a team is not to ensure everyone is busy; it is to ensure value is delivered.",
	},
	{ author = "Niels Bohr", text = "Prediction is very difficult, especially about the future." },
	{
		author = "Peter Drucker",
		text = "There is nothing so useless as doing efficiently that which should not be done at all.",
	},
	{ author = "Bertrand Meyer", text = "Software is our craft." },
	{
		author = "Michael A. Jackson",
		text = "The first law of program evolution: if a program is useful, it will have to be changed.",
	},
	{
		author = "Donald Knuth",
		text = "Programming is the art of telling another human what one wants the computer to do.",
	},
	{
		author = "Edsger Dijkstra",
		text = "Elegance is not a dispensable luxury, but a quality that decides between success and failure.",
	},
	{ author = "Alan Kay", text = "Simple things should be simple, complex things should be possible." },
	{
		author = "John Carmack",
		text = "Sometimes, the elegant implementation is just a function. Not a method. Not a class. Not a framework. Just a function.",
	},
	{ author = "Kevlin Henney", text = "There is no code faster than no code." },
	{ author = "Kevlin Henney", text = "The best time to delete code is before you write it." },
	{ author = "Tim Peters", text = "Beautiful is better than ugly.", source = "https://peps.python.org/pep-0020/" },
	{ author = "Tim Peters", text = "Simple is better than complex.", source = "https://peps.python.org/pep-0020/" },
	{
		author = "Tim Peters",
		text = "Complex is better than complicated.",
		source = "https://peps.python.org/pep-0020/",
	},
	{ author = "Tim Peters", text = "Flat is better than nested.", source = "https://peps.python.org/pep-0020/" },
	{ author = "Tim Peters", text = "Sparse is better than dense.", source = "https://peps.python.org/pep-0020/" },
	{ author = "Tim Peters", text = "Readability counts.", source = "https://peps.python.org/pep-0020/" },
	{
		author = "Tim Peters",
		text = "Special cases aren't special enough to break the rules.",
		source = "https://peps.python.org/pep-0020/",
	},
	{
		author = "Tim Peters",
		text = "Although practicality beats purity.",
		source = "https://peps.python.org/pep-0020/",
	},
	{
		author = "Tim Peters",
		text = "Errors should never pass silently.",
		source = "https://peps.python.org/pep-0020/",
	},
	{ author = "Tim Peters", text = "Unless explicitly silenced.", source = "https://peps.python.org/pep-0020/" },
	{
		author = "Tim Peters",
		text = "In the face of ambiguity, refuse the temptation to guess.",
		source = "https://peps.python.org/pep-0020/",
	},
	{
		author = "Tim Peters",
		text = "There should be one-- and preferably only one --obvious way to do it.",
		source = "https://peps.python.org/pep-0020/",
	},
	{
		author = "Tim Peters",
		text = "Although that way may not be obvious at first unless you're Dutch.",
		source = "https://peps.python.org/pep-0020/",
	},
	{ author = "Tim Peters", text = "Now is better than never.", source = "https://peps.python.org/pep-0020/" },
	{
		author = "Tim Peters",
		text = "Although never is often better than *right* now.",
		source = "https://peps.python.org/pep-0020/",
	},
	{
		author = "Tim Peters",
		text = "If the implementation is hard to explain, it's a bad idea.",
		source = "https://peps.python.org/pep-0020/",
	},
	{
		author = "Tim Peters",
		text = "If the implementation is easy to explain, it may be a good idea.",
		source = "https://peps.python.org/pep-0020/",
	},
	{
		author = "Tim Peters",
		text = "Namespaces are one honking great idea -- let's do more of those!",
		source = "https://peps.python.org/pep-0020/",
	},
	{
		author = "Kyzer Davis",
		text = "With networking, much like programming, numbering SHOULD always start with zero.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "It Has To Work.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "No matter how hard you push and no matter what the priority, you can't increase the speed of light. You can, however, slow it down.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "No matter how hard you try, you can't make a baby in much less than 9 months. Trying to speed this up *might* make it slower, but it won't make it happen any quicker.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "With sufficient thrust, pigs fly just fine. However, this is not necessarily a good idea.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Some things in life can never be fully appreciated nor understood unless experienced firsthand.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "It is always possible to agglutinate multiple separate problems into a single complex interdependent solution. In most cases this is a bad idea.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "It is easier to move a problem around than it is to solve it.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "It is always possible to add another level of indirection.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "It is always something.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Good, Fast, Cheap: Pick any two (you can't have all three).",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "It is more complicated than you think.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "For all resources, whatever it is, you need more.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Every information technology problem always takes longer to solve than it seems like it should.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "One size never fits all.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Every old idea will be proposed again with a different name and a different presentation, regardless of whether it works.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "In protocol design, perfection has been reached not when there is nothing left to add, but when there is nothing left to take away.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "The network is at fault until proven innocent.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Automation is encouraged and oftentimes recommended. (even at times when it shouldn't be.)",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Never make a change unless you know the impact or ramifications of said change.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Never test in production.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Layer 8 of the Open Systems Interconnection (OSI) model is People.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Layer 9 of the Open Systems Interconnection (OSI) model is company/external regulations, rules, and restrictions.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Layer 10 of the Open Systems Interconnection (OSI) model is money, budget, and funds.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Reserved for Catch-22s.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "If it can break, it will break, unexpectedly, on a weekend/holiday.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Fail-over and high availability are not suggestions. Remember to test regularly!",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Change or version control are not a suggestion.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "You will get no praise when everything is working. Expect to only be needed when things break.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Cloud simply means somebody else's data center/network.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "When things don't work, escalate harder.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Never assume any software is free of bugs/defects.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "IPv6 should replace IPv4 any day now.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "There can always be more people on the conference call.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "TIAAA (There Is Always Another Acronym).",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "There is no such thing as a random issue.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Trust but verify should be the approach to any situation.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "The packets don't lie.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Wireless might as well be magic.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Nothing is ever truly 100% secure.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Everybody's title is made up.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "One of the hardest parts of any IT professional's day is the process of copying a file from a client to a server.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Documentation, while REQUIRED, is never complete or up-to-date.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "A minimum of two data points should be collected in order to properly point the finger.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "It is very likely somebody has always thought of it before you.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Fear of the unknown oftentimes supersedes common sense.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Your microphone behaves much like Schrodinger's cat.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Sometimes a device needs a reload and there SHOULD be no further justification beyond that fact required.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "The best engineers know how to properly discern the false debug errors from the real debug errors.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "The link you saved will change, break, or go away.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Somewhere, right now, a group of individuals are arguing about a SHOULD vs a MUST.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "You never know when you will need that cable. Better hold onto it.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "In IT the number of monitors directly correlates to efficiency.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "Kyzer Davis",
		text = "Your solution is likely way more complicated than required.",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{ author = "Kyzer Davis", text = "Experimental.", source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html" },
	{
		author = "Kyzer Davis",
		text = "Reserved for Future Use (but will likely never be used.)",
		source = "https://www.ietf.org/archive/id/draft-davis-dispatch-the-truths-of-it-00.html",
	},
	{
		author = "J. Snijders et al.",
		text = "Authors MUST NOT implement bugs.",
		source = "https://datatracker.ietf.org/doc/html/rfc9225",
	},
	{
		author = "J. Snijders et al.",
		text = "If bugs are introduced in code, they MUST be clearly documented.",
		source = "https://datatracker.ietf.org/doc/html/rfc9225",
	},
	{
		author = "J. Snijders et al.",
		text = "When implementing specifications that are broken by design, it is RECOMMENDED to aggregate multiple smaller bugs into one larger bug.",
		source = "https://datatracker.ietf.org/doc/html/rfc9225",
	},
	{
		author = "J. Snijders et al.",
		text = "The aphorism \"It's not a bug, it's a feature\" is considered rude.",
		source = "https://datatracker.ietf.org/doc/html/rfc9225",
	},
	{
		author = "J. Snijders et al.",
		text = "Assume all external input is the result of bugs.",
		source = "https://datatracker.ietf.org/doc/html/rfc9225",
	},
	{
		author = "J. Snijders et al.",
		text = "In fact, assume all internal inputs also are the result of bugs.",
		source = "https://datatracker.ietf.org/doc/html/rfc9225",
	},
	{
		author = "J. Snijders et al.",
		text = "Implementers MUST NOT introduce bugs when writing software.",
		source = "https://datatracker.ietf.org/doc/html/rfc9225",
	},
	{
		author = "J. Snijders et al.",
		text = "Unexpected results caused by bugs are not a valid substitute for high-quality random number generators.",
		source = "https://datatracker.ietf.org/doc/html/rfc9225",
	},
	{
		author = "J. Snijders et al.",
		text = "Unsupervised study of the Digest archive may induce a sense of panic.",
		source = "https://datatracker.ietf.org/doc/html/rfc9225",
	},
	{
		author = "Rob Pike",
		text = "Don't communicate by sharing memory, share memory by communicating.",
		source = "https://go-proverbs.github.io/",
	},
	{ author = "Rob Pike", text = "Concurrency is not parallelism.", source = "https://go-proverbs.github.io/" },
	{
		author = "Rob Pike",
		text = "Channels orchestrate; mutexes serialize.",
		source = "https://go-proverbs.github.io/",
	},
	{ author = "Rob Pike", text = "Make the zero value useful.", source = "https://go-proverbs.github.io/" },
	{ author = "Rob Pike", text = "interface{} says nothing.", source = "https://go-proverbs.github.io/" },
	{
		author = "Rob Pike",
		text = "Gofmt's style is no one's favorite, yet gofmt is everyone's favorite.",
		source = "https://go-proverbs.github.io/",
	},
	{
		author = "Rob Pike",
		text = "Syscall must always be guarded with build tags.",
		source = "https://go-proverbs.github.io/",
	},
	{
		author = "Rob Pike",
		text = "Cgo must always be guarded with build tags.",
		source = "https://go-proverbs.github.io/",
	},
	{ author = "Rob Pike", text = "Cgo is not Go.", source = "https://go-proverbs.github.io/" },
	{
		author = "Rob Pike",
		text = "With the unsafe package there are no guarantees.",
		source = "https://go-proverbs.github.io/",
	},
	{ author = "Rob Pike", text = "Clear is better than clever.", source = "https://go-proverbs.github.io/" },
	{ author = "Rob Pike", text = "Reflection is never clear.", source = "https://go-proverbs.github.io/" },
	{ author = "Rob Pike", text = "Errors are values.", source = "https://go-proverbs.github.io/" },
	{
		author = "Rob Pike",
		text = "Don't just check errors, handle them gracefully.",
		source = "https://go-proverbs.github.io/",
	},
	{
		author = "Rob Pike",
		text = "Design the architecture, name the components, document the details.",
		source = "https://go-proverbs.github.io/",
	},
	{ author = "Rob Pike", text = "Documentation is for users.", source = "https://go-proverbs.github.io/" },
	{ author = "Rob Pike", text = "Don't panic.", source = "https://go-proverbs.github.io/" },
}

local current_index = math.random(#quotes)

local function random_index(excluding)
	if #quotes <= 1 then
		return 1
	end

	local index = math.random(#quotes - 1)
	if excluding and index >= excluding then
		index = index + 1
	end
	return index
end

function M.get_quote()
	current_index = random_index()
	return quotes[current_index]
end

function M.random_quote()
	current_index = random_index(current_index)
	return quotes[current_index]
end

function M.cycle_quote()
	current_index = current_index + 1
	if current_index > #quotes then
		current_index = 1
	end
	return quotes[current_index]
end

function M.get_current_quote()
	return quotes[current_index]
end

return M
