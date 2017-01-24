#!/usr/bin/env bash

# @link http://jeroenjanssens.com/2013/08/16/quickly-navigate-your-filesystem-from-the-command-line.html
function j {
    cd -P "$MARKPATH/$1" 2>/dev/null || echo "No such mark: $1"
}
function m {
    mkdir -p "$MARKPATH"; ln -s "$(pwd)" "$MARKPATH/$1"
}
function um {
    rm -i "$MARKPATH/$1"
}
function marks {
    \ls -l "$MARKPATH" | tail -n +2 | sed 's/  / /g' | cut -d' ' -f9- | awk -F ' -> ' '{printf "%-10s -> %s\n", $1, $2}'
}

# Remote Mount (sshfs)
# creates mount folder and mounts the remote filesystem
#
# Options:
#
# SSHFS
#
# sshfs(1) - SSHFS: reconnect to server
# -o reconnect
# sshfs(1) - SSHFS: transform absolute symlinks to relative
# -o transform_symlinks
# sshfs(1) - FUSE: enable caching based on modification times
# -o auto_cache
# sshfs(1) - FUSE: cache files in kernel
# -o kernel_cache
# sshfs(1) - FUSE: immediate removal (don't hide files)
# -o hard_remove

# SSH Options
#
# ssh_config(5): Disable compression for to reduce time to start transferring
# https://www.smork.info/blog/2013/04/24/entry130424-163842.html
# -o Compression=no

# OSXFUSE
#
# osxfuse: The defer_permissions option causes osxfuse to assume that all accesses
# are allowed--it will forward all operations to the file system, and it is up to
# somebody else to eventually allow or deny the operations. In the case of sshfs,
# it would be the SFTP server eventually making the decision about what to allow or
# disallow.
# -o defer_permissions
# osxfuse: This option enables negative vnode name caching in the kernel.
# -o negative_vncache
# osxfuse: You can use the volname option to specify a name for the osxfuse volume being mounted.
# -o volname=$mname
# osxfuse: This option makes osxfuse deny all types of access to Apple Double (._) files and .DS_Store files.
# -o noappledouble
rmount() {
    local host folder mname
    host="${1%%:*}:"
    [[ ${1%:} == ${host%%:*} ]] && folder='' || folder=${1##*:}
    if [[ $2 ]]; then
        mname=$2
    else
        mname=${folder##*/}
        [[ "$mname" == "" ]] && mname=${host%%:*}
    fi
    if [[ $(grep -i "host ${host%%:*}" ~/.ssh/config) != '' ]]; then
        mkdir -p ~/mounts/$mname > /dev/null
        sshfs \
            $host$folder \
            ~/mounts/$mname \
            -o reconnect \
            -o transform_symlinks \
            -o auto_cache \
            -o kernel_cache \
            -o hard_remove \
            -o Ciphers=aes256-ctr \
            -o Compression=no \
            -o defer_permissions \
            -o negative_vncache \
            -o volname=$mname \
            -o noappledouble \
            && echo "mounted ~/mounts/$mname"
    else
        echo "No entry found for ${host%%:*}"
        return 1
    fi
}

# Remote Umount, unmounts and deletes local folder (experimental, watch you step)
rumount() {
    if [[ $1 == "-a" ]]; then
        ls -1 ~/mounts/|while read dir
        do
            [[ $(mount | grep "mounts/$dir") ]] && umount ~/mounts/$dir
            [[ $(ls ~/mounts/$dir) ]] || rm -rf ~/mounts/$dir
        done
    else
        [[ $(mount | grep "mounts/$1") ]] && umount ~/mounts/$1
        [[ $(ls ~/mounts/$1) ]] || rm -rf ~/mounts/$1
    fi
}
