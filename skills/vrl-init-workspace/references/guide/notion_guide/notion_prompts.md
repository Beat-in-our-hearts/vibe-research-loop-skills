# Notion prompts

Prompts for AI coding agents that set up or change the Notion side of the research loop, one per section. When the user asks for a section's task, follow its steps in order, and follow [`operations.md`](operations.md) throughout.

## Set up Notion

Build what [`overview.md`](overview.md) and [`databases.md`](databases.md) describe, with the names this guide uses. Never overwrite an existing page: if one with the same title exists, show it to the user and ask, unless a step below says to reuse it.

1. **Connection.** Check that the `ntn` CLI reaches the user's Notion workspace. If it is missing or not logged in, ask the user to install it and log in themselves; never handle their token.
2. **Project.** Ask the user for the project's name and its research question, and wait for the answer; the rest of the Research Core can stay empty for them to fill in later.
3. **Literature Library.** Search the Notion workspace for a top-level page titled exactly "Literature Library", reading every page of results, since search also returns partial matches. If there is none, create it at the top level with the admission rules and an inline Papers database; if there is one, reuse it without asking, since every project shares it.
4. **Project page.** Search the same way for a top-level page titled exactly the project's name. If there is none, create it with the Research Core, the loop diagram and its legend from [`research-loop.md`](research-loop.md), and the Knowledge Base holding the Ideas, Experiments, and Findings databases, each with the properties, relations, formula, and views in [`databases.md`](databases.md). If there is one, show it to the user and ask whether to reuse it; if they agree, add only what it lacks, such as a research question still left as a placeholder, and leave the rest as it is.
5. **Templates.** For each of the four databases that has no template yet, ask the user to create an empty one in the Notion app (New ▾ → + New template), since the API cannot, and wait. Then fill each new template from [`templates/`](templates/): the body below the line, and the default properties. Leave a template that already exists as it is, and report where it differs from its file.
6. **Human steps.** Ask the user to make each template the default of its database, where it is not yet; to turn on Full width in each of the four databases (⋯ → Customize layout → Page settings → Full width), which widens every page in it, existing and new, since the API cannot; and to set their Notion time zone to the project's, the `TZ` in the workspace's `.env`, all in the Notion app.
7. **Check and report.** Read back every page, database, view, and template, and compare them with this guide. Compare a template by its blocks and their inline styles, not by its markdown export, which splits italic text around inline code into pieces that read as `**…**`. Report in a table what you created, what you reused, and what the user still has to do, such as a research question that is still empty.

## Add a machine

Use this on another machine of a workspace whose Notion is already set up: do step 1 of "Set up Notion" on this machine.
