### `def`

[Read this documentation in the browser](https://github.com/Shopify/ruby-lsp/blob/main/static_docs/def.md)

In Ruby, a method is defined using the `def` keyword. The method definition ends with the `end` keyword. A standard method definition for a method named `foo` is as follows:

```ruby
def foo
  puts "bar"
end

foo
# => bar
```

Alternatively, there is an `end`-less syntax introduced in Ruby 3.0:

```ruby
def foo = puts "bar"

foo
# => bar
```

[Read in editor](static_docs/def.md) | [Ruby keywords](https://docs.ruby-lang.org/en/3.3/keywords_rdoc.html)
