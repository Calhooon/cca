# cca

Many Claude and Codex subscriptions, one pool. A Fable captain per project.
Lanes across the pool. Read `RULES.md`: it is one page and it is the design.

One Python file (`bin/cca`), no dependencies, no daemon. It launches Claude Code and the Codex CLI on whichever login
has the most room for the work, reads what they report about their own limits, and keeps a roster under `~/.cca/`.

## What you need

- macOS and its system Python (`/usr/bin/python3`, 3.9).
- Claude Code (`claude`) for Claude logins, the Codex CLI (`codex`) for ChatGPT logins. Either works alone.
- git, and ssh if a second machine joins.
- Optional: `claude-abl` for the gateway (below), and the Swift toolchain for the menu bar app.

## Set it up

Clone it into the folder that holds your projects. That folder is the workspace: cca reads the repos beside it and
builds into `<workspace>/targets`. `CCA_WORKSPACE` names another folder.

    git clone https://github.com/Calhooon/cca <workspace>/cca
    <workspace>/cca/bin/cca install      # Claude Code's statusline and hooks point at cca; PATH in ~/.zshrc
    cca selftest                         # the checks, on fixtures in a scratch state folder

`cca install` replaces `statusLine` and `hooks` in `~/.claude/settings.json` and keeps the old file beside it as
`settings.json.before-cca-install`.

## Accounts

An account is one login on one machine. An id with an `@` is a Claude login, any other id is a Codex one.

    cca add you@example.com                      # a Claude login, with its own profile under ~/.claude-profiles/
    cca login you@example.com                    # Claude Code's own sign-in, in the Chrome profile that carries that email
    cca add openai-1                             # a Codex login, with its own CODEX_HOME under ~/.codex-profiles/
    cca login openai-1                           # the Codex CLI's own sign-in
    cca role you@example.com pool                # pool (the default) or captain:<project>
    cca project add myproject ~/code/myproject
    cca doctor                                   # what is missing
    cca status                                   # every account: what is left, how old the figure is, who is on it

A login is signed in on each machine that needs it and is never copied. cca keeps no credential of its own: it reads
the login Claude Code keeps in the Keychain and the one the Codex CLI keeps in its home, and records only whether each
is live and when it expires.

## Work

    cca captain myproject                        # the project's Fable captain, in a loop that brings it back
    cca run --class code|review|design|proof "task"
                                                 # a lane on the best pool account, from the project's folder; prints its REPORT
    cca runs                                     # the lanes
    cca claude [--class C] [--account A]         # an interactive session on the picker's account
    cca pick --class C                           # where a launch would go, and why

The class picks the provider and rule 26 picks the model, or a launch names one: `--model sol|astra|opus|fable|opus48|abl`.
`--worktree NAME` gives a lane its own git worktree. A captain runs its lanes in the background and reads their reports.

Every launch skips permission prompts (`--dangerously-skip-permissions`, and the Codex equivalent). That is rule 9.
Use it only where that is acceptable.

## The three providers

- **Claude**: Claude Code, one profile per login. Captains run on Fable; a lane runs on Fable or Opus by rule 26.
- **Codex**: the Codex CLI, one `CODEX_HOME` per login. Code lanes go there first while its week has room (rule 7), and
  `code_split` sets its share.
- **The gateway**: `--model abl` runs a lane through abliteration.ai with `claude-abl`
  (https://github.com/Calgooon/claude-abl), found on `PATH` or at `~/.local/bin/claude-abl`. Prepaid credits, no pool
  account, text only. `--hazard` sends a lane to the `hazard_model` setting; it writes its output to a file and reports
  a verdict and a path (rule 18).

## More than one machine

A peer is an entry under `hosts` in `~/.cca/accounts.json` with the ssh alias that reaches it:

    "hosts": {"studio": {"node": "My-Mac"}, "box": {"ssh": "box"}}

`cca deploy` copies the tool, `RULES.md` and the roster to every peer, to the same path under the peer's home
(`peer_cca` names another). `cca add <id> --host box` and `cca login <id> --host box` sign a login in there. A lane goes
to the machine with the least load that has the project (rule 20); `--host` names one.

## Settings and disk

Settings live under `settings` in `~/.cca/accounts.json`; the defaults are `DEFAULT_SETTINGS` at the top of `bin/cca`.
State is under `~/.cca/` (roster, samples, leases, runs, captains).

When a Mac has a volume named `/Volumes/Lanes`, lane worktrees, scratch and builds go there (rule 23). Without it,
worktrees stay under the repo and builds under `<workspace>/targets`. `cca disk [--clean|--dry]` lists what the lanes
left behind, with sizes.

## The menu bar app

    app/install.sh      # builds it with swift, installs ~/Applications/Claude Accounts.app, starts it at login

It shows what `cca status` shows: what is left on each account and who is on it.

## Readings

The 5-hour and week figures come from the statusline of every live session and from each lane's stream. The Fable
half is not in either: it is only on the usage page, which Claude Code reads once when an interactive session starts
and keeps for the session, so a captain's Fable figure was as old as its launch. The tool reads the page itself, with
the login's own access token in place (the GET Claude Code makes at a session start, the one the Codex CLI makes for
its usage view; no token spent, nothing written to a login), on use and never on a timer:

- a launch reads its candidate accounts when their reading is older than `read_age_launch` (10 minutes);
- a Fable captain's hook reads the captain's own account when it is older than `read_age_captain` (30 minutes);
- the menu bar feed reads whatever it shows that is older than 10 minutes;
- `cca refresh [--all]` reads every login now, on the owner's word;
- `cca reading [--host H] [--out PATH] [--no-jscpd]` writes the fleet reading, one page of counts and paths under `~/.cca/readings/` (rule 22);
- a code lane is held to its repo's gate (`tools/gate`, or a `gate` target) before its REPORT prints; a failing gate blocks the lane (rule 21);
- an HTTP 429 backs that account off for an hour.

What one machine reads travels to its peers with every roster push and fleet pull.

## As is

One person's working tool, published as it runs. It is macOS only, and `RULES.md` names its owner and his machines
(Studio, box, mini). `cca reading` counts things in a Rust stack built on `bsv-rs` and means little elsewhere. Check
your providers' terms before you pool subscriptions. MIT license, see `LICENSE`.
