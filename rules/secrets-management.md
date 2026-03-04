# Secrets Management Rules

## Core Principle
**NEVER hardcode secrets, API keys, or any sensitive credentials directly in the code.**

## Local Development

All secrets for local development MUST be stored in environment files (`.env`, `.env.local`, etc.) at the project root. These files MUST be listed in `.gitignore` and never committed to version control.

### Loading Secrets

Secrets should be loaded from environment variables using your framework's configuration system:
- Python: `pydantic-settings`, `python-dotenv`, or `os.environ`
- Node/TypeScript: `dotenv`, framework-provided env loading
- Any language: Read from environment variables, never from code

## Production & Staging

For deployment environments, secrets MUST be stored in your CI/CD platform's secret management (GitHub Secrets, GitLab CI Variables, etc.) and passed as environment variables during deployment.

## Rules

### Forbidden
- Hardcoded API keys, tokens, passwords in source code
- Secrets in committed config files
- Secrets in logs or error messages
- Secrets in comments or documentation

### Required
- All secrets in `.env` files (local) or CI/CD secrets (production)
- `.env` files in `.gitignore`
- Secrets accessed via environment variables or config objects
- Separate secrets per environment (dev/staging/prod)

---

**REMEMBER: Keep secrets out of the codebase. Use environment files for local and CI/CD secrets for deployment.**