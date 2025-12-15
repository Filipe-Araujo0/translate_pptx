# translate_pptx – safe PPTX text translation

This project was originally built to make it easy (and safe) to **translate** all textual content in a `.pptx` file without touching anything else in the deck, and it works just as well for other text‑only edits (changing writing style, shortening long paragraphs, adding sources, etc.), as long as the number of text lines is preserved.

- All layout, animations, charts, images and formatting stay exactly as in the original.
- Only the text payload is extracted, modified and written back in a controlled way.
- Line‑level mapping makes it practical to use LLMs for translation or other edits while keeping strict one‑line‑in / one‑line‑out guarantees. The JSON produced and consumed by the LLM must keep the **exact same number of lines**.

Doing this reliably is trickier than it sounds: PowerPoint splits text into many small runs, tables and chart labels, and a naïve search/replace will almost always break something. This repo wraps that complexity in a simple JSON‑based pipeline and a single unified `make` command.

## TL;DR – clone and run

From a terminal:

```bash
git clone <REPO_URL>
cd translate_pptx
make full-translation
```

Then follow the on‑screen instructions: the tool will generate the numbered JSON, tell you which file to send to the LLM and where to paste the answer, and only then apply the changes back into a translated/edited PPTX.

The translation/editing step itself is always handled by you ⚠️: this project never calls any LLM or external API directly, it only prepares and consumes the JSON and enforces good practices (line count, formatting, structure) so you are free to use whatever model or provider you prefer.

## High‑level flow

At a high level, the pipeline is:

1. Extract all text from the PPTX into a structured JSON “text map”.
2. Flatten that map into a simple JSON array of strings, preserving order.
3. Add line markers (`#L`) so an LLM can translate everything in one go without losing line boundaries.
4. Send the numbered JSON to an LLM with a strict prompt.
5. Paste the translated JSON back, strip the markers, and merge the new text into the original map.
6. Write a translated PPTX that only differs in text content.

All of this can be driven by one interactive command: `make full-translation`.

## Quickstart – unified interactive command

The recommended way to use this repo is still the unified, interactive command:

```bash
make full-translation
```

What it does:

1. Detects the original PPTX in the current directory (the first `*.pptx` not starting with `Traduzido-`), or uses `PPTX=<file.pptx>` if you pass it explicitly.
2. Runs the full export pipeline:
   - `build_text_map.py` → `<pptx>.text-map.json`
   - `export_text_array.py` → `<pptx>.text-map.text-values.json`
   - Adds `#L` line markers → `<pptx>.text-map.text-values.numbered.json`
3. Creates an empty file where you will paste the translated JSON:
   - `<pptx>.text-map.text-values.numbered.translated.json`
4. Prints:
   - Which numbered file to send to your translation model: `<pptx>.text-map.text-values.numbered.json`
   - Which file you must paste the translated JSON into: `<pptx>.text-map.text-values.numbered.translated.json`
   - A reminder to disable/avoid editor auto‑formatting that might change leading spaces or indentation.
5. Waits for you to:
   - Send the numbered JSON to the LLM with the prompt below (Grok has worked well in practice, but any model is fine as long as it strictly respects the constraints).
   - Paste the LLM response (carefully) into the `*.translated.json` file and save it.
   - Double‑check that the translated file has **exactly the same number of lines** as the numbered input.
   - Press Enter in the terminal to confirm.
6. After you press Enter, it:
   - Strips the `#L` markers and writes a clean translated array.
   - Merges translations back into the original map.
   - Produces a translated PPTX: `<pptx>-translated.pptx`.

You can always override the detected PPTX:

```bash
make full-translation PPTX=YourPresentation.pptx
```

## Suggested LLM prompt

When sending the numbered JSON file (`<pptx>.text-map.text-values.numbered.json`) to a model, use a prompt that enforces strict line and format preservation, for example:

> Keeping exactly the same number of lines and treating the text as a whole, translate the following JSON snippet and return it in exactly the same format and with the exact same number of lines.  
> Be especially careful with technical terms and numbers from the presentation and translate them accurately.  
> Do not change any formatting; each line in the original JSON must correspond to exactly one line in the result JSON.  
> Do not split or join lines, and do not add or remove brackets (`[`, `]`) or any other structural characters.

For very large decks, it may be safer to translate in multiple chunks (e.g. by splitting the numbered JSON into several smaller messages), as long as you strictly preserve order and line count within each chunk and then re‑assemble them in the original order.

## Line‑numbering commands

The core line‑numbering helpers are also exposed as Make targets, if you need them directly:

- Add `#L` line markers to a source JSON array:

  ```bash
  make add-marks INPUT=path/to/export.json OUTPUT=path/to/export_numbered.json
  ```

- Remove `#L` markers from a numbered JSON:

  ```bash
  make remove-marks INPUT=path/to/export_numbered.json OUTPUT=path/to/export_clean.json
  ```

Paths (`INPUT`, `OUTPUT`) can be relative or absolute, depending on your workflow.

All scripts and Make targets are intended to run from the project root, using as input the files produced by the previous steps in the pipeline.
