MESSAGE := $(m)
BRANCH  := $(b)

test:
	echo "hello world"

website:
	@make push m="$(MESSAGE)" b="main"

push: pull
	@git push -u origin $(BRANCH)


pull: commit
ifeq ($(BRANCH),)
	@echo "error: branch not given"
	@exit 1
else
	@git pull origin $(BRANCH)
endif

commit:
ifeq ($(MESSAGE),)
	@echo "error: empty commit message!"
	@exit 1
else
	@git add .
	@git commit -m "$(MESSAGE)"
endif