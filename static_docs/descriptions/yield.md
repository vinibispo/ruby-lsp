# Yield

[Read this documentation in the browser](https://github.com/Shopify/ruby-lsp/blob/main/static_docs/descriptions/yield.md)

In Ruby, any method implicitly accepts a block, even if not included in the argument list. The `yield` keyword invokes the block that was passed as part of the method invocation.

```ruby
def foo
  # Invoke whatever block was passed to the method `foo`
  yield
end

foo { puts "Hello from yield!" }
# => Hello from yield!

Note that invoking `foo` without a block will result in an error: `no block given (yield) (LocalJumpError)`. To use the `yield` keyword conditionally, you can check if a block was given using the `block_given?` method, which returns `true` or `false`.

def foo
  if block_given?
    yield
  else
    puts "No block!"
  end
end

foo { puts "Hello from yield!" }
# => Hello from yield!
foo
# => No block!
```

[Read about methods](static_docs/def.md)
