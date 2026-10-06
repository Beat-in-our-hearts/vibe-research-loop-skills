# Notion prompts

Prompts for AI coding agents that set up or change the Notion side of the research loop, one per section. When the user asks for a section's task, follow its steps in order, and follow [`operations.md`](operations.md) throughout.

## Set up Notion

Build what [`overview.md`](overview.md) and [`databases.md`](databases.md) describe. Keep in English the names this guide gives, which agents look up: the Literature Library's title, and the names of the databases, their properties and views, and the options of their select and status properties. Write all other text, such as the Research Core's headings and the admission rules, in the language the workspace's language rules set for Notion pages, or else in the reply language. Create no templates in the databases: the research skills write each new page from [`templates/`](templates/). Never overwrite an existing page: if one with the same title exists, show it to the user and ask, unless a step below says to reuse it.

1. **Connection.** Check that the `ntn` CLI reaches the user's Notion workspace. If it is missing or not logged in, ask the user to install it and log in themselves; never handle their token.
2. **Project.** Ask the user for the project's name and its research question, and wait for the answer; the rest of the Research Core can stay empty for them to fill in later.
3. **Literature Library.** Search the Notion workspace for a top-level page titled exactly "Literature Library", reading every page of results, since search also returns partial matches. If there is none, create it at the top level with the admission rules and an inline Papers database; if there is one, reuse it without asking, since every project shares it.
4. **Project page.** Search the same way for a top-level page titled exactly the project's name. If there is none, create it with the Research Core and the Knowledge Base holding the Ideas, Experiments, and Findings databases, each with the properties, relations, formula, and views in [`databases.md`](databases.md). If there is one, show it to the user and ask whether to reuse it; if they agree, add only what it lacks, such as a research question still left as a placeholder, and leave the rest as it is.
5. **Human steps.** Ask the user to turn on Full width in each of the four databases (⋯ → Customize layout → Page settings → Full width), which widens every page in it, existing and new, since the API cannot; and to set their Notion time zone to the project's, the `TZ` in the workspace's `.env`, both in the Notion app.
6. **Check and report.** Read back the Literature Library, the project page, the four databases, and their views, and compare them with this guide; anything else the user added, on these pages or elsewhere, is theirs and stays out of the check. Report in a table what you created, what you reused, and what the user still has to do, such as a research question that is still empty.

## Add a machine

Use this on another machine of a workspace whose Notion is already set up: do step 1 of "Set up Notion" on this machine.
