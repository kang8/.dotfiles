.PHONY: duti

duti: defaults.duti
	duti defaults.duti

format:
	sort Brewfile --output=Brewfile
