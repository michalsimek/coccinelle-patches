basedir=$(cd $(dirname $0); pwd)

. ${basedir}/../common/findlog-common.sh
. ${basedir}/findlog-watchdog.sh

maintainers()
{
    local file=$1
    local tmpfile=/tmp/watchdog.$$
    local m

    cc=""

    scripts/get_maintainer.pl --no-l --no-rolestats ${file} | \
	egrep -v "Guenter Roeck|Wim Van" > ${tmpfile}

    while read -r m
    do
	cc="${cc}
Cc: $m"
    done < ${tmpfile}

    rm -f ${tmpfile}
}

git status | grep modified: | awk '{print $2}' | while read a
do
    echo "Handling $a"

    # Only commit if a maching object file exists
    o="${a%.c}.o"
    if [ ! -e $o ]; then
        echo "$a: No object file - skipping"
	continue
    fi

    git add $a

    outmsg=""
    d=0
    o=0
    s=0
    p=0

    findlog_common $a
    findlog_watchdog $a
    maintainers $a
    subject=""
    msg=""
    if [ $d -ne 0 ]
    then
        subject="Convert to use device managed functions"
	msg="Use device managed functions to simplify error handling, reduce
source code size, improve readability, and reduce the likelyhood of bugs."
	if [ $o -ne 0 ]
	then
		subject="${subject} and other improvements"
		msg="${msg}
Other improvements as listed below."
	fi
    else
        if [ $s -ne 0 ]
	then
		subject="Replace shutdown function with call to watchdog_stop_on_reboot"
		msg="The shutdown function calls the stop function.
Call watchdog_stop_on_reboot() from probe instead."
	elif [ $p -ne 0 ]
	then
		subject="Use 'dev' instead of dereferencing it repeatedly"
		msg="Introduce local variable 'struct device *dev' and use it instead of
dereferencing it repeatedly."
		outmsg=""
	else
		subject="Various improvements"
		msg="Various coccinelle driven transformations as detailed below."
	fi
    fi
    git commit -s \
	-m "watchdog: $(basename -s .c $a): ${subject}" \
	-m "${msg}" \
	-m "The conversion was done automatically with coccinelle using the
following semantic patches. The semantic patches and the scripts
used to generate this commit log are available at
https://github.com/groeck/coccinelle-patches" \
-m "${outmsg}" \
-m "${cc}"
done
