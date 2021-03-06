# builds "hard" prerequisites and llpp
set -e

jobs=1
while getopts j: opt; do
    case "$opt" in
        j) jobs="$OPTARG";;
        ?)
        printf "usage: $0 [-j N] [opt]\n";
        exit 1;;
    esac
done
shift $(($OPTIND - 1))

mkdir -p 3rdp
cd 3rdp
root=$(pwd)

lablgl=http://wwwfun.kurims.kyoto-u.ac.jp/soft/lsl/dist/lablgl-1.04.tar.gz
mupdf3p=http://mupdf.com/download/mupdf-thirdparty-2012-04-23.zip
mupdfrev=a606f714258677688c67e9561b87cc70f9e9b6b0
mudir=mupdf-a606f71

test -d lablGL-1.04 || (wget -nc $lablgl && tar -xzf lablgl-1.04.tar.gz)

if ! test -d $mudir; then
    wget -nc \
       "http://git.ghostscript.com/?p=mupdf.git;a=snapshot;h=$mupdfrev;sf=tgz" \
       -O mupdf-$mupdfrev.tgz && tar -xzf mupdf-$mupdfrev.tgz
fi

test -d $mudir/thirdparty || \
    (wget -nc $mupdf3p && unzip -d $mudir $(basename $mupdf3p))

executable_p() {
    command -v $1 >/dev/null 2>&1
}

executable_p gmake && make=gmake || make=make

(cd lablGL-1.04 \
    && sed 17d Makefile.config.linux.mdk > Makefile.config \
    && $make lib libopt \
    && $make install \
            BINDIR=$root/bin \
            LIBDIR=$root/lib/ocaml \
            DLLDIR=$root/lib/ocaml/stublibs \
            INSTALLDIR=$root/lib/ocaml/lablGL)

(cd $mudir && $make -j "$jobs" build=release)

cd ..

srcpath=$(dirname $0)

sh $srcpath/mkhelp.sh $srcpath/keystoml.ml $srcpath/KEYS > help.ml

tp=$root/$mudir/thirdparty

ccopt="-O"
ccopt="$ccopt -I $tp/jbig2dec"
ccopt="$ccopt -I $tp/jpeg-8d"
ccopt="$ccopt -I $tp/freetype-2.4.9/include"
ccopt="$ccopt -I $tp/openjpeg-1.4/libopenjpeg"
ccopt="$ccopt -I $tp/zlib-1.2.5"
ccopt="$ccopt -I $root/$mudir/fitz -I $root/$mudir/pdf -I $root/$mudir/xps"
ccopt="$ccopt -I $root/$mudir/cbz"

ccopt="$ccopt -include $tp/freetype-2.4.9/include/ft2build.h -D_GNU_SOURCE"

cclib="$cclib -L$root/$mudir/build/release"
cclib="$cclib -lfitz"
cclib="$cclib -lz -ljpeg -lopenjpeg -ljbig2dec -lfreetype"
cclib="$cclib -lX11"

echo Building llpp...
if test "$1" = "opt"; then
    cclib="$cclib -lpthread"
    executable_p ocamlopt.opt && comp=ocamlopt.opt || comp=ocamlopt
    $comp -c -o link.o -ccopt "$ccopt" $srcpath/link.c
    $comp -c -o help.cmx help.ml
    $comp -c -o wsi.cmi $srcpath/wsi.mli
    $comp -c -o wsi.cmx $srcpath/wsi.ml
    $comp -c -o parser.cmx $srcpath/parser.ml
    $comp -c -o main.cmx -I $root/lib/ocaml/lablGL $srcpath/main.ml

    $comp -o llpp                       \
        -I $root/lib/ocaml/lablGL       \
        str.cmxa unix.cmxa lablgl.cmxa  \
        link.o                          \
        -cclib "$cclib"                 \
        help.cmx                        \
        parser.cmx                      \
        wsi.cmx                         \
        main.cmx
else
    executable_p ocamlc.opt && comp=ocamlc.opt || comp=ocamlc
    $comp -c -o link.o -ccopt "$ccopt" $srcpath/link.c
    $comp -c -o help.cmo help.ml
    $comp -c -o wsi.cmi $srcpath/wsi.mli
    $comp -c -o wsi.cmo $srcpath/wsi.ml
    $comp -c -o parser.cmo $srcpath/parser.ml
    $comp -c -o main.cmo -I $root/lib/ocaml/lablGL $srcpath/main.ml

    $comp -custom -o llpp            \
        -I $root/lib/ocaml/lablGL    \
        str.cma unix.cma lablgl.cma  \
        link.o                       \
        -cclib "$cclib"              \
        help.cmo                     \
        parser.cmo                   \
        wsi.cmo                      \
        main.cmo
fi
echo All done
