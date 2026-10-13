# Feishu

**This workspace keeps its research memory in Feishu (飞书), not Notion.** Wherever a rule names Notion, `ntn`, or a page, database, or property, do what this file says; skip what fits only Notion.

| Item | Value |
|---|---|
| CLI | `lark-cli`, with `--as user` on every command |
| Wiki space | `<space name>`: `<space_id>`, or `my_library` |

## Where things live

| In Notion | In Feishu |
|---|---|
| The project page | A wiki doc named after the project, with the same sections |
| The Ideas, Experiments, and Findings databases | Tables of those names in the Base `<project> Knowledge Base`, a child of the project doc |
| An entry | A record for its properties, and a doc for its page, titled like it, under the parent doc `Ideas`, `Experiments`, or `Findings` of the project doc |
| The Literature Library page and its Papers database | A wiki doc `Literature Library` with the admission rules; its child Base `Papers` with a table `Papers`; its child doc `Papers`, parent of the paper docs |

## Fields

The tables have the Notion databases' fields and options, with the same English names, except: Related and @mentions between records are the link fields `Related Ideas`, `Related Experiments`, and `Related Findings`, and anything outside the Base, such as a paper, goes in the text field `Related Links`; `Idea` is a one-way link field to Ideas; and the URL field `Page` holds the entry's doc.

## Doing what a skill asks

| In Notion | In Feishu |
|---|---|
| `ntn` | `lark-cli`, its usage looked up live from `lark-cli --help`; run every command with `< /dev/null` |
| `docs/notion/ids.md` | `docs/feishu/ids.md`; if it is missing, find the IDs by exact title with `base +title-resolve` and the wiki node list, and record them there |
| Query a database | `base +record-list` with a filter |
| Create a page from a template | Create the record, then its doc under the parent doc, titled like it, callout first; then set the record's `Page` |
| A page's properties | Not in the doc: the callout's decide line names the record's table and ID and links the Base, where the user ticks Human Approved or sets Status |
| A callout | `<callout emoji="<the template's icon>" background-color="light-gray">` for 📋, `light-blue` for 💡, with its title as a bold first `<p>`; it holds only `<p>`, `<ul>`, and `<ol>`. Rewrite it in place with `block_replace` |
| Read or write a page's sections | `docs +fetch --detail full` reads the doc with its styles and block IDs; `docs +update` changes blocks |
| Write a part at its place | `docs +update --command block_insert_after --block-id <the previous part's last block>`, or `append` for the last part |
| A `\n` between points in a table cell | One `<p>` per point inside the `<td>` |
| @mention a page | In a doc, `<cite type="doc">`; between records, the link fields |
| Review colors, table cells included | `docs +fetch --detail full` gives each text's colors in RGB, the marks below. A field has no color: the user reviews its value in the doc or in a comment |
| Rewritten text, without its mark | `docs +update --command block_replace` on its block: `str_replace` keeps the old color |
| Add a figure | `<img path="<file>.png"/>` in a `docs +update`, the path relative to the working directory; to replace it, `block_replace` its image block |
| `"time_zone"` on a date property | The date-time in ISO 8601 with the offset of `TZ` |

| Mark | Text color | Background, dark or light |
|---|---|---|
| Red | `rgb(216,57,49)` | `rgb(247,105,100)`, `rgb(251,191,188)` |
| Orange | `rgb(222,120,2)` | `rgb(255,165,61)`, `rgba(254,212,164,0.8)` |
| Purple | `rgb(100,37,208)` | `rgba(147,90,246,0.55)`, `rgba(205,178,250,0.7)` |

- Feishu applies a write a moment later: wait briefly before reading it back.
- Deleting anything, transferring ownership, and changing who may see or edit a doc, Base, or space are high-risk writes: do each only after the user confirms that one operation; the login's scopes do not stop them. When `lark-cli` exits with code 10 for a high-risk write, stop and ask the user. Pass `--yes` only for the one operation they have just confirmed, never on your own.
- Never print, copy, or pass on the app secret or a token.
