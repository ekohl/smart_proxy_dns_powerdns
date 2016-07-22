#!/bin/bash
die() {
	echo $*
	exit 1
}

set -xe
HOST=127.0.0.1
export OS=${OS:-centos7}
export DB=${DB:-postgresql}
export FOREMAN_CUSTOM_URL
if [[ $DB == "postgresql" ]] ; then
	export DB_IMAGE=postgres
	export DB_PORT=postgres
elif [[ $DB == "mysql" ]] ; then
	export DB_IMAGE=mysql
	export DB_PORT=mysql
else
	die "Unsupported DB '${DB}'"
fi

get_port() {
	local service=$1
	local port=$2
	local protocol=${3:-tcp}
	docker-compose port --protocol $protocol $service $port | cut -d: -f2
}

remove() {
	docker-compose kill
	docker-compose rm --all -f
}

show_logs() {
	for container in db pdns smartproxy ; do
		docker-compose logs $container
	done
}

wait_db() {
	# TODO: poll for it?
	sleep 8
}

cleanup() {
	show_logs
	#remove
}

remove
docker-compose pull
docker-compose build --pull
docker-compose up -d
trap cleanup EXIT
wait_db

# Run the tests with the right parameters
export PDNS_HOST=$HOST
export PDNS_PORT=$(get_port pdns 53 udp)
export PDNS_CONTROL="pdns_control --remote-address=$HOST --remote-port=$(get_port pdns 53000)"
export SMARTPROXY_URL="http://$HOST:$(get_port smartproxy 8000)/"

[[ -z $PDNS_PORT ]] && die "PDNS port is unconfigured"

bundle exec rake test:integration
