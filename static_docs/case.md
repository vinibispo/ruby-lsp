### `case`

[Read this documentation in the browser](https://github.com/Shopify/ruby-lsp/blob/main/static_docs/case.md)

The `case` keyword is used to execute a block of code based on the value of a variable. It provides a more elegant way to handle multiple conditions compared to multiple `if` statements.

```ruby
day = "Saturday"
case day
when "Monday"
  puts "Start of the work week."
when "Saturday", "Sunday"
  puts "It's the weekend!"
else
  puts "It's a regular weekday."
end
```

[Read in editor](static_docs/case.md) | [Ruby keywords](https://docs.ruby-lang.org/en/3.3/keywords_rdoc.html)
