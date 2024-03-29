#!/bin/bash

ruby ./helpers/wait_for_documentserver_start.rb

if [[ -z $CURRENT_SPEC ]]; then
        echo 'Run all the spec files in their entirety'
        rspec
    else
        echo 'Run the spec file' $CURRENT_SPEC
        rspec --pattern "spec/**/$CURRENT_SPEC"
fi
