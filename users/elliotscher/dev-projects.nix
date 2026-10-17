# Which devshell flake under dev/ each development project uses, so VS Code
# and the JetBrains IDEs (through their direnv plugins) get the same
# environment `nix develop` would give a terminal.
#
# Projects are identified by their git remote ("owner/repo", any URL form,
# case-insensitive) - never by path - so a project can be moved or renamed
# anywhere under `searchRoot` without touching this file. `rebuild` finds each
# one before switching and fails if a project is missing or cloned twice; the
# nixhubEnvrcs activation step in home.nix then writes `use nixhub <flake>`
# into each project's (globally git-ignored) .envrc.
#
# Optional per project: `shell = "<attr>";` picks a non-default devShell.
{
  searchRoot = "/home/elliotscher/Documents";

  projects = {
    "ElliotScher/WPI-RBE-4701" = { flake = "WPI/RBE_4701"; };
    "ElliotScher/WPI-RBE-4540" = { flake = "WPI/RBE_4540"; };
    "ElliotScher/WPI-RBE-4540-FinalProject" = { flake = "WPI/RBE_4540"; };
    "ElliotScher/WPI-Acadia-AI-E26" = { flake = "WPI/Acadia_AI_E26"; };
    "ElliotScher/Metrology" = { flake = "Personal/Metrology"; };
    "ElliotScher/Portfolio" = { flake = "Personal/Portfolio"; };
    "jhlee0409/claude-code-history-viewer" = { flake = "Personal/Claude_Code_History_Viewer"; };
    "ElliotScher/CodeCoach" = { flake = "FRC/CodeCoach"; };
    "Team-190/190-Software-Knowledge-Base" = { flake = "FRC/FRC_190/190_Software_Knowledge_Base"; };
    # build.gradle's Java toolchain asks for languageVersion 25.
    "Team-190/GompeiLib" = { flake = "FRC/FRC_190/Robot_Code"; shell = "systemcore"; };
    # GradleRIO 2026, source/target Java 17.
    "Team-190/XRP-Training-Base" = { flake = "FRC/FRC_190/Robot_Code"; shell = "roborio"; };
    "Team-190/GompeiVision" = { flake = "FRC/FRC_190/GompeiVision"; };
    "ElliotScher/Micnote" = { flake = "Personal/Micnote"; };
    # 2k26-Robot-Code / 2k26-SystemCore-Alpha deliberately stay on the
    # code-frc-* launchers in home.nix (per-profile JDK handling).
  };
}
