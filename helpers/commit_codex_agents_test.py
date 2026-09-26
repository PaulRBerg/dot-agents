import os
import subprocess
from pathlib import Path

import pytest


@pytest.fixture(
    params=[
        (".codex", "AGENTS.md", "commit_codex_agents.sh"),
        (".claude", "CLAUDE.md", "commit_claude_repo.sh"),
    ]
)
def target(request):
    return request.param


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


def fixture(tmp_path: Path, target) -> tuple[Path, Path]:
    caller_repo = tmp_path / "caller"
    target_repo = tmp_path / target[0]
    init_repo(caller_repo)
    init_repo(target_repo)

    (caller_repo / "AGENTS.md").write_text("old instructions\n")
    commit_all(caller_repo, "Initialize caller fixture")
    (target_repo / target[1]).write_text("old instructions\n")
    (target_repo / "foreign.txt").write_text("base\n")
    commit_all(target_repo, "Initialize target fixture")
    return caller_repo, target_repo


def helper_env(tmp_path: Path) -> dict[str, str]:
    binary_dir = tmp_path / "bin"
    binary_dir.mkdir(exist_ok=True)
    environment = os.environ.copy()
    environment["HOME"] = str(tmp_path)
    environment["AI_COMMIT_STATE_DIR"] = str(tmp_path / "ai-commit-state")
    environment["PATH"] = f"{binary_dir}:{environment['PATH']}"
    return environment


def run_helper(
    caller_repo: Path,
    environment: dict[str, str],
    target,
    source: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    command = ["bash", str(Path(__file__).with_name(target[2]))]
    if source is not None:
        command.append(str(source))
    return subprocess.run(
        command,
        capture_output=True,
        cwd=caller_repo,
        env=environment,
        text=True,
    )


def test_ignores_calling_repositories_git_environment(tmp_path: Path, target) -> None:
    caller_repo, target_repo = fixture(tmp_path, target)
    agents_file = caller_repo / "AGENTS.md"
    agents_file.write_text("new instructions\n")

    alternate_index = tmp_path / "caller.index"
    environment = helper_env(tmp_path)
    environment["GIT_INDEX_FILE"] = str(alternate_index)
    git(caller_repo, "read-tree", "HEAD", env=environment)

    result = run_helper(caller_repo, environment, target)

    assert result.returncode == 0, result.stderr
    assert git(target_repo, "show", f"HEAD:{target[1]}") == "new instructions"


def test_commits_agents_only_with_other_dirty_and_staged_paths(tmp_path: Path, target) -> None:
    caller_repo, target_repo = fixture(tmp_path, target)
    agents_file = caller_repo / "AGENTS.md"
    foreign_file = target_repo / "foreign.txt"
    agents_file.write_text("new instructions\n")
    foreign_file.write_text("staged change\n")
    git(target_repo, "add", "foreign.txt")
    foreign_file.write_text("unstaged change\n")
    staged_diff_before = git(target_repo, "diff", "--cached", "--", "foreign.txt")
    unstaged_diff_before = git(target_repo, "diff", "--", "foreign.txt")

    result = run_helper(caller_repo, helper_env(tmp_path), target)

    assert result.returncode == 0, result.stderr
    assert git(target_repo, "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD") == target[1]
    assert git(target_repo, "show", f"HEAD:{target[1]}") == "new instructions"
    assert foreign_file.read_text() == "unstaged change\n"
    assert git(target_repo, "show", ":foreign.txt") == "staged change"
    assert git(target_repo, "diff", "--cached", "--", "foreign.txt") == staged_diff_before
    assert git(target_repo, "diff", "--", "foreign.txt") == unstaged_diff_before


def test_noops_when_generated_path_matches_head(tmp_path: Path, target) -> None:
    caller_repo, target_repo = fixture(tmp_path, target)
    head_before = git(target_repo, "rev-parse", "HEAD")

    result = run_helper(caller_repo, helper_env(tmp_path), target)

    assert result.returncode == 0, result.stderr
    assert git(target_repo, "rev-parse", "HEAD") == head_before


def fake_ai_commit(tmp_path: Path, source: str) -> Path:
    binary_dir = tmp_path / "bin"
    binary_dir.mkdir(exist_ok=True)
    binary = binary_dir / "ai-commit"
    binary.write_text(source)
    binary.chmod(0o755)
    return binary_dir


def test_fails_on_malformed_prepare_porcelain(tmp_path: Path, target) -> None:
    caller_repo, target_repo = fixture(tmp_path, target)
    (caller_repo / "AGENTS.md").write_text("new instructions\n")
    binary_dir = fake_ai_commit(tmp_path, "#!/bin/sh\nprintf 'PREPARED\\tinvalid\\n'\n")
    environment = helper_env(tmp_path)
    environment["PATH"] = f"{binary_dir}:{environment['PATH']}"

    result = run_helper(caller_repo, environment, target)

    assert result.returncode != 0
    assert "malformed transaction ID" in result.stderr
    assert git(target_repo, "show", f"HEAD:{target[1]}") == "old instructions"


def test_fails_when_ai_commit_prepare_fails(tmp_path: Path, target) -> None:
    caller_repo, target_repo = fixture(tmp_path, target)
    (caller_repo / "AGENTS.md").write_text("new instructions\n")
    binary_dir = fake_ai_commit(tmp_path, "#!/bin/sh\necho prepare failure >&2\nexit 73\n")
    environment = helper_env(tmp_path)
    environment["PATH"] = f"{binary_dir}:{environment['PATH']}"

    result = run_helper(caller_repo, environment, target)

    assert result.returncode != 0
    assert "ai-commit prepare failed" in result.stderr
    assert git(target_repo, "show", f"HEAD:{target[1]}") == "old instructions"


def test_supplied_source_is_authoritative_over_physical_agents_file(tmp_path: Path, target) -> None:
    caller_repo, target_repo = fixture(tmp_path, target)
    physical_agents = caller_repo / "AGENTS.md"
    physical_agents.write_text("physical baseline and concurrent work\n")
    snapshot_agents = tmp_path / "hook-worktree" / "AGENTS.md"
    snapshot_agents.parent.mkdir()
    snapshot_agents.write_text("prepared snapshot instructions\n")

    result = run_helper(caller_repo, helper_env(tmp_path), target, snapshot_agents)

    assert result.returncode == 0, result.stderr
    assert git(target_repo, "show", f"HEAD:{target[1]}") == "prepared snapshot instructions"
    assert physical_agents.read_text() == "physical baseline and concurrent work\n"
