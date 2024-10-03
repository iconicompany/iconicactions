set -e

parseURL $DATABASE_URL
echo "create user $user with CREATEDB " | psql -h $host postgres


parseURL () {

url="$1"

protocol=$(echo "$1" | grep "://" | sed -e's,^\(.*://\).*,\1,g')
# Remove the protocol
url_no_protocol=$(echo "${1/$protocol/}")
# Use tr: Make the protocol lower-case for easy string compare
protocol=$(echo "$protocol" | tr '[:upper:]' '[:lower:]')

# Extract the user and password (if any)
# cut 1: Remove the path part to prevent @ in the querystring from breaking the next cut
# rev: Reverse string so cut -f1 takes the (reversed) rightmost field, and -f2- is what we want
# cut 2: Remove the host:port
# rev: Undo the first rev above 
userpass=$(echo "$url_no_protocol" | grep "@" | cut -d"/" -f1 | rev | cut -d"@" -f2- | rev)
pass=$(echo "$userpass" | grep ":" | cut -d":" -f2)
if [ -n "$pass" ]; then
  user=$(echo "$userpass" | grep ":" | cut -d":" -f1)
else
  user="$userpass"
fi

# Extract the host
hostport=$(echo "${url_no_protocol/$userpass@/}" | cut -d"/" -f1)
host=$(echo "$hostport" | cut -d":" -f1)
port=$(echo "$hostport" | grep ":" | cut -d":" -f2)
path=$(echo "$url_no_protocol" | grep "/" | cut -d"/" -f2-)

}

# echo "url: $url"
# echo "  protocol: $protocol"
# echo "  userpass: $userpass"
# echo "  user: $user"
# echo "  pass: $pass"
# echo "  host: $host"
# echo "  port: $port"
# echo "  path: $path"
