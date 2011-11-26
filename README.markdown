*(Note: Still early in development, but should be usable.)*

## Problem

Editing javascript within HTML is annoying. To generalize, editing code that's
embedded in some different code is annoying.

## Solution

Given the following example:

``` html
<script type="text/javascript">
  $(document).ready(function() {
    $('#foo').click(function() {
      alert('OK');
    });
  })
</script>
```

Execute `:InlineEdit` within the script tag. A proxy buffer is opened with
*only* the javascript. Saving the proxy buffer updates the original one. You
can reindent, lint, slice and dice as much as you like.

## What does it work for?

- Javascript within HTML
- SQL within ruby (matches "<<-SQL")

  ``` ruby
  def some_heavy_query
    execute <<-SQL
      SELECT * FROM users WHERE something = 'other';
    SQL
  end
  ```

- Ruby code within markdown blocks

<pre>
  Some text.

  ``` ruby
  def foo
    puts "OK"
  end
  ```

  Some other text
</pre>

## Known issues

- The indentation is adjusted correctly only when spaces are used (soft tabs)
- The cursor is not positioned quite right in the new buffer after saving
