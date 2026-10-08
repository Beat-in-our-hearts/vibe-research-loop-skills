# Feishu prompts

Use these instead of the guide's Notion prompts when the user keeps the research memory in Feishu (飞书), the China edition; `<guide>` is the bundled guide, and `<feishu>` this folder. Build in Feishu what `<guide>/notion_guide/overview.md` and `<guide>/notion_guide/databases.md` describe, laid out and adapted as `<feishu>/docs/AGENTS/feishu.md` says. Follow that file throughout, as if it were already in the workspace.

- Keep in English the names agents look up: `Literature Library`, `Papers`, the tables, their fields and views, and the options of their selects. Write all other text, such as the Research Core's headings and the admission rules, in the language the workspace's language rules set for its pages, or else in the reply language.
- Create no templates: the research skills write each entry's doc from `<guide>/notion_guide/templates/`.
- Never overwrite an existing node: if one with the same title exists, show it to the user and ask, unless a step below says to reuse it.
- Create a doc at the top of the space with `wiki +node-create --obj-type docx`, and a child doc with `docs +create --parent-token <parent node>`. Create a Base with `base +base-create --time-zone <TZ> --table-name <first table> --fields <fields>`, which drops the default table, then move it under its node with `wiki +move --obj-type bitable`. Rename each table's default view to the first view `databases.md` lists, rather than deleting it.
- The Base `Papers` and the doc `Papers` share a title: tell them apart by their object type.

## Set up Feishu

1. **Connection.** Check that `lark-cli` is installed and logged in as the user, through the skill's `scripts/setup_clis.sh`, which installs it and runs both logins: the first registers an app for the user and the second grants it the Base, Docs, Drive, and Wiki scopes, each approved by the user in a browser. Never handle the app secret or a token.
2. **Project.** Ask the user for the project's name and its research question, and which wiki space to use: a team space they name, or their own `my_library`. Wait for the answer.
3. **Literature Library.** In that space, look for a node titled exactly `Literature Library`, reading every page of the node list. If there is none, create it: a doc with the admission rules of `overview.md`, a child Base `Papers` holding a table `Papers` with the fields and views of `databases.md`, and a child doc `Papers` that will hold one doc per paper. If there is one, reuse it without asking, since every project shares it, and add only what it lacks.
4. **Project.** Look the same way for a node titled exactly the project's name. If there is none, create it: a doc with the Research Core of `overview.md`, with these children:
   - a Base `<project> Knowledge Base` with the time zone `TZ` of `.env`, holding the tables Ideas, Experiments, and Findings, with the fields, link fields, formula, and views of `databases.md`, adapted as the rule file says;
   - the docs `Ideas`, `Experiments`, and `Findings`, which will hold one doc per entry.

   If there is one, show it to the user and ask whether to reuse it; if they agree, add only what it lacks, and leave the rest as it is.
5. **Rule file.** Write the workspace's `docs/AGENTS/feishu.md` from `<feishu>/docs/AGENTS/feishu.md`, in the working language, with the wiki space filled in. Add its row to the index in `AGENTS.md`, right after the language rules, as `| @docs/AGENTS/feishu.md | Anything in Feishu |`. Commit it as the workspace's git rules say.
6. **IDs.** Write `docs/feishu/ids.md` with the header `| Object | Title in Feishu | Node token | Object token | Table ID |`: one row each for the project doc, the Literature Library doc, the two Bases, the four parent docs, and the four tables. Put `—` in the cells that do not apply. Commit it as the workspace's git rules say.
7. **Check and report.** Read back every node, Base, table, field, and view you created or reused, and compare them with the guide and the rule file. Anything else the user keeps in Feishu is theirs and stays out of the check. Try the Progress formula on a test record, then delete that record once the user confirms it, as the rule file says for a high-risk write. Report in a table what you created, what you reused, and what the user still has to do, such as a research question that is still empty.

## Add a machine

Use this on another machine of a workspace whose Feishu is already set up: do step 1 of "Set up Feishu" on this machine, since each machine keeps its own login.
