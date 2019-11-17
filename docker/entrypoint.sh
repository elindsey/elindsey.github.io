#!/bin/sh
set -ex

bundle install # shouldn't be necessary; handled by Dockerfile
bundle exec jekyll build -d build
cd build

# tell GH not to run jekyll
touch .nojekyll

# user pages can only be published to master
echo ${GITHUB_REPOSITORY} | grep -E '^([a-z]*)\/\1\.github\.io$' > /dev/null
if [ $? -eq 0 ]; then
    REMOTE_BRANCH="master"
else
    REMOTE_BRANCH="gh-pages"
fi

git init
git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
git add .
git commit -m "automated publish via Github Action"

set +x # don't print token
git push --force "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" master:${REMOTE_BRANCH}
set -x
