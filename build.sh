#!/bin/bash
cd jekyll-uno
rvm 2.0.0 do bundle
rvm 2.0.0 do jekyll build -s . -d ../public --config ../_config.yml --incremental
cd ..
cp keybase.txt public/
