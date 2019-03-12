#!/usr/bin/env bash

curl --user "${CIRCLE_TOKEN}:" \
    --request POST \
    --form config=@config.yml \
    --form notify=false \
        https://circleci.com/api/v1.1/project/github/levelkdev/master-property-value-token/tree/master
