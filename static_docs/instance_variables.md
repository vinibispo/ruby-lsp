# Instance variables

Instance variables are Ruby's way of assigning data to a specific object. For example, if we have a class `Person` to
model people, it could contain as part of its data the person's name and age. Those are a good use case for instance
variables.

All instance variables are prefix with a single `@` symbol. These variables are accessible to all methods that belong to
the same instance (in our example, to all `Person` objects).

```ruby
class Person
  def initialize(name, age)
    @name = name
    @age = age
  end
end
```
