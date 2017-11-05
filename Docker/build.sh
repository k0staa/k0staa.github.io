#!/bin/bash
cp -f ../Gemfile* ./
docker build -t kostek/ruby-blog .
