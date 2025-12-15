SHELL := /bin/sh
MARK_SEP := $(shell printf '\t#L:')
PYTHON ?= python3

# Try to infer the original PPTX from the current directory,
# ignoring already-translated files prefixed with "Traduzido-".
# Uses a shell pipeline so filenames with spaces are handled correctly.
PPTX_AUTO := $(shell ls *.pptx 2>/dev/null | grep -v '^Traduzido-' | head -n1)

PPTX ?= $(PPTX_AUTO)
TEXT_MAP ?= $(PPTX:.pptx=.text-map.json)
TEXT_VALUES ?= $(TEXT_MAP:.json=.text-values.json)
TEXT_VALUES_MARKED ?= $(TEXT_VALUES:.json=.numbered.json)

BASE_MAP ?= $(TEXT_MAP)
TRANSLATED_MARKED ?= $(TEXT_VALUES_MARKED:.json=.translated.json)
TRANSLATED_CLEAN ?= $(TRANSLATED_MARKED:.json=.clean.json)
TRANSLATED_MAP ?= $(TRANSLATED_MARKED:.json=.translated-map.json)
TRANSLATED_PPTX ?= $(PPTX:.pptx=-translated.pptx)

.PHONY: help add-marks remove-marks prep-export apply-translation full-translation

help:
	@printf "Usage: make <target> [vars]\\n\\n"
	@printf "Defaults (can be overridden):\\n"
	@printf "  PPTX               -> first *.pptx not starting with 'Traduzido-' in CWD\\n"
	@printf "  TEXT_MAP           -> <pptx>.text-map.json\\n"
	@printf "  TEXT_VALUES        -> <pptx>.text-map.text-values.json\\n"
	@printf "  TEXT_VALUES_MARKED -> <pptx>.text-map.text-values.numbered.json\\n"
	@printf "  TRANSLATED_MARKED  -> <pptx>.text-map.text-values.numbered.translated.json\\n"
	@printf "  TRANSLATED_CLEAN   -> ...translated.clean.json\\n"
	@printf "  TRANSLATED_MAP     -> ...translated-map.json\\n"
	@printf "  TRANSLATED_PPTX    -> <pptx>-translated.pptx\\n\\n"
	@printf "Targets:\\n"
	@printf "  full-translation   Interactive: run full flow (prep, IA step, apply).\\n"
	@printf "  prep-export        Steps 1-4: build text map, export text array, add #L marks.\\n"
	@printf "                     Uses PPTX/TEXT_MAP/TEXT_VALUES/TEXT_VALUES_MARKED defaults above.\\n"
	@printf "  apply-translation  Steps 6-8: strip marks, merge translations, write translated PPTX.\\n"
	@printf "                     Normally only TRANSLATED_MARKED is needed if you follow defaults.\\n"
	@printf "  add-marks          INPUT=<src> OUTPUT=<dst>  Add #L line markers.\\n"
	@printf "  remove-marks       INPUT=<src> OUTPUT=<dst>  Strip #L line markers.\\n"

add-marks:
	@ : $${INPUT?set INPUT to the source file path}
	@ : $${OUTPUT?set OUTPUT to the destination file path}
	nl -ba -w1 -s "$(MARK_SEP)" "$$INPUT" > "$$OUTPUT"

remove-marks:
	@ : $${INPUT?set INPUT to the numbered file path}
	@ : $${OUTPUT?set OUTPUT to the destination file path}
	sed -E 's/^[[:space:]]*[0-9]+[[:space:]]*#L://' "$$INPUT" > "$$OUTPUT"

prep-export:
	@ test -n "$(PPTX)" || { echo "PPTX not detected; set PPTX=path/to/source.pptx or ensure a *.pptx exists here."; exit 1; }
	$(PYTHON) build_text_map.py "$(PPTX)" --output "$(TEXT_MAP)"
	$(PYTHON) export_text_array.py --source "$(TEXT_MAP)" --output "$(TEXT_VALUES)"
	$(MAKE) --no-print-directory add-marks INPUT="$(TEXT_VALUES)" OUTPUT="$(TEXT_VALUES_MARKED)"

apply-translation:
	@ test -n "$(PPTX)" || { echo "PPTX not detected; set PPTX=path/to/source.pptx or ensure a *.pptx exists here."; exit 1; }
	@ test -n "$(TRANSLATED_MARKED)" || { echo "TRANSLATED_MARKED must point to the translated JSON with #L marks."; exit 1; }
	$(MAKE) --no-print-directory remove-marks INPUT="$(TRANSLATED_MARKED)" OUTPUT="$(TRANSLATED_CLEAN)"
	$(PYTHON) apply_translated_texts.py --base-map "$(BASE_MAP)" --translated-values "$(TRANSLATED_CLEAN)" --output "$(TRANSLATED_MAP)"
	$(PYTHON) apply_text_map_to_pptx.py --pptx "$(PPTX)" --translated-map "$(TRANSLATED_MAP)" --output "$(TRANSLATED_PPTX)"

full-translation:
	@echo "== Step 1: preparing export and line-numbered JSON =="
	@$(MAKE) --no-print-directory prep-export
	@ : > "$(TRANSLATED_MARKED)"
	@echo
	@echo "== Step 2: send numbered JSON for translation =="
	@echo "Send this file to your translation IA using the prompt from README.md:"
	@echo "  $(TEXT_VALUES_MARKED)"
	@echo
	@echo "When you get the translated JSON back, paste it carefully into:"
	@echo "  $(TRANSLATED_MARKED)"
	@echo "and save the file (avoid auto-formatting that changes spaces or line starts)."
	@echo
	@echo "Important: make sure the translated file has EXACTLY the same number of lines"
	@echo "as the numbered input. If the line counts differ, fix the translation before continuing."
	@echo
	@printf "Press Enter once you have pasted and saved the translation to continue..."
	@read dummy
	@echo
	@echo "== Step 3: applying translation and generating translated PPTX =="
	@$(MAKE) --no-print-directory apply-translation
	@echo
	@echo "Done. Translated PPTX written to:"
	@echo "  $(TRANSLATED_PPTX)"
