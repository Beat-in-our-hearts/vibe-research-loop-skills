# Pages

How to read and write the pages of the research memory. Where `docs/AGENTS/feishu.md` exists, skip the Notion section: that file says what each Notion step becomes. If several projects match a title you look up, ask the user which one.

## Notion

- Use the `ntn` CLI; see `ntn --help`, `ntn api ls`, `ntn api <path> -X <method> --spec`. Always run `ntn api ... < /dev/null`.
- Take project page and database IDs from `docs/notion/ids.md`. If missing, find them by exact title with `ntn api v1/search`, reading all result pages. Record them there in columns Object, Title in Notion, Page ID, Database ID, Data source ID.
- Review colors are each rich-text item's `annotations.color` and the block's `color`.
- Upload a figure's PNG with `ntn files create --filename <name>.png --content-type image/png < <file>` and place it as an image block right above its caption.
- Date properties take `"time_zone": "<TZ>"`.

## Templates

- Create each page from its database's template file in `guide/notion_guide/templates/` beside this file, not a Notion template, with the default properties in its header. Below the template's line is the page body: write each part only when you fill it, at its place, by its italic instructions. Italic text and the opening quote never go into the page; plain text goes in as it is. Leave no instruction text or `…`.
- An `<aside>` is a callout with the icon and background in its template's header. Write it first, with the first sections you fill; when a page goes to review, rewrite it in place as its template says.
- Give a new idea, experiment, or finding a Name of at most 15 words, or 20 characters in Chinese. Give every new page an ID of lowercase English words joined by hyphens, at most 24 characters, unique, and never renamed.
- If headings differ from the template's, find sections by name and tell the user before writing.

## Writing

- Write pages, headings and labels included, in the language the workspace rules set, else the reply language. Use property and option names exactly as defined.
- State each fact once, where it belongs, and elsewhere point to it unless a template asks otherwise. Give a reason for each deviation, control, estimate, and ✘, and elsewhere only where a template asks. Spell out at first use abbreviations uncommon in the field or made up here. Never chain abbreviations and symbols without words.
- Keep a table cell to a value, phrase, or sentence. Put several points on separate lines (`\n` in rich text), starting `1.`, `2.` if ordered, else `•`. Move content over three lines to a list below the table, leaving a pointer.
- Write times in the `TZ` of `.env`, as `YYYY-MM-DD HH:MM` in text.

## Budget left

An idea's budget left is each of its Budget limits minus what its experiments used: their number, the days to the Deadline, and single-GPU hours, from each finished experiment's GPU hours row plus `gpu_hours.py` on a running one's log folder, on each of its machines. If `gpu_hours.py` exits 3, the hours are unknown: tell the user and stop.

## Review marks

Read a page before and after every write; merge the user's edits. Read every color, table cells included. Red, orange, or purple text or background is a review mark. Answer each, telling the user what you change and why. Red (wrong): fix it. Orange (unclear): explain it plainly, and rewrite it to need no explanation. Purple (not acceptable): propose an alternative; keep the text and mark until the user decides. Rewritten text loses its mark. Unresolved marks stay.
