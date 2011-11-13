# Rough, kinda-almost-working draft

Editing javascript within HTML is annoying. Solution:

``` html
<script type="text/javascript">
  $(document).ready(function() {
    $('#foo').click(function() {
      alert('OK');
    });
  })
</script>
```

Execute `:InlineEdit` within the script tag. A proxy buffer is opened with *only* the javascript. Saving the proxy buffer updates the original one. You can reindent, lint, slice and dice as much as you like.

Same thing for sql within ruby:

``` ruby
def some_heavy_query
  execute <<-SQL
    select * from users where something = 'other';
  SQL
end
```

Same thing for code within markdown blocks.

<pre>
Some text.

``` ruby
def foo
  puts "OK"
end
```

Some other text.
</pre>
