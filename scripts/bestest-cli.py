#!/usr/bin/env python3
"""
bestest-cli — deterministic helper layer for the bestest skill.

Owns the mechanical operations that spokes currently describe in prose:
detection, config read/write/validate, report selection (with companion
filtering), concurrency locks, and metrics read-modify-write.

Stdlib-only (Python 3.8+). Each subcommand emits JSON to stdout for agent
parsing unless --human is given. Spokes delegate to this tool as the PRIMARY
path and fall back to the documented manual steps when `python3` is
unavailable (graceful degradation).

Usage:
  bestest-cli detect [--phase N] [--human]
  bestest-cli config validate [--human]
  bestest-cli config read <dot.path> [--human]
  bestest-cli config write <dot.path> <value> [--human]
  bestest-cli report list [--kind run|scan|doctor|coverage] [--latest] [--human]
  bestest-cli report latest-full [--human]          # non-companion run, else scan, else companion
  bestest-cli lock acquire <name> [--timeout N] [--human]
  bestest-cli lock release <name> [--human]
  bestest-cli metrics merge <section> <json-file> [--human]
  bestest-cli metrics read [--human]
  bestest-cli render <template-path> <json-params> [--human]
  bestest-cli contracts check [--human]
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_PATH = ".bestest/config.yaml"
METRICS_PATH = ".bestest/state/metrics.json"
LOCK_DIR = ".bestest/state/.locks"


# ═══════════════════════════════════════════════════════════════════════
# Minimal YAML subset parser/serializer (stdlib-only)
# Handles the subset bestest config.yaml actually uses: nested mappings,
# scalars (string/number/bool/null), lists of scalars, and # comments.
# ═══════════════════════════════════════════════════════════════════════

def _yaml_scalar(raw):
    raw = raw.strip()
    if raw in ("null", "~"):
        return None
    if raw in ("true", "True"):
        return True
    if raw in ("false", "False"):
        return False
    if (raw.startswith('"') and raw.endswith('"')) or (raw.startswith("'") and raw.endswith("'")):
        return raw[1:-1]
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    if re.fullmatch(r"-?\d+\.\d+", raw):
        return float(raw)
    return raw


def yaml_load(text):
    """Parse a minimal YAML subset into nested dict/list structure."""
    lines = []
    for raw in text.splitlines():
        if raw.strip().startswith("#") or not raw.strip():
            continue
        lines.append(raw)

    root = {}
    stack = [(-1, root)]  # (indent, container) — container is dict or list

    def container_add(container, key, value):
        if isinstance(container, dict):
            container[key] = value
        else:
            container.append(value)

    def container_assign(container, key, value):
        if isinstance(container, dict):
            container[key] = value
        else:
            if len(container) == 0 or not isinstance(container[-1], dict):
                container.append({})
            container[-1][key] = value

    for line in lines:
        indent = len(line) - len(line.lstrip())
        stripped = line.strip()

        while stack and indent <= stack[-1][0]:
            stack.pop()
        parent_indent, parent = stack[-1] if stack else (-1, root)

        if stripped.startswith("- "):
            item = _yaml_scalar(stripped[2:])
            if not isinstance(parent, list):
                # promote parent container to list if it's an empty dict value under a key
                if isinstance(parent, dict) and not parent:
                    # cannot happen with our stack model; treat as list at root-ish level
                    pass
            container_add(parent, None, item)
            if isinstance(item, dict):
                stack.append((indent, item))
            continue

        if ":" not in stripped:
            # continuation of a scalar list item (rare) — skip
            continue

        key, _, value = stripped.partition(":")
        key = key.strip()
        value = value.strip()

        if value == "":
            # nested container; ensure parent supports it
            if isinstance(parent, list):
                container_assign(parent, key, {})
                new_container = parent[-1]
            else:
                new_container = {}
                parent[key] = new_container
            stack.append((indent, new_container))
        else:
            container_assign(parent, key, _yaml_scalar(value))

    return root


def yaml_dump(data, indent=0):
    """Serialize nested dict/list back to the minimal YAML subset."""
    out = []

    def _dump_item(key, value, level):
        pad = "  " * level
        if isinstance(value, dict):
            if key is not None:
                out.append(f"{pad}{key}:")
                for k, v in value.items():
                    _dump_item(k, v, level + 1)
            else:
                for k, v in value.items():
                    _dump_item(k, v, level)
        elif isinstance(value, list):
            if key is not None:
                out.append(f"{pad}{key}:")
            for item in value:
                if isinstance(item, dict):
                    out.append(f"{pad}-")
                    for k, v in item.items():
                        _dump_item(k, v, level + 1)
                else:
                    out.append(f"{pad}- {_yaml_str(item)}")
        else:
            out.append(f"{pad}{key}: {_yaml_str(value)}")

    def _yaml_str(value):
        if value is None:
            return "null"
        if value is True:
            return "true"
        if value is False:
            return "false"
        if isinstance(value, str):
            if value == "":
                return '""'
            if any(ch in value for ch in ":#\n"):
                return f'"{value}"'
            return value
        return str(value)

    _dump_item(None, data, indent)
    return "\n".join(out) + "\n"


def _read_file(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def _atomic_write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(content)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def _in_repo_root():
    if not os.path.isdir(".bestest"):
        return None
    return os.getcwd()


# ═══════════════════════════════════════════════════════════════════════
# Locks
# ═══════════════════════════════════════════════════════════════════════

def lock_acquire(name, timeout=5):
    root = _in_repo_root()
    if root is None:
        return {"ok": False, "error": "not in a .bestest project root"}
    os.makedirs(LOCK_DIR, exist_ok=True)
    lockfile = os.path.join(LOCK_DIR, f"{name}.lock")
    # flock via fcntl when available (POSIX)
    try:
        import fcntl
        with open(lockfile, "a") as fh:
            try:
                fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError:
                return {"ok": False, "error": f"lock '{name}' already held", "file": lockfile}
            return {"ok": True, "name": name, "file": lockfile, "fd": fh.fileno()}
    except ImportError:
        # mkdir-based fallback
        lockdir = lockfile + ".d"
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                os.mkdir(lockdir)
                return {"ok": True, "name": name, "file": lockdir}
            except FileExistsError:
                time.sleep(0.2)
        return {"ok": False, "error": f"could not acquire lock '{name}' within {timeout}s", "file": lockdir}


def lock_release(name):
    root = _in_repo_root()
    if root is None:
        return {"ok": False, "error": "not in a .bestest project root"}
    lockfile = os.path.join(LOCK_DIR, f"{name}.lock")
    lockdir = lockfile + ".d"
    removed = False
    try:
        if os.path.isdir(lockdir):
            os.rmdir(lockdir)
            removed = True
    except OSError:
        pass
    # flock locks release when the process exits; nothing to do here
    return {"ok": True, "name": name, "released": removed or True}


# ═══════════════════════════════════════════════════════════════════════
# Config
# ═══════════════════════════════════════════════════════════════════════

def _load_config():
    root = _in_repo_root()
    if root is None:
        return None, "not in a .bestest project root"
    path = os.path.join(root, CONFIG_PATH)
    if not os.path.exists(path):
        return None, f"{CONFIG_PATH} not found"
    try:
        return yaml_load(_read_file(path)), None
    except Exception as exc:
        return None, f"failed to parse {CONFIG_PATH}: {exc}"


def _dot_get(data, path):
    cur = data
    for part in path.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return None
    return cur


def _dot_set(data, path, value):
    parts = path.split(".")
    cur = data
    for part in parts[:-1]:
        if not isinstance(cur, dict):
            return False
        cur = cur.setdefault(part, {})
    if isinstance(cur, dict):
        cur[parts[-1]] = value
        return True
    return False


def cmd_config(args):
    root = _in_repo_root()
    if root is None:
        return {"ok": False, "error": "not in a .bestest project root"}
    data, err = _load_config()
    if err:
        return {"ok": False, "error": err}

    if args.action == "validate":
        # schemaVersion / version presence checks per config-schema.md
        issues = []
        if "framework" not in data:
            issues.append("missing required field: framework")
        if "version" not in data:
            issues.append("missing top-level version field")
        return {
            "ok": len(issues) == 0,
            "valid": len(issues) == 0,
            "issues": issues,
            "version": data.get("version"),
            "framework": data.get("framework"),
        }

    if args.action == "read":
        value = _dot_get(data, args.path)
        return {"ok": True, "path": args.path, "value": value}

    if args.action == "write":
        if args.value is None:
            return {"ok": False, "error": "value required for write"}
        if not _dot_set(data, args.path, args.value):
            return {"ok": False, "error": f"cannot set path {args.path}"}
        _atomic_write(os.path.join(root, CONFIG_PATH), yaml_dump(data))
        return {"ok": True, "path": args.path, "value": args.value}

    return {"ok": False, "error": f"unknown config action: {args.action}"}


# ═══════════════════════════════════════════════════════════════════════
# Reports
# ═══════════════════════════════════════════════════════════════════════

def _is_companion(report):
    return "companionTo" in report or report.get("suiteFilter") == "generated"


def cmd_report(args):
    root = _in_repo_root()
    if root is None:
        return {"ok": False, "error": "not in a .bestest project root"}
    reports_dir = os.path.join(root, ".bestest/reports")
    kind = args.kind or "*"
    pattern = os.path.join(reports_dir, f"{kind}-*.json")
    if not os.path.isdir(reports_dir):
        return {"ok": True, "reports": [], "count": 0}

    matches = []
    for name in sorted(os.listdir(reports_dir)):
        if not name.startswith(f"{kind}-") or not name.endswith(".json"):
            continue
        if kind != "*" and not name.startswith(f"{kind}-"):
            continue
        try:
            data = json.loads(_read_file(os.path.join(reports_dir, name)))
        except (ValueError, OSError):
            continue
        matches.append({"file": name, "path": os.path.join(reports_dir, name), "data": data})

    matches.sort(key=lambda m: m["file"], reverse=True)

    if args.latest:
        return {"ok": True, "latest": matches[0] if matches else None, "count": len(matches)}

    return {"ok": True, "reports": matches, "count": len(matches)}


def cmd_report_latest_full(args):
    """Priority chain from data-source-discovery.md: non-companion run → scan → companion run."""
    root = _in_repo_root()
    if root is None:
        return {"ok": False, "error": "not in a .bestest project root"}
    reports_dir = os.path.join(root, ".bestest/reports")
    if not os.path.isdir(reports_dir):
        return {"ok": True, "source": None}

    def load(kind):
        out = []
        for name in sorted(os.listdir(reports_dir)):
            if not name.startswith(f"{kind}-") or not name.endswith(".json"):
                continue
            try:
                out.append((name, json.loads(_read_file(os.path.join(reports_dir, name)))))
            except (ValueError, OSError):
                continue
        out.sort(key=lambda t: t[0], reverse=True)
        return out

    full_runs = [t for t in load("run") if not _is_companion(t[1])]
    if full_runs:
        name, data = full_runs[0]
        return {"ok": True, "source": "run-report", "file": name, "data": data}

    scans = load("scan")
    if scans:
        name, data = scans[0]
        return {"ok": True, "source": "scan-report", "file": name, "data": data}

    companions = [t for t in load("run") if _is_companion(t[1])]
    if companions:
        name, data = companions[0]
        return {"ok": True, "source": "run-report-companion", "file": name, "data": data}

    return {"ok": True, "source": None}


# ═══════════════════════════════════════════════════════════════════════
# Metrics
# ═══════════════════════════════════════════════════════════════════════

def cmd_metrics(args):
    root = _in_repo_root()
    if root is None:
        return {"ok": False, "error": "not in a .bestest project root"}
    path = os.path.join(root, METRICS_PATH)

    if args.action == "read":
        if not os.path.exists(path):
            return {"ok": True, "exists": False, "metrics": None}
        try:
            return {"ok": True, "exists": True, "metrics": json.loads(_read_file(path))}
        except ValueError as exc:
            return {"ok": False, "error": f"metrics.json corrupt: {exc}"}

    if args.action == "merge":
        # merge a spoke JSON payload into the store under a section key
        section = args.section
        payload_path = args.json_file
        if not os.path.exists(path):
            store = {"schemaVersion": "1.0", "lastUpdated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
        else:
            try:
                store = json.loads(_read_file(path))
            except ValueError:
                store = {"schemaVersion": "1.0", "lastUpdated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
        try:
            payload = json.loads(_read_file(payload_path))
        except (ValueError, OSError) as exc:
            return {"ok": False, "error": f"cannot read payload: {exc}"}
        store[section] = payload
        store["lastUpdated"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        _atomic_write(path, json.dumps(store, indent=2) + "\n")
        return {"ok": True, "section": section}

    return {"ok": False, "error": f"unknown metrics action: {args.action}"}


# ═══════════════════════════════════════════════════════════════════════
# Detect (lightweight)
# ═══════════════════════════════════════════════════════════════════════

def cmd_detect(args):
    """Run a small, deterministic detection pass and emit a StackProfile.
    This is a lighter-weight version of detection-engine.md Phase 1 — spokes
    use it for the language/toolchain signal scan, then enrich with the full
    decision tree for framework recommendation."""
    root = _in_repo_root()
    signals = []

    def add(category, name, confidence, evidence):
        signals.append({"category": category, "signal": name, "confidence": confidence, "evidence": evidence})

    languages = []
    if os.path.exists("tsconfig.json") or os.path.exists("package.json"):
        pkg = None
        try:
            pkg = json.loads(_read_file("package.json"))
        except (ValueError, OSError):
            pass
        if pkg:
            deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
            if deps.get("typescript") or os.path.exists("tsconfig.json"):
                languages.append({"name": "typescript", "confidence": 0.95,
                                  "evidence": ["tsconfig.json", "package.json → devDependencies.typescript"]})
            else:
                languages.append({"name": "javascript", "confidence": 0.8,
                                  "evidence": ["package.json"]})
    if os.path.exists("pyproject.toml") or os.path.exists("requirements.txt") or os.path.exists("setup.py"):
        languages.append({"name": "python", "confidence": 0.9,
                          "evidence": ["pyproject.toml" if os.path.exists("pyproject.toml") else "requirements.txt"]})
    if os.path.exists("go.mod"):
        languages.append({"name": "go", "confidence": 0.95, "evidence": ["go.mod"]})
    if os.path.exists("pom.xml") or os.path.exists("build.gradle") or os.path.exists("build.gradle.kts"):
        languages.append({"name": "java", "confidence": 0.9,
                          "evidence": ["pom.xml" if os.path.exists("pom.xml") else "build.gradle"]})

    languages.sort(key=lambda l: l["confidence"], reverse=True)

    test_frameworks = []
    if os.path.exists("package.json"):
        pkg = json.loads(_read_file("package.json")) if os.path.exists("package.json") else {}
        deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
        for fw in ("vitest", "jest", "mocha", "jasmine"):
            if fw in deps:
                test_frameworks.append(fw)
    if os.path.exists("requirements.txt") and "pytest" in _read_file("requirements.txt"):
        test_frameworks.append("pytest")
    if os.path.exists("go.mod") and "testify" in _read_file("go.mod"):
        test_frameworks.append("testify")

    profile = {
        "schemaVersion": "1.3",
        "languages": languages,
        "testFrameworks": {"existing": test_frameworks or None},
        "buildTool": "unknown",
    }
    if languages:
        profile["selectedLanguage"] = languages[0]["name"]

    result = {
        "ok": True,
        "schemaVersion": "1.3",
        "languages": languages,
        "testFrameworks": {"existing": test_frameworks or None},
        "signals": signals,
    }
    return result


# ═══════════════════════════════════════════════════════════════════════
# Render
# ═══════════════════════════════════════════════════════════════════════

def cmd_render(args):
    template_path = args.template_path
    if not os.path.exists(template_path):
        return {"ok": False, "error": f"template not found: {template_path}"}
    try:
        params = json.loads(args.json_params)
    except ValueError:
        return {"ok": False, "error": "params must be a JSON object"}

    content = _read_file(template_path)
    rendered = re.sub(r"\{\{(\w+)\}\}", lambda m: str(params.get(m.group(1), m.group(0))), content)
    return {"ok": True, "rendered": rendered}


# ═══════════════════════════════════════════════════════════════════════
# Contracts
# ═══════════════════════════════════════════════════════════════════════

def cmd_contracts(args):
    script = os.path.join(REPO_ROOT, "scripts", "validate-contracts.sh")
    if not os.path.exists(script):
        return {"ok": False, "error": "validate-contracts.sh not found"}
    env = dict(os.environ)
    env["SKILL_DIR"] = REPO_ROOT
    proc = subprocess.run(["bash", script], capture_output=True, text=True, env=env)
    return {"ok": proc.returncode == 0, "exit_code": proc.returncode,
            "output": proc.stdout + proc.stderr}


# ═══════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════

def _emit(result, human=False):
    if human:
        print(json.dumps(result, indent=2, default=str))
        return
    print(json.dumps(result, default=str))
    if not result.get("ok", True):
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(prog="bestest-cli", description="Deterministic helper layer for bestest")
    parser.add_argument("--human", action="store_true", help="pretty-print output")
    sub = parser.add_subparsers(dest="command", required=True)

    p_detect = sub.add_parser("detect")
    p_detect.add_argument("--phase", type=int, default=1)
    p_detect.set_defaults(func=cmd_detect)

    p_config = sub.add_parser("config")
    p_config.add_argument("action", choices=["validate", "read", "write"])
    p_config.add_argument("path", nargs="?", default=None)
    p_config.add_argument("value", nargs="?", default=None)
    p_config.set_defaults(func=cmd_config)

    p_report = sub.add_parser("report")
    p_report.add_argument("action", choices=["list", "latest-full"])
    p_report.add_argument("--kind", default=None)
    p_report.add_argument("--latest", action="store_true")
    p_report.set_defaults(func=None)

    p_lock = sub.add_parser("lock")
    p_lock.add_argument("action", choices=["acquire", "release"])
    p_lock.add_argument("name")
    p_lock.add_argument("--timeout", type=int, default=5)
    p_lock.set_defaults(func=None)

    p_metrics = sub.add_parser("metrics")
    p_metrics.add_argument("action", choices=["read", "merge"])
    p_metrics.add_argument("section", nargs="?", default=None)
    p_metrics.add_argument("json_file", nargs="?", default=None)
    p_metrics.set_defaults(func=None)

    p_render = sub.add_parser("render")
    p_render.add_argument("template_path")
    p_render.add_argument("json_params")
    p_render.set_defaults(func=None)

    p_contracts = sub.add_parser("contracts")
    p_contracts.add_argument("check", nargs="?", default="check")
    p_contracts.set_defaults(func=None)

    args = parser.parse_args()

    human = args.human

    if args.command == "detect":
        _emit(cmd_detect(args), human)
    elif args.command == "config":
        _emit(cmd_config(args), human)
    elif args.command == "report":
        if args.action == "latest-full":
            _emit(cmd_report_latest_full(args), human)
        else:
            _emit(cmd_report(args), human)
    elif args.command == "lock":
        if args.action == "acquire":
            _emit(lock_acquire(args.name, args.timeout), human)
        else:
            _emit(lock_release(args.name), human)
    elif args.command == "metrics":
        _emit(cmd_metrics(args), human)
    elif args.command == "render":
        _emit(cmd_render(args), human)
    elif args.command == "contracts":
        _emit(cmd_contracts(args), human)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
