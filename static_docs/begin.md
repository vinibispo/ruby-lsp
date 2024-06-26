### `begin`

[Read this documentation in the browser](https://github.com/Shopify/ruby-lsp/blob/main/static_docs/begin.md)

The `begin` keyword is used to start a block of code that can handle exceptions. It is typically used with `rescue`, `ensure`, and `end` keywords to define exception handling and cleanup code.

```ruby
begin
  result = 10 / 0
rescue ZeroDivisionError
  puts "Can't divide by zero!"
ensure
  puts "This will always execute."
end
```

[Read in editor](static_docs/begin.md) | [Ruby keywords](https://docs.ruby-lang.org/en/3.3/keywords_rdoc.html)
