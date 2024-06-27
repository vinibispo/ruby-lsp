### `module`

[Read this documentation in the browser](https://github.com/Shopify/ruby-lsp/blob/main/static_docs/module.md)

The `module` keyword is used to define a module, which is a collection of methods and constants. They are usually mixed into classes.

```ruby
module Bar
  def baz
    puts "Hello"
  end
end

class Foo
  include Bar
end

Foo.new.baz
# => Hello
```

Modules are commonly nested as a means of namespacing classes.

```ruby
module Assessment
  module Examination
    # Methods defined here
  end

  module Grade
    # Methods defined here
  end
end
```

[Read in editor](static_docs/module.md) | [Ruby keywords](https://docs.ruby-lang.org/en/3.3/keywords_rdoc.html)
