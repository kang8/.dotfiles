#!/usr/bin/env bash

line=`php artisan list --raw | fzf`

command=`echo $line | cut -d ' ' -f 1`
is_create=`echo $line | cut -d ' ' -f 2`
introduce=`echo $line | cut -d ' ' -f 2-`

if [[ $is_create == "Create" ]]; then
    echo -n "Please input a file name to ${introduce}: "
    read -r file_name

    echo "Run \"php artisan $command $file_name\" to ${introduce}"

    php artisan $command $file_name
else
    echo "Run \"php artisan $command\" to ${introduce}"

    php artisan $command
fi
