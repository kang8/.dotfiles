.PHONY: duti

duti: defaults.duti
	duti defaults.duti

format:
	LC_ALL=C sort Brewfile --output=Brewfile
	jq -S . claude/.claude/settings.json > claude/.claude/settings.json.tmp && mv claude/.claude/settings.json.tmp claude/.claude/settings.json
	deno fmt
