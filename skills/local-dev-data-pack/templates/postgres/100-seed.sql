INSERT INTO todos (id, title, is_done)
VALUES
  ('todo-pg-001', 'Validate local postgres wiring', FALSE),
  ('todo-pg-002', 'Verify deterministic seed IDs', FALSE),
  ('todo-pg-003', 'Confirm compose profile startup', TRUE)
ON CONFLICT (id) DO UPDATE
SET title = EXCLUDED.title,
    is_done = EXCLUDED.is_done;

