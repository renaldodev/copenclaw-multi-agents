# 🦞 OpenClaw Multi-Agent System

Sistema multi-agente hierárquico baseado em OpenClaw, pronto para deploy em VPS DigitalOcean com Supabase como Data Layer.

---

## Arquitetura — Hierarquia de Comando

```
Renaldo (CEO / Human)
└── Amora (L4 · Autonomous) — github-copilot/gpt-4o
    ├── Planner (L3 · Operator) — github-copilot/gpt-4o
    │   ├── Orchestrator (L2 · Advisor) — github-copilot/gpt-4o
    │   ├── Dev (L2 · Advisor) — github-copilot/gpt-4o
    │   └── QA (L2 · Advisor) — github-copilot/gpt-4o
    ├── Scraper (L1 · Observer) — github-copilot/gpt-4o
    └── Content (L1 · Observer) — github-copilot/gpt-4o
```

> **Comunicação** flui para **cima** (agente → supervisor).
> **Coordenação** flui para **baixo** via Amora.
> Agentes **não falam diretamente** entre si (por enquanto).

---

## Agentes

| Agente        | Nível | Papel      | Modelo                 | Heartbeat | Triggers                  |
|---------------|-------|------------|------------------------|-----------|---------------------------|
| Amora         | L4    | Autonomous | github-copilot/gpt-4o | 30min     | Telegram HQ + DM          |
| Planner       | L3    | Operator   | github-copilot/gpt-4o | Sob demanda | Telegram tópico 719     |
| Orchestrator  | L2    | Advisor    | github-copilot/gpt-4o | —         | Planner / Amora           |
| Dev           | L2    | Advisor    | github-copilot/gpt-4o | 10min*    | Planner / Amora           |
| QA            | L2    | Advisor    | github-copilot/gpt-4o | —         | Amora (spawned)           |
| Scraper       | L1    | Observer   | github-copilot/gpt-4o | —         | Amora                     |
| Content       | L1    | Observer   | github-copilot/gpt-4o | —         | Amora (spawned)           |

*futuro

---

## Pré-requisitos

- VPS Ubuntu 22.04 com **mínimo 4GB RAM** (ex: DigitalOcean Droplet)
- Domínio apontando para o IP da VPS
- Docker 24+ e Docker Compose v2
- Conta GitHub Copilot com API Key
- Contas Supabase, Telegram Bot, Discord Bot
- 1Password CLI instalado (`op`) — Regra #4

---

## Instalação

### 1. Clone o repositório

```bash
git clone https://github.com/renaldodev/copenclaw-multi-agents.git
cd copenclaw-multi-agents
```

### 2. Configure as variáveis de ambiente

```bash
cp .env.example .env
nano .env   # preencha todas as variáveis
```

### 3. Configure o nginx com seu domínio

```bash
nano nginx/conf.d/default.conf   # substitua YOUR_DOMAIN_HERE
```

### 4. Execute o script de setup (em VPS)

```bash
sudo bash setup-digitalocean.sh
```

Ou manualmente:

```bash
docker compose pull
docker compose up -d
```

---

## Estrutura de Arquivos

```
copenclaw-multi-agents/
├── openclaw.json              # Configuração principal dos agentes
├── docker-compose.yml         # Orquestração dos serviços
├── .env.example               # Template de variáveis de ambiente
├── setup-digitalocean.sh      # Script de setup para VPS Ubuntu
├── supabase/
│   └── init.sql               # Schema completo do banco de dados
├── nginx/
│   └── conf.d/
│       └── default.conf       # Configuração do reverse proxy
├── shared/
│   ├── TEAM.md                # Org chart vivo (lido por todos os agentes)
│   ├── RULES.md               # 10 Regras Invioláveis
│   └── lessons/               # Lições aprendidas por agente (Regra #9)
└── workspaces/
    ├── amora/
    │   ├── SOUL.md            # Identidade, valores e guardrails
    │   └── WORKING.md         # Contexto atual da task
    ├── planner/
    ├── orchestrator/
    ├── dev/
    ├── qa/
    ├── scraper/
    └── content/
```

---

## Task Lifecycle

```
Backlog → Assign → Doing → Review → Done
                                      ↕
                                   Blocked
```

- Tasks vivem no **Mission Control** (Supabase)
- Agentes recebem contexto via `WORKING.md` + API `/context`
- Resultado volta como **comentário no card** (Regra #8)

---

## Performance Review (Semanal — Domingos)

Amora avalia cada agente com os critérios:

| Critério         | Peso |
|------------------|------|
| Quality Score    | ⭐⭐⭐ |
| Velocidade       | ⭐⭐   |
| Proatividade     | ⭐⭐   |
| Aderência        | ⭐⭐⭐ |
| Custo-Benefício  | ⭐⭐   |

**Decisão possível**: ⬆️ Promover | 🟰 Manter | ⬇️ Rebaixar | ❌ Desativar

Registro em `shared/TEAM.md` + `shared/lessons/{agent}.md`

---

## 10 Regras Invioláveis

1. **Texto > Cérebro** — Se importa, escreve no arquivo. "Mental notes" morrem no restart.
2. **Todo agente começa L1** — Sem exceções. Confiança se conquista, não se assume.
3. **SOUL.md define quem o agente É** — Sem alma, é só um chatbot.
4. **Nunca hardcodar credenciais** — Tudo via 1Password CLI (`op item get`).
5. **Dado privado não vaza** — Nunca em grupos, nunca sem permissão.
6. **Um agente com 8 skills > 8 agentes** — Só cria agente novo quando skill não resolve.
7. **shared/TEAM.md é obrigatório** — Todo agente lê na sessão.
8. **Resultado volta como comentário no card** — MC (Supabase) é source of truth.
9. **Lição aprendida → shared/lessons/** — Erro que não vira lição vai se repetir.
10. **Se travou, bloqueia e comenta** — Mover card pra "blocked" + explicar o motivo.

---

## API Endpoints

| Endpoint                        | Descrição                            |
|---------------------------------|--------------------------------------|
| `GET /cards`                    | Listar cards do Mission Control      |
| `GET /tasks`                    | Listar tasks                         |
| `GET /bookmarks`                | Listar bookmarks                     |
| `GET /activity`                 | Feed de atividades                   |
| `GET /notifications`            | Notificações                         |
| `GET /sessions`                 | Sessões ativas                       |
| `GET /memory`                   | Memória compartilhada                |
| `GET /agents/{id}/context`      | Contexto do agente                   |
| `POST /agents/{id}/assign-task` | Atribuir task ao agente              |
| `POST /agents/{id}/complete-task` | Marcar task como concluída         |

---

## Sistema de Níveis

| Nível | Nome      | Autonomia                                              |
|-------|-----------|--------------------------------------------------------|
| L1    | Observer  | Executa tasks atribuídas, output revisado              |
| L2    | Advisor   | Recomenda e executa com aprovação, pode sugerir        |
| L3    | Operator  | Executa autônomo dentro dos guardrails                 |
| L4    | Autonomous| Autoridade total no domínio, reporta direto ao Renaldo |

---

## Links Úteis

- [OpenClaw Docs](https://openclaw.dev/docs)
- [Supabase Docs](https://supabase.com/docs)
- [Docker Compose Docs](https://docs.docker.com/compose/)
- [DigitalOcean — Create Droplet](https://docs.digitalocean.com/products/droplets/how-to/create/)

---

> **Renaldo** (CEO/Human) é o topo da cadeia de comando.
> **Amora** é a coordenadora — único ponto de contato direto com o Renaldo no sistema.
