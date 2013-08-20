#!/bin/bash

# depends on googlecl


Today="`date +%F`"
Time="`date +%H%M%S`"
gfile='/tmp/goog-'$Today'-'$Time
tfile='/usr/local/freeswitch/conf/dialplan/default/tenants.xml'


function prepwork {

google docs get --title your-google-doc --format=csv --dest=$gfile

# replace empty fields with 'null', to guarantee that our while loop will correctly match fields with variables.  

awk -F, '{for(i=1;i<=NF;++i){if($i==""){printf "null"}else{printf $i} if(i<NF)printf ","} printf "\n"}'  "$gfile".csv  > tmpfile.txt && mv tmpfile.txt "$gfile".csv

# remove the first 3 rows of csv, wich are instructions to the client and headers
sed -i '1,3d'       "$gfile".csv

#removespaces
sed -i 's/ //g'   "$gfile".csv

# remove hyphens
sed -i 's/-//g'   "$gfile".csv



}

function scrape {


echo "<include>" >  $tfile

#loop through the tenants that have valid apt and cell numbers where physical extension field is no.

cat "$gfile".csv  | awk -F , '($1 !=  "null") && ($4 != "null") && ($5 == "no") {print $1, $2, $3, $4, $5}' | while read apt first last cell phys
do

echo -e '<extension name="'$first'_'$last'">'  >> $tfile
echo -e ' <condition field="destination_number" expression="^('$apt')$">' >> $tfile
echo -e '   <action application="export" data="suppress_cng=true"/>' >> $tfile
echo -e '   <action application="set" data="sip_h_X-accountcode=${accountcode}"/>' >> $tfile
echo -e '   <action application="set" data="sip_h_X-Tag="/>' >> $tfile
echo -e '   <action application="set" data="call_direction=outbound"/>' >> $tfile
echo -e '   <action application="set" data="hangup_after_bridge=true"/>' >> $tfile
echo -e '   <action application="set" data="effective_caller_id_number=0000000000"/>' >> $tfile
echo -e '   <action application="set" data="inherit_codec=true"/>' >> $tfile
echo -e '   <action application="set" data="continue_on_fail=true"/>' >> $tfile
echo -e '   <action application="bind_meta_app" data="9 b s transfer::open_sesame XML features"/>' >> $tfile
echo -e '   <action application="bridge" data="sofia/gateway/flowroute/1'$cell'"/>' >> $tfile
echo -e ' </condition>' >> $tfile
echo -e '</extension>' >> $tfile
echo -e '\n' >> $tfile

done


#cat "$gfile".csv  | awk -F , '($1 !=  "null") && ($4 != "null") && ($5 == "yes") {print $1, $2, $3, $4, $5}' | while read apt first last cell phys
#do
# add  code here when hardwired phones are installed.  See "Follow Me" in Freeswitch wiki
#done

echo "</include>" >>  $tfile


/usr/local/freeswitch/bin/fs_cli -x  reloadxml
}


#######

remountrw

cp $tfile to "$tfile".bk
rm $tfile

prepwork
scrape

remountro
