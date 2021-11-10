#!/usr/bin/env bash
set -Eeuo pipefail

list=`php artisan list --raw` || echo "Could not open input file: artisan" >&2 && exit
line=`printf "$list" | fzf`

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
