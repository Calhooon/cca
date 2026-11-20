# cca: the rules

North star: many subscriptions become one pool; every project gets its own
Fable captain; captains run lanes across the pool in parallel, on whichever
model fits the work (Codex gpt-6.1-sol or gpt-6-astra, Opus, Fable when it
takes Fable) and whichever account has the most capacity for it; the limits
never stop the work and no point goes unspent; nothing we build touches
Claude Code or Codex beyond how they are launched.

What this enables: a plan John has fully defined runs for days without him.
The captain plans, fires lanes, reads their reports, moves accounts at a wall,
waits for a reset, and keeps going. John's input is the plan and the decisions
he reserved for himself.

 1. A login is one token. It moves, never copies.
 2. An account is a Claude or Codex login on one machine: Studio, box or mini.
    The roster knows all three. Mini runs no Claude unless John flips it.
 3. Every account has a role: captain of one project, or pool.
 4. A captain is always Fable, on its own account, at xhigh effort (`captain_effort`; the
    launch line may say otherwise). Max is never used on Fable 5.2 (the owner's word,
    2026-11-09: "Max sucks for Fable 5.2, it should never be used"): a captain or a lane asked
    for it there goes at xhigh and says so. Its subagents run at xhigh: `~/.claude/agents/` holds
    the four built-in agent types with `effort: xhigh`, shared into every profile (2026-10-26).
    Nothing else launches there.
 5. When a captain's Fable is gone, it moves to the pool account with the most
    Fable left, same conversation.
 6. Lanes run on pool accounts. The captain says what kind of work a lane is
    (code, review, design, proof); that picks the provider, rule 26 picks the model, or the
    captain names one on that rule or the owner's word: `--model sol|astra|opus|fable`. The account is always
    the one with the most capacity for that model, read from what Claude Code
    and Codex report.
 7. Code lanes go to Codex first while its week is above the floor (`codex_week_floor`, 1 percent since 2026-10-18 by the owner's word `codex: floor 1`; it was 10). Among the
    accounts with room for a launch (the 5-hour window, and the Fable half or
    the week after it), non-Fable launches use the one whose week expires
    soonest, then the one with the most room: what would be lost is spent
    before what would keep. Fable launches use the most Fable points per hour
    to the week reset first, counting at least one hour. A new captain sits on
    the idle pool account with the most Fable left, ties going to the soonest
    week reset. A Fable half that expires within a day goes to any lane without a
    named model (rule 26). Nothing is stranded on purpose, on any model. Code lanes split
    between Codex and Claude by a setting (half and half unless John says otherwise).
 8. A lane that hits a wall is resumed on the next pool account, same conversation.
 9. Every launch (captain, lane, John's own) skips permissions. Always.
10. What's left is read only from what Claude Code and Codex report themselves.
    A reading is shown with its age. It is never rolled forward. A number is read from the
    usage page on use, never on a timer: a launch reads its candidates when the figure in hand
    is older than ten minutes, a Fable captain's hook its own account at thirty, the board what
    it shows at sixty (`read_age_board`); due is judged by the last read and the figures the page
    carries, never by its 5-hour window, which the page does not carry (2026-11-04: judged by the
    oldest window, the board asked every 12 s and was answered 429); a read is claimed before it
    goes out, so two looks never make two; no token is spent; a 429 or a refused login backs the
    account off an hour.
    One exception: a Codex home whose access token has expired gets a one-word exec (some 2k
    tokens, at most once an hour) so the Codex CLI renews it; nothing else runs a Codex home
    between lanes, and the stale reading would otherwise stand (2026-10-23). The other:
    `cca refresh --all` runs from the Studio's LaunchAgent at 03:00 and 15:00 (one cached
    one-word turn per login on each host), because a grant left unused on a machine for a
    day or more is refused on its next start and the box only sees lanes (2026-10-26).
    A login is read from the keychain on the launch that will use it, and when the keychain file has
    moved since the last reading; the board, the status line and the picker read the record under
    `~/.cca/logins/` (2026-11-04: the menu bar app's panel read every login 85 times a cycle and
    kept securityd at a quarter of a core).
11. A lane reports in 20 lines or fewer: done / blocked / walled, the commit,
    what is unverified, what is next. The captain reads reports, not transcripts.
12. Claude Code wakes the captain when a lane ends. No relay, no watcher, no loop.
13. No daemons. Nothing runs unless someone launched it. The tool never writes
    into a session, never ends a session John opened, never edits settings
    behind him.
14. There is no context trigger. A captain manages its own context: lanes absorb
    the tool output; a heavy captain writes its own handoff and restarts.
15. A captain's terminal is a loop John opened. If the captain exits for any
    reason but John's own Ctrl-C, the loop brings it back: resumed, or from its
    handoff. Waiting for a reset is the captain's own scheduled wake-up.
16. The board shows what is left and who is on it, per account, per project.
    Never what is used.
17. A captain opens, says where the project stands, and waits. John names the
    work. Nothing proposes work to him unasked: not a captain, not a lane's
    report, not the tool.
18. A safety stop never touches a captain. Material that stopped a model is a
    hazard: the captain never opens it; a lane that must touch it runs on a
    model John names (`--hazard`, the gateway by his setting), writes its output to a
    file, and reports a verdict and a path with no excerpt. A lane a
    classifier stops is recorded as stopped and never retried by the tool;
    John names its next model or takes it himself. The content is never
    reworded to pass; a lens judges the record. Stopped on every model, it is
    John's own hand.
19. One file of code, no more than it needs. If a rule needs a paragraph, it is wrong.

20. A lane runs on the machine with the least load that can take it. With no `--host`, a
    report-only lane or a worktree lane goes to a peer when the project is checked out
    there, a login with room is there, and its load per core (lanes counted) is lower than
    here; the sender pushes its HEAD, the lane's worktree starts at that commit, and the
    branch comes back as `<peer>/lane/<name>`. A code lane without a worktree, and a
    gateway lane, stay where they are typed. `--host` names a machine outright.

21. A code lane that says done is held to the repo's gate: an executable `tools/gate`, else a
    Makefile or justfile target named `gate`, run in the lane's own folder before its REPORT
    is printed. Pass: the head line carries the gate's time. Fail: the lane is blocked, its
    REPORT starts with the verdict and the log's path, and the captain puts the finding in the
    channel. A repo with no gate file is held to nothing new. The captain never runs a linter.

22. The fleet reading is a script, not a lane and not a clock: `cca reading` walks every
    checkout the roster knows and every top-level repo in the workspace (the folder cca's repo sits in) but archives, upstreams,
    references and worktree copies, and writes one page of counts and paths under
    `~/.cca/readings/`: crate names in more than one repo, vendored crates, path dependencies
    that leave a repo or point at nothing, each repo's pin of the stack crates, hand-rolled
    primitives outside bsv-rs, lint files per repo, jscpd when installed. It runs when someone
    types it, here or `--host box`.

23. The internal disk is not a build disk. On a Mac with the lane volume (`/Volumes/Lanes`)
    every lane and every captain builds into `<workspace>/targets/<project>-lanes` on it (a crate
    anywhere in the repo counts), scratch goes to its `tmp`, and a lane's worktree is made at
    `/Volumes/Lanes/worktrees/<repo>/<name>`; a worktree already under the repo keeps its home.
    `cca disk` lists what the lanes left behind with sizes: cargo target folders inside a
    checkout, lane worktrees by the state of their lane, scratch older than a day that no
    running lane sits in, entries under `<workspace>/targets` named for nothing that exists, and a
    checkout's own build folder (`<project>-lanes/wt-<12 hex>`, the hash of the checkout's
    path, made by one project's parity test) that no existing checkout builds into (2026-11-15:
    142 of them, 74 GB, sat in one project's lanes folder behind removed worktrees).
    `cca disk --clean` removes the safe classes only: scratch, those orphan folders once nothing
    in them changed in a day and no running lane or captain is named by them, a done lane's clean worktree
    whose work landed (its commits in main, or its PR merged) with the target folder named
    for that lane, and its own wt- folder, in the same pass (2026-10-25: 600 GB of them sat behind finished lanes until
    six captains cleared them by hand), and Chrome's code-sign clones older than a day. Nothing any process holds open is touched: two lsof reads unioned, a
    direct `lsof +D` on each scratch folder right before it goes. A clone stays when it was
    born in a running Chrome's first two minutes (Chrome makes its clone in its first seconds;
    the clones share one binary by hard link, so lsof cannot tell which one a Chrome uses). `--dry` shows what
    would go.

    The rest is the owner's or the captain's to clear, by name: `cca disk --clean --path P [--host H] [--dry]` moves one
    folder under a targets folder (`/Volumes/Lanes/targets` or `<workspace>/targets`) to the trash, where it stays two days, and logs
    it in `~/.cca/runs/disk-clean.log`. It refuses, one line and a named exit: 3 outside the roots or naming `..`, 4 a running
    lane's target, 5 held open (or lsof failed), 6 a `.cca-keep` on it, above it or anywhere below it, 7 not a folder, 8 the
    `--host` peer did not answer the `--caps` question in 30 s, is unreachable, or its cca does not know `--path` (asked first;
    nothing is sent), 9 a project's shared `<project>-lanes` folder (any casing), unless `--shared` names it. An empty `--path`,
    or a flag `--clean` does not know (a mistyped `--path`), is refused (2), as is `--json` with `--clean` and no `--path`: `--json` alone only scans. Scratch and review
    targets go under `$TMPDIR` or `<workspace>/targets`, never a literal `/tmp`, which is the
    internal disk. The fleet reading carries the same table.

24. Nothing a lane makes lands on the internal disk; everything on the lane volume has an owner and an
    expiry, and the tool enforces both: a sweep at each lane's end, and no launch under `disk_floor_gb`.
    A lane stops every server it started before its REPORT; at its end the tool ends any process still
    listening on a port that carries the lane's `CCA_RUN` (2026-10-25 02:40: one lane's leftover wrangler
    dev and two workerd held 29,000 loopback connections, the Studio ran out of ports, and git push, gh
    and cargo fetch failed for every captain until they were killed).

    2026-10-18: A captain marks a standing worktree it restores by hand with `.cca-keep` at its root.
    The marker's content is free text (a reason), never parsed. On every host, the sweep leaves any
    candidate folder with this marker alone and prints `kept (.cca-keep): <path>` for each one.

