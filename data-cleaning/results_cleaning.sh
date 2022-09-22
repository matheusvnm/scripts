#!/bin/zsh

process_file() {
    cat $1 |
        grep -i -E $2 |
        grep -oE '[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?' |
        tr '\n' ';' |
        tr '.' ',' |
        sed 's/.$//' >../$3/$1

    echo "[DONE]: $1"
}

getopts ":s:" ARGS
if [ $ARGS != s ]; then
    echo "[ERROR] Use -s SEARCH_TERM"
    exit 147
fi
SEARCH_TERM=$OPTARG
BASE_DIR="Ibicui/Time/"
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
        process_file $WORKING_FILE $SEARCH_TERM $CLEAN_DIR &
    fi
done

wait
echo "Finished!"
exit 0
