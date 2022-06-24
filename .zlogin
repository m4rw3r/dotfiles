

{
    # Compile the completion dump to increase startup speed.
    zcompdump="$XDG_CACHE_HOME/zsh/zcompcache"
    if [[ -s "$zcompdump" && (! -s "${zcompdump}.zwc" || "$zcompdump" -nt "${zcompdump}.zwc") ]]; then
        zcompile "$zcompdump"
    fi
} &!
