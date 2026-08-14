MERGE Todos AS target
USING (VALUES
  ('todo-sql-001', 'Validate local sqlserver wiring', 0),
  ('todo-sql-002', 'Verify deterministic seed IDs', 0),
  ('todo-sql-003', 'Confirm compose profile startup', 1)
) AS source (Id, Title, IsDone)
ON target.Id = source.Id
WHEN MATCHED THEN
  UPDATE SET Title = source.Title, IsDone = source.IsDone
WHEN NOT MATCHED THEN
  INSERT (Id, Title, IsDone) VALUES (source.Id, source.Title, source.IsDone);

