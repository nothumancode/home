confirmed=false
options=true
for arg do
    shift
    if "$options"; then
        case $arg in
            --) options=false ;;
            --yes) confirmed=true; continue ;;
            --*) ;;
            -*y*)
                confirmed=true
                # Strip y from a short option cluster, retaining flags like -rf.
                flags=${arg#-}
                arg=-
                while [ -n "$flags" ]; do
                    rest=${flags#?}
                    flag=${flags%"$rest"}
                    [ "$flag" = y ] || arg=$arg$flag
                    flags=$rest
                done
                [ "$arg" != - ] || continue
                ;;
            -?*) ;;
            *) [ -z "${POSIXLY_CORRECT+x}" ] || options=false ;;
        esac
    fi
    set -- "$@" "$arg"
done

if ! "$confirmed"; then
    printf '%s\n' 'rm: deletion requires --yes (-y).' >&2
    exit 1
fi
exec @rm@ "$@"
