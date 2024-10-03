# @see https://gist.github.com/joshisa/297b0bc1ec0dcdda0d1625029711fa24
GITHUB_OUTPUT=${GITHUB_OUTPUT:-/dev/stdout}
url="$1"
protocol=$(echo "$url" | grep "://" | sed -e's,^\(.*://\).*,\1,g')
url_no_protocol=$(echo "${url/$protocol/}")
protocol=$(echo "$protocol" | tr '[:upper:]' '[:lower:]')
userpass=$(echo "$url_no_protocol" | grep "@" | cut -d"/" -f1 | rev | cut -d"@" -f2- | rev)
pass=$(echo "$userpass" | grep ":" | cut -d":" -f2)
if [ -n "$pass" ]; then
  user=$(echo "$userpass" | grep ":" | cut -d":" -f1)
else
  user="$userpass"
fi
hostport=$(echo "${url_no_protocol/$userpass@/}" | cut -d"/" -f1)
host=$(echo "$hostport" | cut -d":" -f1)
port=$(echo "$hostport" | grep ":" | cut -d":" -f2)
path=$(echo "$url_no_protocol" | grep "/" | cut -d"/" -f2-)
echo "protocol=$protocol" >> $GITHUB_OUTPUT
echo "userpass=$userpass" >> $GITHUB_OUTPUT
echo "user=$user" >> $GITHUB_OUTPUT
echo "pass=$pass" >> $GITHUB_OUTPUT
echo "host=$host" >> $GITHUB_OUTPUT
echo "port=$port" >> $GITHUB_OUTPUT
echo "path=$path" >> $GITHUB_OUTPUT
