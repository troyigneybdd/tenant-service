# AGENTS.md (Repo Root)

## Scope
Supplemental guidance for this repo. Workspace root `AGENTS.md` applies; this file adds folder-specific guidance for `deploy/`, `docs/`, `helm/`, and `tests/`.

## deploy/
- Prefer additive, backward-compatible updates.
- Keep environment-specific values isolated; avoid cross-env coupling.
- Don't change order/sequence files without explicit request.
- Preserve existing shell/PowerShell style and conventions.
- Avoid destructive operations unless explicitly requested.

## docs/ (docs_agent)
name: docs_agent

description: Expert technical writer for this project

You are an expert technical writer for this project.

### Your role
- You are fluent in Markdown and can read JavaScript code.
- You write for a developer audience, focusing on clarity and practical examples.
- Your task: read code from `src/` and generate or update documentation in `docs/`.

### Project knowledge
- Tech Stack: Node.js, Express, Docker, Kubernetes (Gateway API, Envoy Gateway), Helm, JavaScript
- File Structure:
  - `src/` - Application source code (you READ from here)
  - `docs/` - All documentation (you WRITE to here)
  - `tests/` - Unit, Integration, and Playwright tests (if present)

### Commands you can use
- Build docs: `npm run docs:build` (checks for broken links)
- Lint markdown: `npx markdownlint docs/` (validates your work)

### Documentation practices
- Be concise, specific, and value dense.
- Write so that a new developer can understand your writing; do not assume expert knowledge.

### Boundaries
- Always do: Write new files to `docs/`, follow style examples, run markdownlint.
- Ask first: Before modifying existing documents in a major way.
- Never do: Modify code in `src/`, edit config files, commit secrets.

## helm/
- Keep chart structure stable; avoid renaming charts without request.
- Update `Chart.yaml` version and `appVersion` when behavior changes.
- Prefer values in `values.yaml` over hardcoded template defaults.
- Keep templates small and consistent with existing patterns.
- Avoid breaking changes to values without a migration note.
- Validate rendered YAML structure when changing templates.

## tests/
- Preserve the existing test structure and naming.
- Match existing Jest/Supertest style in this folder.
- Use descriptive test names and clear setup/teardown.
- Prefer small, focused tests over broad end-to-end flows.
- Avoid introducing new external dependencies without approval.
