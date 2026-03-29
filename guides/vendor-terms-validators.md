# Vendor Terms Validators — Implementation Guide

Reference guide for setting up vendor term enforcement in any Aitronos project. This is NOT loaded into AI context — see `rules/vendor-terms.md` for the concise rule.

---

## Overview

Vendor term enforcement uses two complementary validators:

1. **Doc Scanner** (`forbidden_terms_validator.py`) — Scans public-facing documentation (Markdown, YAML, JSON, HTML) for vendor names using text matching with allowlists.
2. **Code Scanner** (`vendor_exposure_validator.py`) — AST-based scan of API-facing Python code for vendor terms in docstrings, Field descriptions, decorator parameters, class names, and schema field names.

Both validators:
- Exit with code 1 on failure (errors found)
- Write JSON reports to `compliance_reports/{date}/json/`
- Read configuration from `scripts/compliance/config.json`
- Support project-specific allowlists and exclusions

---

## Doc Scanner — Public Documentation

### What It Scans

Text files in public documentation directories (configurable via `project.config.yaml`):

| File Type | Extensions |
|-----------|-----------|
| Markdown | `.md`, `.mdx` |
| Data | `.yaml`, `.yml`, `.json` |
| Web | `.html` |
| Text | `.txt` |

### How It Works

1. Recursively find all text files in configured `public_doc_paths`
2. For each line, check against the forbidden terms regex pattern
3. Before flagging, check if the line matches any allowlisted pattern
4. Report violations with file path, line number, and matched term

### Allowlisted Patterns

Lines matching these patterns are skipped because they contain legitimate API identifiers that cannot be renamed:

| Pattern Type | Example |
|-------------|---------|
| URL paths | `/v1/admin/composio/sync` |
| operationId values | `trigger_composio_sync_v1_admin_composio_sync_post` |
| JSON `$ref` pointers | `#/components/schemas/ComposioSyncResponse` |
| Property names | `is_composio_managed`, `composio_connection_id` |
| HTTP headers | `x-composio-signature` |
| Code example URLs | `curl`, `requests.get(...)`, `fetch(...)` with API URLs |
| Markdown link targets | `[Label](./trigger-composio-sync.md)` |
| Example data values | `"airbyte": 5` in JSON examples |
| Protocol URLs | `webcal://p123-caldav.icloud.com/...` |

Projects should extend allowlists as needed for their specific API identifiers.

### Skeleton: Doc Scanner

