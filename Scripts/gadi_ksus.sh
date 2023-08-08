#! /bin/bash

groups=( `groups` )
tmp=tmp
echo "#PROJECT,PERIOD,GRANT,USED,RESERVED,AVAIL">$tmp
for project in "${groups[@]}"; do
	if [[ $project =~ ^[a-z]{1,2}[0-9]{1,2} ]]; then
		nci=`nci_account -P $project`
		if [[ ${nci} =~ "Project does not exist" ]];then
			echo $project,0,0,0,0,0>>$tmp
		else
			period=`echo $nci | sed -E s'/^.*Period\=(([0-9]{1,4}\.q.)|None).*$/\1/g'`
			grant=`echo $nci | sed -E s'/^.*Grant: ([-+]?[0-9]*\.[0-9]+\sK?SU).*$/\1/g'`
			used=`echo $nci | sed -E s'/^.*Used: ([-+]?[0-9]*\.[0-9]+\sK?SU).*$/\1/g'`
			reserved=`echo $nci | sed -E s'/^.*Reserved: ([-+]?[0-9]*\.[0-9]+\sK?SU).*$/\1/g'`
			avail=`echo $nci | sed -E s'/^.*Avail: ([-+]?[0-9]*\.[0-9]+\sK?SU).*$/\1/g'`
			echo $project,$period,$grant,$used,$reserved,$avail>>$tmp
		fi
	fi
done
column -t -s',' $tmp

rm -rf $tmp
