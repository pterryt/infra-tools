include env/deploy.env
export

.DEFAULT_GOAL := help
.PHONY: help

help:
	@grep -Eh '(\s##\s|^##\s)' $(MAKEFILE_LIST) \
	| grep -Ev '^--' \
	| awk '\
		/^##/ { print ""; print substr($$0,4); print ""; next } \
		BEGIN { FS=":[[:space:]]*##[[:space:]]*" } \
		{ printf "\033[32m  %-35s\033[0m %s\n", $$1, $$2 }'
