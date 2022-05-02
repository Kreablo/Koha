#!/bin/bash -e

kohadir=/usr/share/koha

export TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT INT TERM HUP

v=$(egrep '^\$VERSION =' Koha.pm)
major=$(perl -e "$v \$VERSION =~ /^(\d+\.\d+)/; print \"\$1\n\"")
patchflags=
help=
quiet=no

fp=$(git describe | awk -F- '{ print $1 }')

msg () {
    if [[ "$quiet" != "yes" ]]; then
        echo "$1"
    fi
}

parse_arguments () {
    local tmp=$(getopt -o 'R,h,q,d:' --long 'reverse,help,quiet,kohadir:' -- "$@")

    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    eval set -- "${tmp}"
    while true; do
        case "$1" in
            -R|--reverse)
                patchflags+=" -R"
                shift
                ;;
            -d|--kohadir)
                kohadir="$2";
                shift 2;
                ;;
            -h|--help)
                help=1
                shift
                ;;
            -q|--quiet)
                quiet=yes
                shift
                ;;
            --)
                shift
                break
                ;;
	    *) echo "Invalid option '$1'" ; exit 1 ;;
        esac
    done
}

parse_arguments "$@"

if [[ -n "$help" ]]; then
    echo "$0: [--reverse] [--kohadir=<kohadir>]"
    exit 0
fi

msg "Including patches since $fp:"

if [[ "$quiet" != "yes" ]]; then
    git log --pretty=oneline $fp..HEAD
fi

if (( $(git log --pretty=oneline $fp..HEAD -- opac | wc -l) > 0 )); then
    msg "Creating OPAC patch."
    opacpatch=$(mktemp -p $TMPDIR XXXXXXX.patch)
    git diff $fp..HEAD -- opac > $opacpatch
fi

if (( $(git log --pretty=oneline $fp..HEAD -- koha-tmpl/opac-tmpl | wc -l) > 0 )); then
    msg "Creating OPAC templates patch."
    opactmplpatch=$(mktemp -p $TMPDIR  XXXXXXX.patch)
    git diff $fp..HEAD -- koha-tmpl/opac-tmpl  > $opactmplpatch
fi

if (( $(git log --pretty=oneline $fp..HEAD -- C4  CGI  Koha  Koha.pm  cpanfile | wc -l) > 0 )); then
    msg "Creating lib patch."
    libpatch=$(mktemp -p $TMPDIR  XXXXXXX.patch)
    git diff $fp..HEAD -- C4  CGI  Koha  Koha.pm  cpanfile > $libpatch
fi

if (( $(git log --pretty=oneline $fp..HEAD -- api | wc -l) > 0 )); then
    msg "Creating api patch."
    apipatch=$(mktemp -p $TMPDIR  XXXXXXX.patch)
    git diff $fp..HEAD -- api > $apipatch
fi

if (( $(git log --pretty=oneline $fp..HEAD -- koha-tmpl/intranet-tmpl | wc -l) > 0 )); then
    msg "Creating intra templates patch."
    intratmplpatch=$(mktemp -p $TMPDIR  XXXXXXX.patch)
    git diff $fp..HEAD -- koha-tmpl/intranet-tmpl > $intratmplpatch
fi

declare -a intra=()
readarray -t intra < <(for filename in $(git diff --numstat $fp..HEAD | awk '{ print $3 }') ; do
                           if [[ ! $filename =~ ^opac/|koha-tmpl/|C4/|Koha/|CGI/|(Koha.pm$)|(cpanfile$)|api/ ]]; then
                               msg $filename
                           fi
                      done)



if (( $(git log $fp..HEAD -- "${intra[@]}" | wc -l) > 0 )); then
    msg "Creating intra patch."
    intrapatch=$(mktemp -p $TMPDIR  XXXXXXX.patch)
    git diff $fp..HEAD -- "${intra[@]}" > $intrapatch
fi

if [[ -z "$opacpatch" && -z "$opactmplpatch" && -z "$libpatch" && -z "$apipatch" && -z "$intratmplpatch" && -z "$intrapatch" ]] ; then
    msg "Nothing to do!"
    exit 0
fi

patchscript=$(mktemp -p $TMPDIR  XXXXXXX.sh)

cat <<EOVARS >> "$patchscript"
#!/bin/bash -e

kohadir=$kohadir
reverse=no
patchflags=$patchflags
help=
quiet=no

EOVARS


cat <<'EOF' >> "$patchscript"

parse_arguments () {
    local tmp=$(getopt -o 'R,h,q,d:' --long 'reverse,help,quiet,kohadir:' -- "$@")


    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    eval set -- "${tmp}"
    while true; do
        case "$1" in
            -R|--reverse)
                reverse="yes"
                shift
                ;;
            -d|--kohadir)
                kohadir="$2";
                shift 2;
                ;;
            -h|--help)
                help=1
                shift
                ;;
            -q|--quiet)
                quiet=yes
                shift
                ;;
            --)
                shift
                break
                ;;
	    *) echo "Invalid option '$1'" ; exit 1 ;;
        esac
    done
}

parse_arguments "$@"

if [[ -n "$help" ]]; then
    echo "$0: [--reverse] [--kohadir=<kohadir>]"
    exit 0
fi

if [[ "$quiet" != "no" ]]; then
   patchflags+=" -s"
fi

if [[ "$reverse" != "no" ]]; then
   patchflags+=" -R"
fi

EOF


if [[ -n "$opacpatch" ]]; then
    echo "patch \$patchflags -p1 -d \"\$kohadir\"/opac/cgi-bin <<'EOPACPATCH'" >> "$patchscript"
    cat "$opacpatch"         >> "$patchscript"
    echo "EOPACPATCH" >> "$patchscript"
fi

if [[ -n "$opactmplpatch" ]]; then
    echo "patch \$patchflags -p2 -d \"\$kohadir\"/opac/htdocs <<'EOPACTMPLPATCH'" >> "$patchscript"
    cat "$opactmplpatch"         >> "$patchscript"
    echo "EOPACTMPLPATCH" >> "$patchscript"
fi

if [[ -n "$libpatch" ]]; then
    echo "patch \$patchflags -p1 -d \"\$kohadir\"/lib <<'ELIBPATCH'" >> "$patchscript"
    cat "$libpatch"         >> "$patchscript"
    echo "ELIBPATCH" >> "$patchscript"
fi

if [[ -n "$apipatch" ]]; then
    echo "patch \$patchflags -p1 -d \"\$kohadir\"/api <<'EAPIPATCH'" >> "$patchscript"
    cat "$apipatch"         >> "$patchscript"
    echo "EAPIPATCH" >> "$patchscript"
fi

if [[ -n "$intratmplpatch" ]]; then
    echo "patch \$patchflags -p2 -d \"\$kohadir\"/intranet/htdocs <<'EINTRATMPLPATCH'" >> "$patchscript"
    cat "$intratmplpatch"         >> "$patchscript"
    echo "EINTRATMPLPATCH" >> "$patchscript"
fi

if [[ -n "$intrapatch" ]]; then
    echo "patch \$patchflags -p1 -d \"\$kohadir\"/intranet/cgi-bin <<'EINTRAPATCH'" >> "$patchscript"
    cat "$intrapatch"         >> "$patchscript"
    echo "EINTRAPATCH" >> "$patchscript"
fi

cp "$patchscript" /tmp/koha-patch-prod.sh
chmod a+x /tmp/koha-patch-prod.sh

msg "Created patch script: /tmp/koha-patch-prod.sh"

