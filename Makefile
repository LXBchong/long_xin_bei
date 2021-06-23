website: push
	mkdocs gh-deploy



push:
	git add .
	git commit -m "update website"
	git push -u origin main


test:
	git status
	git add .
	git status
