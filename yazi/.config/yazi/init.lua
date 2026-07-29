-- Plugin setup. Both plugins are pinned in package.toml and restored with
-- `ya pkg install`; the plugins/ directory itself is git-ignored.

-- ranger: set vcs_aware true / set vcs_backend_git local
-- Renders git status signs in the linemode. Registered as fetchers in yazi.toml.
require("git"):setup({
	-- Order of the status sign within the linemode.
	order = 1500,
})

-- ranger: set line_numbers relative
-- Yazi has no built-in line-number option, so this plugin supplies both the
-- relative numbers and the vim-style counted motions (3j, 12k, 2yy) that
-- ranger's quantifiers provided.
require("relative-motions"):setup({
	show_numbers = "relative",
	show_motion = true,
	-- Keep d/x/y/v operators available, matching ranger's quantifier behaviour.
	only_motions = false,
	enter_mode = "first",
})
