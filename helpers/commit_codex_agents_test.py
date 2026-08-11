import os
import subprocess
from pathlib import Path


SCRIPT = Path(__file__).with_name("commit_codex_agents.sh")


def git(repo: Path, *args: str, env: dict[str, str] | None = None) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        env=env,
        text=True,
    )
    return result.stdout.strip()


def init_repo(repo: Path) -> None:
    repo.mkdir()
    git(repo, "init", "--quiet")
    git(repo, "config", "user.email", "test@example.com")
    git(repo, "config", "user.name", "Test User")


def commit_all(repo: Path, message: str) -> None:
    git(repo, "add", ".")
    git(repo, "commit", "--quiet", "-m", message)


def fixture(tmp_path: Path) -> tuple[Path, Path]:
    caller_repo = tmp_path / "caller"
    codex_repo = tmp_path / ".codex"
    init_repo(caller_repo)
    init_repo(codex_repo)

    (caller_repo / "AGENTS.md").write_text("old instructions\n")
    commit_all(caller_repo, "Initialize caller fixture")
    (codex_repo / "AGENTS.md").write_text("old instructions\n")
    (codex_repo / "foreign.txt").write_text("base\n")
    commit_all(codex_repo, "Initialize Codex fixture")
    return caller_repo, codex_repo


def helper_env(tmp_path: Path) -> dict[str, str]:
    binary_dir = tmp_path / "bin"
    binary_dir.mkdir(exist_ok=True)
    just = binary_dir / "just"
    just.write_text(
        "#!/bin/sh\n"
        "set -eu\n"
        "test \"$1\" = --justfile\n"
        "test \"$2\" = \"$HOME/.codex/justfile\"\n"
        "test \"$3\" = build\n"
        "test \"$#\" -eq 4\n"
        "cp -- \"$4\" \"$HOME/.codex/AGENTS.md\"\n"
    )
    just.chmod(0o755)
    environment = os.environ.copy()
    environment["HOME"] = str(tmp_path)
    environment["AI_COMMIT_STATE_DIR"] = str(tmp_path / "ai-commit-state")
    environment["AI_COMMIT_CONFIG"] = str(tmp_path / "ai-commit-config.toml")
    environment["PATH"] = f"{binary_dir}:{environment['PATH']}"
    return environment


def run_helper(
    caller_repo: Path,
    environment: dict[str, str],
    source: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    command = ["bash", str(SCRIPT)]
    if source is not None:
        command.append(str(source))
    return subprocess.run(
        command,
        capture_output=True,
        cwd=caller_repo,
        env=environment,
        text=True,
    )


def test_ignores_calling_repositories_git_environment(tmp_path: Path) -> None:
    caller_repo, codex_repo = fixture(tmp_path)
    agents_file = caller_repo / "AGENTS.md"
    agents_file.write_text("new instructions\n")

    alternate_index = tmp_path / "caller.index"
    environment = helper_env(tmp_path)
    environment["GIT_INDEX_FILE"] = str(alternate_index)
    git(caller_repo, "read-tree", "HEAD", env=environment)

    result = run_helper(caller_repo, environment)

    assert result.returncode == 0, result.stderr
    assert git(codex_repo, "show", "HEAD:AGENTS.md") == "new instructions"


def test_commits_agents_only_with_other_dirty_and_staged_paths(tmp_path: Path) -> None:
    caller_repo, codex_repo = fixture(tmp_path)
    agents_file = caller_repo / "AGENTS.md"
    foreign_file = codex_repo / "foreign.txt"
    agents_file.write_text("new instructions\n")
    foreign_file.write_text("staged change\n")
    git(codex_repo, "add", "foreign.txt")
    foreign_file.write_text("unstaged change\n")
    staged_diff_before = git(codex_repo, "diff", "--cached", "--", "foreign.txt")
    unstaged_diff_before = git(codex_repo, "diff", "--", "foreign.txt")

    result = run_helper(caller_repo, helper_env(tmp_path))

    assert result.returncode == 0, result.stderr
    assert git(codex_repo, "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD") == "AGENTS.md"
    assert git(codex_repo, "show", "HEAD:AGENTS.md") == "new instructions"
    assert foreign_file.read_text() == "unstaged change\n"
    assert git(codex_repo, "show", ":foreign.txt") == "staged change"
    assert git(codex_repo, "diff", "--cached", "--", "foreign.txt") == staged_diff_before
    assert git(codex_repo, "diff", "--", "foreign.txt") == unstaged_diff_before


def test_noops_when_generated_path_matches_head(tmp_path: Path) -> None:
    caller_repo, codex_repo = fixture(tmp_path)
    head_before = git(codex_repo, "rev-parse", "HEAD")

    result = run_helper(caller_repo, helper_env(tmp_path))

    assert result.returncode == 0, result.stderr
    assert git(codex_repo, "rev-parse", "HEAD") == head_before


def fake_ai_commit(tmp_path: Path, source: str) -> Path:
    binary_dir = tmp_path / "bin"
    binary_dir.mkdir(exist_ok=True)
    binary = binary_dir / "ai-commit"
    binary.write_text(source)
    binary.chmod(0o755)
    return binary_dir


def test_fails_on_malformed_prepare_porcelain(tmp_path: Path) -> None:
    caller_repo, codex_repo = fixture(tmp_path)
    (caller_repo / "AGENTS.md").write_text("new instructions\n")
    binary_dir = fake_ai_commit(tmp_path, "#!/bin/sh\nprintf 'PREPARED\\tinvalid\\n'\n")
    environment = helper_env(tmp_path)
    environment["PATH"] = f"{binary_dir}:{environment['PATH']}"

    result = run_helper(caller_repo, environment)

    assert result.returncode != 0
    assert "malformed transaction ID" in result.stderr
    assert git(codex_repo, "show", "HEAD:AGENTS.md") == "old instructions"


def test_fails_when_ai_commit_prepare_fails(tmp_path: Path) -> None:
    caller_repo, codex_repo = fixture(tmp_path)
    (caller_repo / "AGENTS.md").write_text("new instructions\n")
    binary_dir = fake_ai_commit(tmp_path, "#!/bin/sh\necho prepare failure >&2\nexit 73\n")
    environment = helper_env(tmp_path)
    environment["PATH"] = f"{binary_dir}:{environment['PATH']}"

    result = run_helper(caller_repo, environment)

    assert result.returncode != 0
    assert "ai-commit prepare failed" in result.stderr
    assert git(codex_repo, "show", "HEAD:AGENTS.md") == "old instructions"


def test_supplied_source_is_authoritative_over_physical_agents_file(tmp_path: Path) -> None:
    caller_repo, codex_repo = fixture(tmp_path)
    physical_agents = caller_repo / "AGENTS.md"
    physical_agents.write_text("physical baseline and concurrent work\n")
    snapshot_agents = tmp_path / "hook-worktree" / "AGENTS.md"
    snapshot_agents.parent.mkdir()
    snapshot_agents.write_text("prepared snapshot instructions\n")

    result = run_helper(caller_repo, helper_env(tmp_path), snapshot_agents)

    assert result.returncode == 0, result.stderr
    assert git(codex_repo, "show", "HEAD:AGENTS.md") == "prepared snapshot instructions"
    assert physical_agents.read_text() == "physical baseline and concurrent work\n"
