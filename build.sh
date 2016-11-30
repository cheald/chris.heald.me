#!/bin/bash
jekyll build -s ./jekyll-uno -d public --layouts jekyll-uno/_layouts --config _config.yml --incremental
cp keybase.txt public/