```python
#!/usr/bin/env python3
"""
Forbidden Terms Validator for Public Documentation

Scans public-facing documentation for third-party vendor names that should
never appear in customer-facing docs.
"""

import json
import re
import sys
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Forbidden terms — case-insensitive
# ---------------------------------------------------------------------------
FORBIDDEN_TERMS = [
    "composio", "airbyte", "fivetran", "qdrant", "quadrant",
    "vexa", "assemblyai", "deepgram", "caldav",
    "redis", "celery", "rabbitmq", "minio", "supabase", "flower", "whisper",
]

FORBIDDEN_PATTERN = re.compile(
    r"\b(" + "|".join(re.escape(t) for t in FORBIDDEN_TERMS) + r")\b",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Allowlisted patterns — lines matching these contain legitimate identifiers
# PROJECT-SPECIFIC: Extend this list for your API identifiers
# ---------------------------------------------------------------------------
ALLOWLISTED_LINE_PATTERNS = [
    # API endpoint URL paths
    re.compile(
        r"/v1/[^\s\"']*(" + "|".join(re.escape(t) for t in FORBIDDEN_TERMS) + r")",
        re.IGNORECASE,
    ),
    # operationId values
    re.compile(r"operationId", re.IGNORECASE),
    # JSON schema $ref pointers
    re.compile(r"\$ref"),
    # Code example URLs (curl, requests, fetch)
    re.compile(r"(curl|https?://|requests\.(get|post|put|patch|delete)|fetch\()", re.IGNORECASE),
    # Markdown link targets with vendor terms (actual filenames)
    re.compile(
        r"\]\([^)]*(" + "|".join(re.escape(t) for t in FORBIDDEN_TERMS) + r")[^)]*\)",
        re.IGNORECASE,
    ),
    # Protocol URLs (e.g., webcal://...caldav...)
    re.compile(r"webcal://[^\s\"']*caldav", re.IGNORECASE),
    # --- PROJECT-SPECIFIC allowlists below ---
    # Add patterns for your project's specific API identifiers here
]


def is_allowlisted_line(line: str) -> bool:
    return any(pattern.search(line) for pattern in ALLOWLISTED_LINE_PATTERNS)


# PROJECT-SPECIFIC: Update these paths for your project
SCAN_PATHS = [
    "docs/public-docs/docs",
    # "docs/public-docs/openapi/openapi.json",
]

EXCLUDED_PATTERNS = [
    "redoc-static.html",
    "_archived/",
]

TEXT_EXTENSIONS = {".md", ".yaml", ".yml", ".json", ".html", ".txt", ".mdx"}


def is_excluded(file_path: Path) -> bool:
    path_str = str(file_path)
    return any(pattern in path_str for pattern in EXCLUDED_PATTERNS)


def scan_file(file_path: Path, display_path: str) -> list[dict]:
    violations = []
    try:
        content = file_path.read_text(encoding="utf-8")
    except Exception:
        return []

    for line_num, line in enumerate(content.splitlines(), 1):
        if is_allowlisted_line(line):
            continue
        for match in FORBIDDEN_PATTERN.finditer(line):
            violations.append({
                "file": display_path,
                "line": line_num,
                "severity": "error",
                "message": f"Forbidden vendor term '{match.group(1)}' in public docs.",
                "code": "FORBIDDEN_VENDOR_TERM",
                "term": match.group(1).lower(),
            })
    return violations


def validate_forbidden_terms(root_dir: Path) -> list[dict]:
    violations = []
    for scan_path_str in SCAN_PATHS:
        scan_path = root_dir / scan_path_str
        if not scan_path.exists():
            continue
        if scan_path.is_file():
            rel = str(scan_path.relative_to(root_dir))
            if not is_excluded(scan_path):
                violations.extend(scan_file(scan_path, rel))
        else:
            for fp in sorted(scan_path.rglob("*")):
                if not fp.is_file() or is_excluded(fp):
                    continue
                if fp.suffix.lower() not in TEXT_EXTENSIONS:
                    continue
                violations.extend(scan_file(fp, str(fp.relative_to(root_dir))))
    return violations


def main():
    root_dir = Path(__file__).parent.parent.parent
    violations = validate_forbidden_terms(root_dir)

    error_count = len(violations)
    if error_count > 0:
        print(f"  {error_count} forbidden vendor term(s) found in public docs")
        sys.exit(1)
    else:
        print("Forbidden terms check passed")
        sys.exit(0)

if __name__ == "__main__":
    main()
```

---

## Code Scanner — API-Facing Code

### What It Checks

Using Python AST analysis, the code scanner inspects:

| Element | Why It Matters |
|---------|---------------|
| Route handler docstrings | Feeds into OpenAPI spec operation descriptions |
| Module-level docstrings in route files | Feeds into OpenAPI tag descriptions |
| `Field(description=...)` | Feeds into OpenAPI schema property descriptions |
| `Query(description=...)`, `Body(description=...)`, `Header(description=...)` | OpenAPI parameter descriptions |
| Route decorator `summary=`, `description=` | OpenAPI operation summary/description |
| Pydantic model class names | Exposed in OpenAPI schema names |
| Schema field names (class attributes) | Exposed in API response JSON keys |
| Class docstrings | Feeds into OpenAPI schema descriptions |

### What It Ignores (Allowed)

| Element | Reason |
|---------|--------|
| Import statements | Internal code |
| Variable names in logic | Internal code |
| `#` comments (non-docstring) | Internal code |
| Logger calls | Internal code |
| Private function docstrings (`_prefixed`) | Not API-facing |
| Non-route function docstrings | Not in OpenAPI |
| `__init__.py` files | Internal |
| Admin route directories | Internal endpoints |
| Utility module docstrings | Not in OpenAPI |

### Identifier Matching

For class names and field names, use **substring matching** instead of word-boundary matching because vendor terms are embedded in CamelCase or snake_case identifiers:

- `ComposioSyncResponse` → matches "Composio"
- `composio_connection_id` → matches "composio"
- `VexaBotConfig` → matches "Vexa"

For docstrings and descriptions, use **word-boundary matching** (`\b`) to avoid false positives.

