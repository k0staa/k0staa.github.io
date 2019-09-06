#!/bin/bash
docker run -it --name ruby-blog -p 4001:4001 -v "$(pwd)/../":/blog  kostek/ruby-blog /bin/sh
