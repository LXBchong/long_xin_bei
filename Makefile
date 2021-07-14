#建议第一次部署网站的时候一步步执行，然后之后再用make website快捷部署

MESSAGE=$(m)

push: pull
ifeq ($(MESSAGE),)
	echo "empty message!"
else
	git add .
	git commit -m "$(MESSAGE)"
	git push -u origin main
endif


website: pull PushForWebsite
	mkdocs gh-deploy

pull:
	git pull origin main


PushForWebsite:
ifeq ($(MESSAGE),)
	echo "emtpy message!"
else
	git add .
	git commit -m "$(MESSAGE)"
	git push -u origin main
endif

test:
	echo "test"

