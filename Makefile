website: pull PushForWebsite
	mkdocs gh-deploy

pull:
	git pull origin main

PushForWebsite:
	git add .
	git commit -m "update website"
	git push -u origin main


test:
	git status
	git add .
	git status


