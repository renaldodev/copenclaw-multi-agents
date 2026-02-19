-- =============================================================================
-- OpenClaw Multi-Agent System — Supabase Init SQL
-- =============================================================================

-- Extensões
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- ENUMS
-- =============================================================================

CREATE TYPE card_status AS ENUM ('backlog', 'assign', 'doing', 'review', 'done', 'blocked');
CREATE TYPE agent_level AS ENUM ('L1', 'L2', 'L3', 'L4');
CREATE TYPE agent_role  AS ENUM ('Observer', 'Advisor', 'Operator', 'Autonomous');

-- =============================================================================
-- TABELAS
-- =============================================================================

-- Agents
CREATE TABLE agents (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug          TEXT UNIQUE NOT NULL,
  name          TEXT NOT NULL,
  level         agent_level NOT NULL DEFAULT 'L1',
  role          agent_role NOT NULL DEFAULT 'Observer',
  model         TEXT NOT NULL DEFAULT 'github-copilot/gpt-4o',
  description   TEXT,
  active        BOOLEAN NOT NULL DEFAULT TRUE,
  spawned_by    UUID REFERENCES agents(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Labels
CREATE TABLE labels (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT UNIQUE NOT NULL,
  color      TEXT NOT NULL DEFAULT '#94a3b8',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cards (Mission Control)
CREATE TABLE cards (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title       TEXT NOT NULL,
  description TEXT,
  status      card_status NOT NULL DEFAULT 'backlog',
  assigned_to UUID REFERENCES agents(id),
  created_by  UUID REFERENCES agents(id),
  due_date    TIMESTAMPTZ,
  priority    SMALLINT NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Card Labels (M2M)
CREATE TABLE card_labels (
  card_id  UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  label_id UUID NOT NULL REFERENCES labels(id) ON DELETE CASCADE,
  PRIMARY KEY (card_id, label_id)
);

-- Tasks
CREATE TABLE tasks (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  card_id     UUID REFERENCES cards(id) ON DELETE CASCADE,
  agent_id    UUID REFERENCES agents(id),
  title       TEXT NOT NULL,
  description TEXT,
  status      card_status NOT NULL DEFAULT 'backlog',
  result      TEXT,
  started_at  TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Comments
CREATE TABLE comments (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  card_id    UUID REFERENCES cards(id) ON DELETE CASCADE,
  task_id    UUID REFERENCES tasks(id) ON DELETE CASCADE,
  agent_id   UUID REFERENCES agents(id),
  body       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Activities
CREATE TABLE activities (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id    UUID REFERENCES agents(id),
  card_id     UUID REFERENCES cards(id) ON DELETE SET NULL,
  task_id     UUID REFERENCES tasks(id) ON DELETE SET NULL,
  action      TEXT NOT NULL,
  metadata    JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Notifications
CREATE TABLE notifications (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id   UUID REFERENCES agents(id),
  title      TEXT NOT NULL,
  body       TEXT,
  read       BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Performance Reviews
CREATE TABLE performance_reviews (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id        UUID NOT NULL REFERENCES agents(id),
  reviewed_by     UUID REFERENCES agents(id),
  review_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  quality_score   NUMERIC(3,1) CHECK (quality_score BETWEEN 0 AND 10),
  speed_score     NUMERIC(3,1) CHECK (speed_score BETWEEN 0 AND 10),
  proactivity     NUMERIC(3,1) CHECK (proactivity BETWEEN 0 AND 10),
  adherence       NUMERIC(3,1) CHECK (adherence BETWEEN 0 AND 10),
  cost_benefit    NUMERIC(3,1) CHECK (cost_benefit BETWEEN 0 AND 10),
  decision        TEXT CHECK (decision IN ('promote', 'maintain', 'demote', 'deactivate')),
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX idx_cards_status       ON cards(status);
CREATE INDEX idx_cards_assigned_to  ON cards(assigned_to);
CREATE INDEX idx_tasks_card_id      ON tasks(card_id);
CREATE INDEX idx_tasks_agent_id     ON tasks(agent_id);
CREATE INDEX idx_tasks_status       ON tasks(status);
CREATE INDEX idx_comments_card_id   ON comments(card_id);
CREATE INDEX idx_activities_agent   ON activities(agent_id);
CREATE INDEX idx_activities_created ON activities(created_at DESC);
CREATE INDEX idx_notifications_agent ON notifications(agent_id);
CREATE INDEX idx_perf_reviews_agent  ON performance_reviews(agent_id);

-- =============================================================================
-- updated_at TRIGGER
-- =============================================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_agents_updated_at
  BEFORE UPDATE ON agents
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_cards_updated_at
  BEFORE UPDATE ON cards
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_tasks_updated_at
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- RLS
-- =============================================================================

ALTER TABLE agents              ENABLE ROW LEVEL SECURITY;
ALTER TABLE labels              ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards               ENABLE ROW LEVEL SECURITY;
ALTER TABLE card_labels         ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks               ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments            ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities          ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications       ENABLE ROW LEVEL SECURITY;
ALTER TABLE performance_reviews ENABLE ROW LEVEL SECURITY;

-- Roles
DO $$ BEGIN
  CREATE ROLE anon NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE ROLE authenticated NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Políticas permissivas para service role (acesso total)
CREATE POLICY "service_all" ON agents              FOR ALL TO postgres USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "service_all" ON labels              FOR ALL TO postgres USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "service_all" ON cards               FOR ALL TO postgres USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "service_all" ON card_labels         FOR ALL TO postgres USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "service_all" ON tasks               FOR ALL TO postgres USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "service_all" ON comments            FOR ALL TO postgres USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "service_all" ON activities          FOR ALL TO postgres USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "service_all" ON notifications       FOR ALL TO postgres USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "service_all" ON performance_reviews FOR ALL TO postgres USING (TRUE) WITH CHECK (TRUE);

-- Anon: somente leitura nas tabelas públicas
CREATE POLICY "anon_read" ON agents  FOR SELECT TO anon USING (active = TRUE);
CREATE POLICY "anon_read" ON cards   FOR SELECT TO anon USING (TRUE);
CREATE POLICY "anon_read" ON labels  FOR SELECT TO anon USING (TRUE);

-- =============================================================================
-- REALTIME
-- =============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE cards;
ALTER PUBLICATION supabase_realtime ADD TABLE tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE comments;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE activities;

-- =============================================================================
-- SEED — 7 Agentes Iniciais
-- =============================================================================

INSERT INTO agents (slug, name, level, role, model, description) VALUES
  ('amora',        'Amora',        'L4', 'Autonomous', 'github-copilot/gpt-4o', 'Coordenadora geral. Autoridade total no domínio permitido. Reporta direto ao Renaldo. Heartbeat: 30min.'),
  ('planner',      'Planner',      'L3', 'Operator',   'github-copilot/gpt-4o', 'Planejamento estratégico. Executa autônomo dentro dos guardrails. Sob demanda via Telegram tópico 719.'),
  ('orchestrator', 'Orchestrator', 'L2', 'Advisor',    'github-copilot/gpt-4o', 'Orquestração de tarefas. Recomenda e executa com aprovação.'),
  ('dev',          'Dev',          'L2', 'Advisor',    'github-copilot/gpt-4o', 'Desenvolvimento e código. Ferramentas: MC, Metricsen, MOM. Heartbeat: 10min (futuro).'),
  ('qa',           'QA',           'L2', 'Advisor',    'github-copilot/gpt-4o', 'Qualidade e testes. Scope: APIs, edge cases, UX.'),
  ('scraper',      'Scraper',      'L1', 'Observer',   'github-copilot/gpt-4o', 'Coleta de dados: YouTube, Reddit, HN, PH, Twitter. Output revisado antes de ir ao Renaldo.'),
  ('content',      'Content',      'L1', 'Observer',   'github-copilot/gpt-4o', 'Criação de conteúdo: 547 conteúdos / 8 creators. LinkedIn posts, video cutting.');

-- Relacionar spawned_by
UPDATE agents SET spawned_by = (SELECT id FROM agents WHERE slug = 'amora')
WHERE slug IN ('qa', 'content');

-- Labels iniciais
INSERT INTO labels (name, color) VALUES
  ('bug',      '#ef4444'),
  ('feature',  '#3b82f6'),
  ('infra',    '#f59e0b'),
  ('content',  '#8b5cf6'),
  ('review',   '#10b981'),
  ('blocked',  '#6b7280'),
  ('urgent',   '#dc2626');
