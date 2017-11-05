#!/bin/bash
docker run -it --name ruby-blog -p 4000:4000 -v "$(pwd)/../":/blog  kostek/ruby-blog /bin/sh