### Skeleton: Code Scanner

```python
#!/usr/bin/env python3
"""
Vendor Exposure Validator

AST-based scan of API-facing code for vendor term exposure.
"""

import ast
import re
import sys
from pathlib import Path
from typing import Any

FORBIDDEN_TERMS = [
    "airbyte", "composio", "qdrant", "quadrant",
    "vexa", "assemblyai", "deepgram", "caldav",
    "redis", "celery", "rabbitmq", "minio", "supabase", "flower", "whisper",
]

# Word-boundary pattern for natural text (docstrings, descriptions)
FORBIDDEN_PATTERN = re.compile(
    r"\b(" + "|".join(re.escape(t) for t in FORBIDDEN_TERMS) + r")\b",
    re.IGNORECASE,
)

# Substring pattern for identifiers (class names, field names)
FORBIDDEN_IDENTIFIER_PATTERN = re.compile(
    r"(" + "|".join(re.escape(t) for t in FORBIDDEN_TERMS) + r")",
    re.IGNORECASE,
)

# PROJECT-SPECIFIC: Update these for your project
SCAN_DIRS = ["app/api"]
EXCLUDED_DIRS = ["app/api/v1/routes/admin"]
INTERNAL_UTIL_DIRS = ["app/api/v1/utils", "app/api/deps.py"]

ROUTE_DECORATOR_METHODS = {"get", "post", "put", "delete", "patch", "head", "options"}


class VendorExposureVisitor(ast.NodeVisitor):
    """AST visitor that detects vendor terms in user-facing code elements."""

    def __init__(self, file_path: str, is_internal_util: bool = False):
        self.file_path = file_path
        self.is_internal_util = is_internal_util
        self.violations: list[dict[str, Any]] = []
        self._class_stack: list[str] = []

    def _add_violation(self, line: int, term: str, context: str, severity: str = "error"):
        self.violations.append({
            "file": self.file_path, "line": line, "severity": severity,
            "message": f"Vendor term '{term}' exposed in {context}.",
            "code": "VENDOR_EXPOSURE", "term": term.lower(), "context": context,
        })

    def _check_string(self, value: str, line: int, context: str, severity: str = "error"):
        for match in FORBIDDEN_PATTERN.finditer(value):
            self._add_violation(line, match.group(1), context, severity)

    def _get_docstring_node(self, node):
        if (isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Module))
                and node.body and isinstance(node.body[0], ast.Expr)
                and isinstance(node.body[0].value, ast.Constant)
                and isinstance(node.body[0].value.value, str)):
            return node.body[0].value
        return None

    def visit_Module(self, node):
        if not self.is_internal_util:
            doc = self._get_docstring_node(node)
            if doc:
                self._check_string(doc.value, doc.lineno, "module docstring")
        self.generic_visit(node)

    def visit_FunctionDef(self, node):
        self._visit_function(node)

    def visit_AsyncFunctionDef(self, node):
        self._visit_function(node)

    def _visit_function(self, node):
        doc = self._get_docstring_node(node)
        if doc and self._has_route_decorator(node):
            self._check_string(doc.value, doc.lineno, f"route handler docstring '{node.name}'")
        for decorator in node.decorator_list:
            if isinstance(decorator, ast.Call):
                for kw in decorator.keywords:
                    if kw.arg in ("summary", "description") and isinstance(kw.value, ast.Constant):
                        self._check_string(kw.value.value, kw.value.lineno,
                                           f"route decorator {kw.arg}= on '{node.name}'")
        self.generic_visit(node)

    def _has_route_decorator(self, node):
        for d in node.decorator_list:
            if isinstance(d, ast.Call) and isinstance(d.func, ast.Attribute):
                if d.func.attr in ROUTE_DECORATOR_METHODS:
                    return True
            elif isinstance(d, ast.Attribute) and d.attr in ROUTE_DECORATOR_METHODS:
                return True
        return False

    def visit_ClassDef(self, node):
        self._class_stack.append(node.name)
        doc = self._get_docstring_node(node)
        if doc:
            self._check_string(doc.value, doc.lineno, f"class docstring '{node.name}'")
        for match in FORBIDDEN_IDENTIFIER_PATTERN.finditer(node.name):
            self._add_violation(node.lineno, match.group(1), f"class name '{node.name}'")
        self.generic_visit(node)
        self._class_stack.pop()

    def visit_Call(self, node):
        name = ""
        if isinstance(node.func, ast.Name):
            name = node.func.id
        elif isinstance(node.func, ast.Attribute):
            name = node.func.attr
        if name in ("Field", "Query", "Body", "Header"):
            for kw in node.keywords:
                if kw.arg == "description" and isinstance(kw.value, ast.Constant):
                    self._check_string(kw.value.value, kw.value.lineno,
                                       f"{name}(description=...)")
        self.generic_visit(node)

    def visit_Assign(self, node):
        if self._class_stack:
            for target in node.targets:
                if isinstance(target, ast.Name):
                    for match in FORBIDDEN_IDENTIFIER_PATTERN.finditer(target.id):
                        self._add_violation(node.lineno, match.group(1),
                                            f"schema field name '{target.id}'", "warning")
        self.generic_visit(node)

    def visit_AnnAssign(self, node):
        if self._class_stack and isinstance(node.target, ast.Name):
            for match in FORBIDDEN_IDENTIFIER_PATTERN.finditer(node.target.id):
                self._add_violation(node.lineno, match.group(1),
                                    f"schema field name '{node.target.id}'", "warning")
        self.generic_visit(node)


def scan_python_file(file_path: Path, display_path: str, is_internal_util: bool = False):
    try:
        source = file_path.read_text(encoding="utf-8")
        tree = ast.parse(source)
    except Exception:
        return []
    visitor = VendorExposureVisitor(display_path, is_internal_util)
    visitor.visit(tree)
    return visitor.violations


def main():
    root_dir = Path(__file__).parent.parent.parent
    violations = []
    for scan_dir_str in SCAN_DIRS:
        scan_dir = root_dir / scan_dir_str
        if not scan_dir.exists():
            continue
        for py_file in sorted(scan_dir.rglob("*.py")):
            if not py_file.is_file() or py_file.name == "__init__.py":
                continue
            rel = str(py_file.relative_to(root_dir))
            if any(rel.startswith(exc) for exc in EXCLUDED_DIRS):
                continue
            is_util = any(rel.startswith(u) or rel == u for u in INTERNAL_UTIL_DIRS)
            violations.extend(scan_python_file(py_file, rel, is_util))

    errors = sum(1 for v in violations if v["severity"] == "error")
    if errors > 0:
        print(f"  {errors} vendor exposure error(s) found")
        sys.exit(1)
    else:
        print("Vendor exposure check passed")
        sys.exit(0)

if __name__ == "__main__":
    main()
```

