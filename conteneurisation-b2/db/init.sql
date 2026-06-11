CREATE TABLE IF NOT EXISTS messages (
  id SERIAL PRIMARY KEY,
  message TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO messages (message)
VALUES
  ('Bonjour depuis PostgreSQL'),
  ('Donnee exemple pour le projet B2'),
  ('La base est interrogeable depuis les serveurs web')
ON CONFLICT DO NOTHING;
