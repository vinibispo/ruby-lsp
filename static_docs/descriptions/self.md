### `self`

[Read this documentation in the browser](https://github.com/Shopify/ruby-lsp/blob/main/static_docs/self.md)

The `self` keyword within a method refers to the instance of the class for which the method is called. It is used to access instance variables and methods.

```ruby
class Person
  attr_accessor :name

  def initialize(name)
    self.name = name
  end

  def display_name
    puts "Name is #{self.name}"
  end
end

person = Person.new("Alice")
person.display_name
# => Name is Alice
```

[Read in editor](static_docs/self.md) | [Ruby keywords](https://docs.ruby-lang.org/en/3.3/keywords_rdoc.html)
