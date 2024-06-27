### `super`

[Read this documentation in the browser](https://github.com/Shopify/ruby-lsp/blob/main/static_docs/descriptions/super.md)

The `super` keyword is used within a method to call a method of the same name in the superclass. It is useful for extending or modifying the behavior of inherited methods.

```ruby
class Animal
  def speak
    puts "Animal speaks"
  end
end

class Dog < Animal
  def speak
    super
    puts "Dog barks"
  end
end

dog = Dog.new
dog.speak
# => Animal speaks
# => Dog barks
```

[Ruby keywords](https://docs.ruby-lang.org/en/3.3/keywords_rdoc.html)
