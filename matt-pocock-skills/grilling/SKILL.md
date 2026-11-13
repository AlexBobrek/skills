---
name: grilling
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Every decision has an **altitude**. A **route decision** changes what the user gets, what is in scope, or the shape of the system (its parts, which part owns which data, how the parts talk, what happens on failure), or it is costly to reverse. A **leaf decision** is everything below that: an implementer can settle it alone and change it later at low cost. The user owns route decisions. You own leaf decisions: settle each with your default and list it under **Assumed**, one line each, for the user to veto. A vetoed Assumed line becomes a route decision.

Work the tree top-down, in **rounds**: who the users are and what must be true for them, then scope, then system shape. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask every route decision on the frontier in one round: number each one, put it as a scenario, and give your recommended answer. Then wait for the user's answers before the next round.

Put each route decision as a **scenario**: a concrete situation with named actors and values, then what happens under each option. The user chooses the outcome; you derive the mechanism.

Format a round like so:

```
❓ **Q1** - **<question title>**
Scenario: <a concrete situation: named actors, real values, one triggering event>
- **A**: <what the actors see happen> (<the mechanism, in one clause>)
- **B**: <what the actors see happen> (<the mechanism, in one clause>)

➡️ <your recommended option, and why>

---

❓ **Q2** - **<question title>**
Scenario: <...>
- **A**: <...>
- **B**: <...>

➡️ <your recommended option, and why>

---

🧩 **Assumed** (tell me to change one):
- <leaf decision>: <your default>
```

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _route decisions_ are the user's: put each to them and wait.

The session is done when the frontier holds no route decisions: every branch of the design tree visited, each decision either made by the user or listed under Assumed. Do not act on it until the user confirms you have reached a shared understanding.
