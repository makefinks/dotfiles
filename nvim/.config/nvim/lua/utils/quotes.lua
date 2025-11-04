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
}

function M.get_quote()
  local index = math.random(#quotes)
  return quotes[index]
end

return M
