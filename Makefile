all : fountain.js

fountain.js : fountain.coffee

%.js : %.coffee
	coffee --bare -c -p $< > $@

