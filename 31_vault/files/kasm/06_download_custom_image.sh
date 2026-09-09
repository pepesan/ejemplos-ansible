#!/bin/bash

IMAGE_NAME="${KASM_IMAGE:-pepesan/mi-ubuntu-resolute-kasm:1.0}"

docker exec kasm docker pull "${IMAGE_NAME}"