---

## Project Configuration

Add to `project.config.yaml`:

```yaml
compliance:
  vendor_terms:
    extra_terms: []                           # Project-specific additions
    public_doc_paths: ["docs/public-docs/docs"]
    api_code_paths: ["app/api"]
    excluded_dirs: ["app/api/v1/routes/admin"]
    excluded_files: ["redoc-static.html"]
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `extra_terms` | `list[str]` | Additional vendor terms specific to this project |
| `public_doc_paths` | `list[str]` | Directories/files to scan for doc violations |
| `api_code_paths` | `list[str]` | Directories to scan for code violations |
| `excluded_dirs` | `list[str]` | Directories exempt from code scanning |
| `excluded_files` | `list[str]` | Files/patterns to skip in doc scanning |

---

## Compliance Runner Integration

Register both validators in your project's compliance runner (`scripts/compliance/config.json` or equivalent):

```json
{
  "compliance_checks": {
    "forbidden_terms": {
      "enabled": true,
      "script": "scripts/compliance/forbidden_terms_validator.py",
      "thresholds": { "fail_on_error": true }
    },
    "vendor_exposure": {
      "enabled": true,
      "script": "scripts/compliance/vendor_exposure_validator.py",
      "thresholds": { "fail_on_error": true }
    }
  }
}
```

---

## Setting Up in a New Project

1. Create `scripts/compliance/forbidden_terms_validator.py` from the doc scanner skeleton above
2. Create `scripts/compliance/vendor_exposure_validator.py` from the code scanner skeleton above
3. Update paths in both scripts to match your project structure
4. Add project-specific allowlisted patterns for legitimate API identifiers
5. Register in your compliance runner
6. Add `compliance.vendor_terms` section to `project.config.yaml`
7. Run both validators and fix any violations
