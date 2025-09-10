.PHONY: duti

duti: defaults.duti
	duti defaults.duti

format:
	LC_ALL=C sort Brewfile --output=Brewfile
