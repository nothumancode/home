# GNU getopt resolves option clusters and option arguments before we look for
# force. In particular, neither "mv -t -f ..." nor "mv -- -f ..." grants it.
parsed=$(unset GETOPT_COMPATIBLE; @getopt@ -s sh -n mv \
    -o bfinS:t:TuvZ -l backup::,debug,exchange,force,interactive,no-clobber,no-copy,strip-trailing-slashes,suffix:,target-directory:,no-target-directory,update::,verbose,context,help,version \
    -- "$@") || exit 1

guarded_move() {
    remaining=$#
    while [ "$1" != -- ]; do
        option=$1
        shift
        remaining=$((remaining - 1))
        case $option in
            -f|--force) return 0 ;;
            -t|--target-directory)
                set -- "$@" "$option" "$1"
                shift
                remaining=$((remaining - 1))
                ;;
            # A protected move cannot need a backup. GNU mv rejects backup
            # options together with --update=none-fail, even for new targets.
            --backup)
                case $1 in
                    ''|none|off|numbered|t|existing|nil|simple|never) ;;
                    *) printf 'mv: invalid --backup value: %s\n' "$1" >&2; exit 1 ;;
                esac
                shift
                remaining=$((remaining - 1))
                ;;
            --suffix|-S)
                shift
                remaining=$((remaining - 1))
                ;;
            -b) ;;
            -u) set -- "$@" --update=none-fail ;;
            --update)
                case $1 in
                    none) set -- "$@" --update=none ;;
                    ''|all|older|none-fail) set -- "$@" --update=none-fail ;;
                    *) printf 'mv: invalid --update value: %s\n' "$1" >&2; exit 1 ;;
                esac
                shift
                remaining=$((remaining - 1))
                ;;
            *) set -- "$@" "$option" ;;
        esac
    done

    # Options are now at the back. Rotate the delimiter and operands behind
    # them without interpreting filenames or losing empty arguments.
    while [ "$remaining" -gt 0 ]; do
        set -- "$@" "$1"
        shift
        remaining=$((remaining - 1))
    done
    @mv@ --update=none-fail "$@" && exit 0
    status=$?
    printf '%s\n' 'mv: overwriting an existing destination requires --force (-f).' >&2
    exit "$status"
}

# getopt -s sh emits shell-quoted arguments. Keep the original argv for
# forced moves so coreutils applies the user's options in their original order.
eval "guarded_move $parsed"
exec @mv@ "$@"
