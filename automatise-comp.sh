#!/bin/bash

#set -x
eval $(dpkg-architecture -s)
#REPCONFSRC = répertoire contenant les fichiers de configuration des sources à compiler
REPCONFSRC=/home/tintin/

# fonction clean : 
# Supprime repertoire de compilation, fichiers et paquets generes par dpkg-buildpackage
# Arguments:
#          $1 : repertoire ou sont telechargés les sources
#          $2 : types de sources 
clean() {
    for i in $(find $1 -mindepth 1 -maxdepth 1 -type d -iname "$2*") ; do
        rm -rf $i
    done
    rm -f $1/$2*.deb
    find $1 -mindepth 1 -maxdepth 1 -type f  -iname "$2*.diff.gz" -exec rm {} \;
    find $1 -mindepth 1 -maxdepth 1 -type f  -iname "$2*.dsc" -exec rm {} \;
    find $1 -mindepth 1 -maxdepth 1 -type f  -iname "$2*.orig.tar.gz" -exec rm {} \;

}

verify_need_update() {
        RESULT=1
        count=0
        count=$(find $1 -type f -name "$2_*_*\.deb" | wc -l)
        if [ $count -gt 0 ] ; then
                file=$(find $1 -type f -name "$2*_*_*\.deb" | head -1)
                version_paquet_compiled=$(echo $file | sed 's/^.*_\(.*\)_.*$/\1/')
                for i in $(apt-cache showsrc $2 | awk '/^Version: / { print $2 }')  ; do
                        dpkg  --compare-versions $version_paquet_compiled lt $i
                        RESULT=$(($RESULT & $?))
                done
        else RESULT=0
        fi
        echo $RESULT                    
}

#find_repsources : retourne le répertoire où les sources modifies du paquet php5 ont étés decompresses
#find_repsources() {
#    FILESRC=$(apt-cache showsrc $2 | grep '\.tar\.gz' | head -1 | awk ' { for(i=1;i<=NF;i++) { if($i ~ /\.tar\.gz/) print $i} }')
#    #echo $(tar tvfz $1/$FILESRC | head -1 | awk ' { chaine=sub(".orig","",$NF); print $chaine }')
#    echo $(tar tfz $1/$FILESRC | head -1 | sed 's/\.orig//')
#}

find_repsources() {
        file=$(find $1 -type f -iname $2'*\.dsc' -print)
        if [ -n "$file" ] ; then
                sources=$(grep ^Source $file)
                sources=${sources#Source: }
                version=$(grep ^Version $file | head -1)
                version=${version#Version: }
                version=${version%-*}
                repsources=$sources-$version
        fi
        echo ${repsources:-none}
}

#install_sources : install le paquet sources $2 dans le répertoire $1 
install_sources() {
    CURRENT_REP=$PWD
    cd $1
    apt-get source $2
    [ $? -gt 0 ] && (echo "Unable to find sources $2" ; exit 1)
    cd $CURRENT_REP
}

#install_build_depends() : Installation des dépendances de compilation
install_build_depends() {
    #Install fakeroot if not installed
    dpkg --get-selections fakeroot 2>&1 | grep -q "install$"
    [ $? -eq 1 ] && sudo apt-get install -y fakeroot
    dontwork=0
    for i in $(sed -ne '/Build-Depends/p' $1/debian/control | sed -e 's/Build-Depends: //' -e 's/,/ /g' -e 's/|//g'); do
        echo $i | grep -q "^\["
        if [ $? -eq 0 ]; then dontwork=1 ; continue ; fi
        if [ $dontwork -eq 1 ] ; then
            echo $i | grep -q "]$"
            [ $? -eq 0 ] && dontwork=0
        else
            echo $i | grep -q -e "^(" -e ")$"
            if [ $? -eq 1 ] ; then
                dpkg --get-selections $i 2>&1 | grep -q "install$"
                if [ $? -eq 1 ]; then
                    apt-cache search $i | grep -qv "^$"
                    if [ $? -eq 0 ] ; then
                        echo "Installing $i"
                        sudo apt-get install -y $i
                    fi
                fi
            fi
        fi
    done
}




if [ $# -lt 2 ] ; then
echo "Usage $0 <repertoire_compilation> <sources>"
exit 1
fi

if [ ! -d $1 ]; then
echo "Directory $1 doesn't exist, please create directory before ..."
exit 1
else
#enlève le "/" à la fin du répertoire spécifié
REPSOURCES=$(echo $1 | sed 's/\(^.*\)\/$/\1/')
fi

if [ $(verify_need_update $1 $2) -eq 0 ] ; then
    clean $1 $2
    install_sources $1 $2
    repextract=$(find_repsources $1 $2)
    if [ $repextract == "none" ] ; then
	echo "Unable to find directory of sources for $2"
	exit 1
    fi
    REPSOURCES=$REPSOURCES/$repextract
    $REPCONFSRC/$2-"$DEB_BUILD_ARCH".sh $REPSOURCES
#    if [ $? -eq 0 ]; then
#        apt-get install build-dep $2
#        cd $REPSOURCES
#        ./compil.sh
#        cd -
#        if [ $? -eq 0 ] ; then
#            echo "Problem during compilation of $2"
#            exit 1
#        fi
#    else
#        echo "Can't modify files in $REPSOURCES/debian !!"
#        exit 1
#    fi
else
echo "Nothing to do ..."
exit 0
fi