25. No lane runs on a loop host (`fleet_lock_hosts`, the box) while a fleet loop runs there: `cca run` asks the
    project's own checker (`fleet_lock_check`, `node fleet-lock.mjs check --host=box`) on the sending machine and on
    the box, and refuses by the loop's name; the picker never sends a lane there meanwhile. `cca runs --host box`
    is what a loop's launcher reads the other way; it exits 3 when the box cannot be asked.

26. The model a lane runs on is the owner's rule, never a captain's choice (John's word, 2026-10-26,
    to the bsv-wallet-cli captain: "use claude accounts that reset the soonest.. opus 5.5... if you
    have fable that resets within 24 hours.. use that first", and "opus 5.5 on claude accounts
    expiring the week soonest if no fable expiring within 24 hours"): a Claude lane runs on Fable
    on the account whose week expires soonest when one expires within 24 hours, else on Opus 5.5 on
    the Claude account whose week expires soonest; a Codex lane on the pool's Codex account. A
    captain names `--model` on a launch line only to say this rule's answer or on John's word for
    that launch (a cold review on Opus is such a word, given 2026-10-23); no captain invents a
    model policy of its own. Since 2026-11-09 the picker answers this rule itself for a lane with no
    named model, whatever its class (the owner again that day: lanes on the accounts that reset soonest,
    Fable where it expires within 24 hours). Before, review, design, proof, plan and lens lanes
    defaulted to Fable on any account, and a Fable 5.2 lane costs about half a point.
