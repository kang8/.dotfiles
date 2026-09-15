.PHONY: duti

duti: defaults.duti
	duti defaults.duti

format:
	LC_ALL=C sort Brewfile --output=Brewfile
	@# Skillfile is to .skill-lock.json what Brewfile is to Brewfile.lock.json:
	@# the list of what is installed, without the hashes that churn every update.
	@# The lock stores a well-known source bare; `skills add` needs the scheme.
	@if [ -f agents/.agents/.skill-lock.json ]; then \
		{ sed -n '/^#/p' agents/.agents/Skillfile; \
		  { awk 'NF && $$1 !~ /^#/ && $$2 == "*" { print $$1, $$2 }' \
		      agents/.agents/Skillfile; \
		    jq -r '.skills | to_entries[] | .value.source as $$s | \
		      "\(if .value.sourceType == "well-known" then "https://" + $$s else $$s end) \(.key)"' \
		      agents/.agents/.skill-lock.json | \
		      while read -r source name; do \
		        awk -v source="$$source" \
		          '$$1 == source && $$2 == "*" { found=1 } END { exit !found }' \
		          agents/.agents/Skillfile || printf '%s %s\n' "$$source" "$$name"; \
		      done; \
		  } | LC_ALL=C sort; \
		} > agents/.agents/Skillfile.tmp && \
		mv agents/.agents/Skillfile.tmp agents/.agents/Skillfile; \
	fi
	jq -S . claude/.claude/settings.json > claude/.claude/settings.json.tmp && \
		if cmp -s claude/.claude/settings.json.tmp claude/.claude/settings.json; then \
			rm claude/.claude/settings.json.tmp; \
		else \
			mv claude/.claude/settings.json.tmp claude/.claude/settings.json; \
		fi
	deno fmt
