# No Emojis in Code

**Never use emoji characters in source code. Use proper icons (Lucide React) or text symbols instead.**

## Rules

- Do NOT use emoji Unicode characters (e.g. `🔴`, `📁`, `⚡`, `🐛`) in constants, default values, labels, or data
- Use Lucide React icon components for UI elements
- Use Unicode geometric/math symbols (e.g. `▲`, `▬`, `▼`, `◇`) for inline text indicators when icons aren't practical
- Use single-letter abbreviations for avatar/badge content (e.g. `"E"` for Engineering)

## Why

Emojis render inconsistently across platforms and browsers, look unprofessional in enterprise UIs, and break text-based tooling (grep, diff, terminals). Proper icon libraries provide consistent sizing, theming, and accessibility.

## Alternatives

| Instead of | Use |
|-----------|-----|
| Emoji in JSX | Lucide React component (`<Settings />`, `<Bug />`) |
| Emoji in data/constants | Single letter or Unicode symbol |
| Emoji as priority indicator | Arrow/bar symbols (`▲`, `▬`, `▼`) |
| Emoji as status dot | Colored `<span>` with CSS classes |