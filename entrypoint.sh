#!/bin/sh -l
# inspired by https://gist.github.com/romainbsl/0d0bb2149ce7f34246ec6ab0733a07f1

closingRepository=$(
  curl -s --request POST -u "$INPUT_USERNAME:$INPUT_PASSWORD" \
    --url ${INPUT_BASE_URL}staging/bulk/close \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --data '{ "data" : {"stagedRepositoryIds":["'"$INPUT_STAGING_REPOSITORY_ID"'"], "description":"Close '"$INPUT_STAGING_REPOSITORY_ID"'." } }'
)

if [ ! -z "$closingRepository" ]; then
    echo "Error while closing repository $INPUT_STAGING_REPOSITORY_ID : $closingRepository."
    exit 1
fi

if [ "$INPUT_CLOSE_ONLY" = "true" ]; then
    echo "Do not auto-release repository $INPUT_STAGING_REPOSITORY_ID. This can be done manually on https://oss.sonatype.org/."
    exit 0
fi

start=$(date +%s)
while true ; do
  # force timeout after 15 minutes
  now=$(date +%s)
  if [ $(( (now - start) / 60 )) -gt 15 ]; then
      echo "Closing process is to long, stopping the job (waiting for closing repository)."
      exit 1
  fi

  rules=$(curl -s --request GET -u "$INPUT_USERNAME:$INPUT_PASSWORD" \
        --url ${INPUT_BASE_URL}staging/repository/"$INPUT_STAGING_REPOSITORY_ID"/activity \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json')

  closingRules=$(echo "$rules" | jq '.[] | select(.name=="close")')
  if [ -z "$closingRules" ] ; then
    continue
  fi

  rulesPassed=$(echo "$closingRules" | jq '.events | any(.name=="rulesPassed")')
  rulesFailed=$(echo "$closingRules" | jq '.events | any(.name=="rulesFailed")')

  if [ "$rulesFailed" = "true" ]; then
    echo "Staged repository [$INPUT_STAGING_REPOSITORY_ID] could not be closed."
    exit 1
  fi

  if [ "$rulesPassed" = "true" ]; then
      break
  else
      sleep 5
  fi
done

start=$(date +%s)
while true ; do
  # force timeout after 5 minutes
  now=$(date +%s)
  if [ $(( (now - start) / 60 )) -gt 5 ]; then
      echo "Closing process is to long, stopping the job (waiting for transitioning state)."
      exit 1
  fi

  repository=$(curl -s --request GET -u "$INPUT_USERNAME:$INPUT_PASSWORD" \
    --url ${INPUT_BASE_URL}staging/repository/"$INPUT_STAGING_REPOSITORY_ID" \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json')

  type=$(echo "$repository" | jq -r '.type' )
  transitioning=$(echo "$repository" | jq -r '.transitioning' )
  if [ "$type" = "closed" ] && [ "$transitioning" = "false" ]; then
      break
  else
      sleep 1
  fi
done

release=$(curl -s --request POST -u "$INPUT_USERNAME:$INPUT_PASSWORD" \
  --url ${INPUT_BASE_URL}staging/bulk/promote \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data '{ "data" : {"stagedRepositoryIds":["'"$INPUT_STAGING_REPOSITORY_ID"'"], "autoDropAfterRelease" : true, "description":"Release '"$INPUT_STAGING_REPOSITORY_ID"'." } }')

if [ ! -z "$release" ]; then
    echo "Error while releasing $INPUT_STAGING_REPOSITORY_ID : $release."
    exit 1
fi