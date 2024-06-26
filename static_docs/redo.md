### `redo`

[Read this documentation in the browser](https://github.com/Shopify/ruby-lsp/blob/main/static_docs/redo.md)

The `redo` keyword is used to restart the current iteration of a loop without reevaluating the loop condition.

```ruby
i = 0
for i in 0..5
  if i < 2
    puts "i is #{i}"
    i += 1
    redo
  end
end
```

[Read in editor](static_docs/redo.md) | [Ruby keywords](https://docs.ruby-lang.org/en/3.3/keywords_rdoc.html)
