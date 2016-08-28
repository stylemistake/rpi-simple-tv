#!/bin/bash
cd "$(dirname ${0})"

shopt -s expand_aliases

if [[ ! -f config.conf ]]; then
    echo "You forgot to create the 'config.conf' configuration file!"
    exit 1
fi

mkdir -p .tmp

PLAYLIST_FILE=".tmp/playlist.m3u"

source config.conf

trap "before_exit" EXIT HUP INT QUIT PIPE TERM

log() {
    echo "${@}" >&2
}

log_reset() {
    tput reset
    log "${@}"
}

before_exit() {
    player_stop
    exit 0
}

fetch_playlist() {
    if hash curl 2>/dev/null; then
        curl -o ${PLAYLIST_FILE} "${PLAYLIST_URL}"
    elif hash wget 2>/dev/null; then
        wget -O ${PLAYLIST_FILE} "${PLAYLIST_URL}"
    else
        hash curl wget
        exit 1
    fi
}

remove_playlist() {
    rm -f ${PLAYLIST_FILE}
}

get_channel() {
    if [[ ! -f $(find ${PLAYLIST_FILE} -mmin -30 2>/dev/null) ]]; then
        log "Updating channels..."
        fetch_playlist
    fi
    local line
    line=$(grep -in "tvg-name=\"${CHANNELS[$1]}\"" ${PLAYLIST_FILE} | cut -d: -f1 | head -1)
    if [[ -n ${line} ]]; then
        cat ${PLAYLIST_FILE} | sed -n $(( line + 1 ))p
    fi
}

manage_input() {
    local stream
    log_reset "Status: press any key"
    while :; do
        read -t5 key
        if [[ -z ${key} ]]; then
            if [[ -z ${stream} ]]; then
                log_reset "Status: press any key"
                continue
            fi
            if ! player_status; then
                player_start "${stream}" &
            else
                log_reset "Status: running"
            fi
            continue
        fi
        stream="$(get_channel ${key})"
        if [[ -z ${stream} ]]; then
            remove_playlist
            continue
        fi
        if player_status; then
            player_stop
        fi
        log "Starting player..."
        player_start "${stream}" &
    done
}

python remote.py | manage_input
