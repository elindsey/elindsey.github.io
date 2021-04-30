.PHONY: build run
.DEFAULT: build

build:
	bundle exec jekyll build
run:
	bundle exec jekyll serve
