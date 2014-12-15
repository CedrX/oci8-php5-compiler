#!/bin/bash
#set -x
ORACLELIB_DIR=/usr/lib/oracle/
CLIENT="client64"
ORACLE_CLIENT=$(find /usr/lib/oracle/ -name $CLIENT | sort --reverse | head --lines=1)
ORACLE_INCLUDE=$(find /usr/include/oracle -name $CLIENT | sort --reverse | head --lines=1)
TARGETSCP="uplinist@vigix:"
TARGETDIRMIRROR="/var/spool/apt-mirror/mirror/inist-repository64/incoming/"
DEBDISTRIB=$(/usr/bin/lsb_release -a | grep Codename | awk ' { print $2 }')
DEBEMAIL="cedric.tintin@domain.fr"
ORACLE_CCFLAGS=/usr/local/share/oracle_flags.mk

# ok_or_fail : si reçoit 0 alors affiche un [Ok] à la sauce redhat sinon affiche un [Fail] et sort du programme
ok_or_fail() {
if [ $1 -eq 0 ] ; then echo -e "\t[Ok]"
   else echo "[Fail]"; exit 1
fi
}

modify_debian_modulelist() {
    echo -n "Modification du fichier $1/debian/modulelist"
    echo "oci8 OCI8" >>  $1/debian/modulelist
    ok_or_fail $?
}

modify_debian_rules() {
        echo -n " Ajout des flags de compilation oracle dans $1/debian/rules"
	/bin/echo ${ORACLE_CCFLAGS} | /bin/sed -e 's|/|\\/|g' | \
		/usr/bin/xargs -IFILEFLAGS /bin/sed -i '/export DH_VERBOSE=1/a\
include FILEFLAGS' $1/debian/rules
	ok_or_fail $?
	echo -n "Ajout de l'option de configuration oci8 dans $1/debian/rules"
        /bin/echo ${ORACLE_CLIENT} | /bin/sed -e 's|/|\\/|g' | \
                /usr/bin/xargs -ICLIENT /bin/sed -i -e '/--with-mysql=shared,\/usr/i\
        \t--with-oci8=shared,CLIENT \\' $1/debian/rules
        ok_or_fail $?
}

modify_debian_control() {
echo -n "Modification du fichier $1/debian/control"
/bin/echo -e "\n
Package: php5-oci8
Architecture: any
Depends: \${shlibs:Depends}, \${misc:Depends}, \${php:Depends}, php5-common (= \${Source-Version}), oracle-instantclient-basic, oracle-instantclient-devel
Description: OCI8 module for php5
 This package provides a module for OCI8 using Oracle instantclient amd64 client.
 .
 PHP5 is an HTML-embedded scripting language. Much of its syntax is borrowed
 from C, Java and Perl with a couple of unique PHP-specific features thrown
 in. The goal of the language is to allow web developers to write
 dynamically generated pages quickly.
" >>  $1/debian/control
ok_or_fail $?
/bin/sed -i -e 's/\(Build-Depends: .*\)/\1, oracle-instantclient-basic, oracle-instantclient-devel,/' $1/debian/control
ok_or_fail $?
}

modify_php_version() {
cd $1
echo -n "Increment version number of php"
DEBEMAIL=cedric.tintin@domain.fr dch --distribution stable "add oci8 support"
ok_or_fail $?
cd -
}

get_new_version() {
	newversion=$(head -1 $1/debian/changelog)
	newversion=${newversion%) *}
	newversion=${newversion#* (}
	echo $newversion
}

modify_debian_modulelist $1
modify_debian_rules $1
modify_debian_control $1
modify_php_version $1
NBCPU=$(cat /proc/cpuinfo  | grep ^processor | wc -l)
cat << EOF > $1/compil.sh
export DEB_BUILD_OPTIONS=parallel=$NBCPU
export NAME="Cedric TINTANET"
export DEBEMAIL="cedric.tintin@domain.fr"
#export CPPFLAGS="-I$ORACLE_INCLUDE"
#export LDFLAGS="-L$ORACLE_CLIENT/lib"
export LD_LIBRARY_PATH=${ORACLE_CLIENT}/lib
/usr/bin/dpkg-buildpackage -j$NBCPU -uc -us -rfakeroot
#if [ \$? -eq 0 ] ; then
#scp $1/../*.deb ${TARGETSCP}${TARGETDIRMIRROR}
#scp $1/../*.diff.gz ${TARGETSCP}${TARGETDIRMIRROR}
#scp $1/../*.dsc ${TARGETSCP}${TARGETDIRMIRROR}
#scp $1/../*.changes ${TARGETSCP}${TARGETDIRMIRROR}
#scp $1/../*_$(get_new_version $1)* ${TARGETSCP}${TARGETDIRMIRROR}
#exit 0
#else
#exit 1
#fi
EOF
chmod 750 $1/compil.sh

