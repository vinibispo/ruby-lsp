### `retry`

[Read this documentation in the browser](https://github.com/Shopify/ruby-lsp/blob/main/static_docs/descriptions/retry.md)

The `retry` keyword is used to retry a `begin` block from the start if an exception occurs.

```ruby
begin
  puts 'Trying...'
  raise 'Oops!'
rescue
  puts 'Retrying...'
  retry
end
```

[Ruby keywords](https://docs.ruby-lang.org/en/3.3/keywords_rdoc.html)
