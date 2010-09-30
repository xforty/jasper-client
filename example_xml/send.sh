#!/bin/sh

file=$1
action=`echo $file|sed 's/.xml//'`
username='jasperadmin'
password=$username
url="http://$username:$password@127.0.0.1:8080/jasperserver/services/repository"

#lwp-request -e -S -U -H 'SoapAction: ""' -m POST $url < $file  | sed 's/&gt;/>/g' | sed 's/&lt;/</g' | sed 's/&quot;/"/g'

lwp-request -e -S -U -H 'SoapAction: ""' -m POST $url < $file

#lwp-request -H 'SoapAction: ""' -m POST $url < $file | \
#    xpath '//getReturn/node()' 2>&1 | \
#    sed -n '3,$p' | \
#    sed 's/&gt;/>/g' | sed 's/&lt;/</g' | sed 's/&quot;/"/g'


