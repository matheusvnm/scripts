#!/bin/zsh

process_file() {
    cat $1 | \
        awk '{print $4}' | \
        egrep -o '[0-9]+(\.[0-9]+)?' | \
        tr "." "," > ../$2/$1

    echo "[DONE]: $1"
}

BASE_DIR="Ibicui/Temp/"
DIRTY_DIR="Dirty"
CLEAN_DIR="Clean"

echo "$PWD"
rm $BASE_DIR/$CLEAN_DIR/* &>/dev/null

cd $BASE_DIR/$DIRTY_DIR
for WORKING_FILE in *.txt; do
    IGNORE=false
    for IGNORED_FILE_PATTERN in "$@"; do
        if [[ $WORKING_FILE == *"$IGNORED_FILE_PATTERN"* ]]; then
            echo "[IGNORED]: $WORKING_FILE"
            IGNORE=true
            break
        fi
    done
    if [ $IGNORE = false ]; then
        process_file $WORKING_FILE $CLEAN_DIR &
    fi
done

wait
echo "Finished!"
exit 0
