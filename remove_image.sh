#!/bin/bash
#-----------------------------
#Author: Pasit Y. (2023-05-09)
#-----------------------------

echo "-> Enter the Image Name: "  
read val_image

echo "-> Enter the Tags Name: "  
read val_tag

if [ -z "$val_image" ]; then
    echo "Can't Running Without define Image name"
    exit 1
fi

if [ -n "$val_image" ]; then
    if [ -n "$val_tag" ]; then
        echo "Remove Image with Tags $val_image:$val_tag"
        rm -rf /home/registry/data/docker/registry/v2/repositories/$val_image/_manifests/tags/$val_tag >/dev/null 2>&1
        docker exec -it registry bin/registry garbage-collect /etc/docker/registry/config.yml >/dev/null 2>&1
    else
        echo "Remove Image all Tags $val_image"
        rm -rf /home/registry/data/docker/registry/v2/repositories/$val_image >/dev/null 2>&1
        docker exec -it registry bin/registry garbage-collect /etc/docker/registry/config.yml >/dev/null 2>&1
    fi
else
    exit 1
fi
