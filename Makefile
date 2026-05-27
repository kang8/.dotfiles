.PHONY: duti

duti: defaults.duti
	duti defaults.duti

format:
	LC_ALL=C sort Brewfile --output=Brewfile
	jq -S . claude/.claude/settings.json > claude/.claude/settings.json.tmp && \
		if cmp -s claude/.claude/settings.json.tmp claude/.claude/settings.json; then \
			rm claude/.claude/settings.json.tmp; \
		else \
			mv claude/.claude/settings.json.tmp claude/.claude/settings.json; \
		fi
	deno fmt
