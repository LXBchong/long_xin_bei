MESSAGE := $(m)
BRANCH  := $(b)

test:
	echo "$(MESSAGE):$(m)"
	echo "$(BRANCH):$(b)"

push: pull
ifeq ($(MESSAGE),)
	@echo "error: empty commit message!"
	@exit 1
else
	@git add .
	@git commit -m "$(MESSAGE)"
	@git push -u origin $(BRANCH)
endif

pull:
ifeq ($(BRANCH),)
	@echo "error: branch not given"
	@exit 1
else
	@git pull origin $(BRANCH)
endif

website:
	@make push m="$(MESSAGE)" b="main"