# Feishu

**This workspace keeps its research memory in Feishu (飞书), not in Notion.** Wherever a skill or a rule names Notion, `ntn`, a page, a database, or a property, do what this file says instead; a rule that only makes sense in Notion, such as Full width, does not apply.

| Item | Value |
|---|---|
| CLI | `lark-cli`, brand `feishu`, always as the user: `--as user` on every command |
| Wiki space | `<space name>`: `<space_id>`, or `my_library` |
| IDs | `docs/feishu/ids.md` |
| Time zone | The `TZ` of `.env`; each Base has it as its time zone |

## Where things live

| In Notion | In Feishu |
|---|---|
| The project page: Research Core and Direction Log | A wiki doc titled with the project's name, with the same sections in its body |
| The Ideas, Experiments, and Findings databases | Tables of those names in one Base, `<project> Knowledge Base`, a child node of the project doc |
| An entry: its properties and its page | A record for the properties, and a doc for the body: a child of the parent doc `Ideas`, `Experiments`, or `Findings` under the project doc, titled like the record. The record's `Page` field holds the doc's URL |
| The Literature Library page and its Papers database | A wiki doc `Literature Library` holding the admission rules; its child Base `Papers` with a table `Papers`; and a parent doc `Papers` for the paper docs |

## Fields

The tables have the fields and options of the Notion databases, with the same English names, except:

| In Notion | In Feishu |
|---|---|
| Status, a status property | A single select with the same options; its to-do, in-progress, and complete groups exist only in the guide |
| Related, a text property of @mentions | Link fields to the tables of the same Base: `Related Ideas`, `Related Experiments`, `Related Findings`; a paper, or anything else outside the Base, goes in `Related Links`, a text field of links |
| Idea, a one-way relation | `Idea`, a one-way link field to Ideas |
| Progress, a formula | The same logic as a Feishu formula: `stopped` for Failed or Invalid, a full bar for Finish, empty without Started or Est. Hours, otherwise ten characters of `█` and `░` with the percent. Feishu has no `REPT`: build the bar with `LEFT("██████████", n)` and `LEFT("░░░░░░░░░░", 10 - n)`. Take the hours as `(NOW() - [Started]) * 24`: `DAYS` returns whole days |
| A date with its time zone | A date-time field, written in ISO 8601 with the offset of `TZ` |
| — | `Page`: a URL field holding the entry's doc |

## Doing what a skill asks

| A skill says | In Feishu |
|---|---|
| Use `ntn`, and look up its usage live | Use `lark-cli`, and look up its usage live: `lark-cli --help`, `lark-cli <domain> --help`, `lark-cli schema <method>`. Prefer the shortcuts (`base +…`, `docs +…`, `wiki +…`); use `lark-cli api` for the rest. Run every command with `< /dev/null`, read the JSON `{ok, data}` it prints, and stop and ask the user when it exits with code 10, which marks a risky write |
| Take the IDs from `docs/notion/ids.md`, or find them by title | Take them from `docs/feishu/ids.md`. If it is missing, find them by exact title with `base +title-resolve` and the wiki node list, and record them there |
| Query a database | `base +record-list` with a filter on the fields |
| Create a page with its properties and its body from a template | Create the record with its fields; create its doc under the parent doc, with the record's title and only the parts filled now, the callout first; then set the record's `Page` |
| A page's properties, which Notion shows above the body | A doc does not show its record: the callout's decide line names the record's table and ID and links the Base, where the user ticks Human Approved or sets Status |
| A callout | `<callout emoji="<the template's icon>" background-color="light-gray">` for 📋, `light-blue` for 💡, with its title as a bold first `<p>`; it holds only `<p>`, `<ul>`, and `<ol>`. Rewrite it in place with `block_replace` |
| Read, write, or fill a section of a page | Edit the entry's doc: `docs +fetch --detail full` to read it with its styles and block IDs, `docs +update` to change blocks |
| Write a part when you fill it, at its place in the template | `docs +update --command block_insert_after --block-id <the last block of the part before it>`, or `append` when it comes last |
| Put several points in one table cell, a `\n` between them | One `<p>` per point inside the `<td>` |
| @mention a page | In a doc, a doc mention (`<cite type="doc">` in the CLI's XML). Between records, the link fields above |
| Read the review colors of every text, table cells included | `docs +fetch --detail full` gives each text's color and background as RGB values, in the table below. Record fields carry no color, so the user reviews a field's value in the doc, or in a comment on it |
| Write rewritten text without its mark | `docs +update --command block_replace` on the block that holds it: `str_replace` keeps the color of the text it replaces |
| Add a figure | An image in the doc, right above its caption: `<img path="<file>.png"/>` in a `docs +update`, with the path relative to the working directory. To replace a figure, such as the curves at each report, `block_replace` its image block |
| Set `"time_zone"` on a date property | Write the date-time with the offset of `TZ` |

The user's marks, as `docs +fetch --detail full` prints them; other colors are not marks:

| Mark | Text color | Background, dark or light |
|---|---|---|
| Red | `rgb(216,57,49)` | `rgb(247,105,100)`, `rgb(251,191,188)` |
| Orange | `rgb(222,120,2)` | `rgb(255,165,61)`, `rgba(254,212,164,0.8)` |
| Purple | `rgb(100,37,208)` | `rgba(147,90,246,0.55)`, `rgba(205,178,250,0.7)` |

- Feishu applies a write a moment later: read a record back after a short wait before you conclude that a write failed.
- Deleting anything, transferring ownership, and changing who may see or edit a doc, a Base, or a wiki space are high-risk writes, which `lark-cli` runs only with `--yes`. Pass `--yes` only for the one operation the user has just confirmed, never on your own; the login's scopes do not stop these writes.
- Never print, copy, or pass on the app secret or a token; `lark-cli` keeps them in the system keychain.
