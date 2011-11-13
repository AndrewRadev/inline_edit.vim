def some_heavy_query
  execute <<-SQL
    select * from users where something = 'other';
  SQL
end
