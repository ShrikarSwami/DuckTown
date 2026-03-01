# Duck Party Rumor Game

# Demo: https://youtu.be/uarb4KIBCAo

**A chaotic 2D top-down social simulation game where rumors and relationships determine the story.**

## Team Members

- Shrikar Swami
- Adithya Pillai
- Abhiram Kandadi
- Daksh Aggrawal

## Quick Start

### Running the Game Locally

1. **Install Godot 4** from [godotengine.org](https://godotengine.org)
2. **Open the project:**
   - Launch Godot and select "Import" → navigate to `/game/` folder
   - Or run: `godot --path game/`
3. **Run the game:**
   - Press F5 or click the Play button in the editor

### Running the Backend Locally

The backend is optional for offline play. For full AI NPC dialogue:

1. **Navigate to the server folder:**
   ```bash
   cd server
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Set up environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your Gemini API key (see below)
   ```

4. **Start the server:**
   ```bash
   npm start
   ```
   Server runs on `http://localhost:8080` by default.

5. **Configure in Godot:**
   - In game settings, set backend URL to `http://localhost:8080`

## Environment Variables

Copy `.env.example` to `.env` and fill in your credentials:

```bash
# Root .env (for backend reference)
cp .env.example .env
```

**Available variables:**
- `GEMINI_API_KEY` — Your Google Gemini API key
- `FIREBASE_PROJECT_ID` — Firebase project ID (optional, for persistence)
- `FIREBASE_CLIENT_EMAIL` — Firebase service account email
- `FIREBASE_PRIVATE_KEY` — Firebase service account private key
- `BACKEND_PORT` — Port for the Node backend (default: 8080)

**Never commit `.env` to Git.** The `.env.example` file is tracked as a template.

## Development Workflow

### Branching Strategy

```
main (stable releases)
 └─ develop (integration branch)
     ├─ feature/gameplay-loop
     ├─ feature/npc-dialogue
     └─ feature/rumor-system
```

### Commit Conventions

- `feat: add NPC dialogue system`
- `fix: resolve rumor propagation bug`
- `docs: update API contract`
- `chore: update dependencies`

### Pull Request Process

1. Create a feature branch from `develop`
2. Make atomic commits with clear messages
3. Push and open a PR with description of changes
4. Request review from at least one teammate
5. Merge to `develop` when approved
6. `main` is updated only for releases

## Folder Structure

```
├── README.md                 # This file
├── LICENSE                   # MIT License
├── .gitignore               # Git ignore rules
├── .env.example             # Environment template
├── docs/                    # Documentation & design
├── game/                    # Godot game project
└── server/                  # Node.js backend (optional)
```

## Documentation

- **[Architecture](docs/architecture.md)** — System design & tech stack
- **[Task Board](docs/task_board.md)** — Team task breakdown
- **[NPC Profiles Template](docs/npc_profiles_template.md)** — Character creation guide
- **[API Contract](docs/api_contract.md)** — Backend JSON specification
- **[Art Pipeline](docs/art_pipeline.md)** — Sprite & asset guidelines

## Getting Help

- Check relevant docs in `/docs/` folder
- Review TODO comments in code
- Ask in team Slack/Discord
- Create an Issue or PR for discussions

---

**Happy hacking! 🦆**
