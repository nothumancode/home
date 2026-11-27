# Run in the flake check's disposable build directory, with the profile on PATH.
set -eu
cd "$(mktemp -d)"

refuses() {
    hint=$1
    shift
    if "$@" 2>error; then
        printf 'unexpected success: %s\n' "$*" >&2
        exit 1
    fi
    grep -Fq -- "$hint" error
}

mkdir target
printf old >target/file
printf new >file
refuses --force mv file target
refuses --force mv --update=all file target
refuses --force mv -T file target/file
printf 'y\n' | refuses --force mv -i file target
test "$(cat target/file)" = old
test "$(cat file)" = new
mv -vf file target
test "$(cat target/file)" = new

mkdir src dest
refuses --force mv -T src dest
test -d src
mv --force -T src dest
test ! -d src

ln -s missing link
touch source
refuses --force mv source link
test -L link
mv source "it's a new name"
test -f "it's a new name"

mkdir -- -f
touch -- -f/file file
refuses --force mv -t -f file
refuses --force mv --suffix --force file target
touch -- --force
refuses --force mv -- --force target/file
test -f ./--force

touch -- --yes -y
refuses --yes rm -rf target
refuses --yes rm -- --yes -y
test -f target/file
test -f ./--yes
test -f ./-y
rm --yes -- --yes
rm -y -- -y
rm -ryf target
test ! -e ./--yes
test ! -e ./-y
test ! -e target
