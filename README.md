# Build recipes

This repository contains a collection of recipes for [build(https://github.com/mverboom/build)].

You can easily link all recipes in this repository by running the following command.

```
RECIPEDIR=~/recipes
GITCHECKOUT=~/git/build-recipes
find $GITCHECKOUT -name *.recipe -o -name *.files -exec ln -nfs {} $RECIPEDIR- \;
```
