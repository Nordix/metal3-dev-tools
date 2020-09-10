#!/bin/bash
set -e
url="${1}"
dst="${2}"
filename="$(basename ${url})"
tmpfile="/tmp/${filename}"
curl -sSL -w "%{http_code}" "${url}" | sed "s:/usr/bin:/usr/local/bin:g" > /tmp/"${filename}"
http_status=$(cat "${tmpfile}" | tail -n 1)
if [ "${http_status}" != "200" ]; then
  echo "Error: unable to retrieve ${filename} file";
  exit 1;
else
  cat "${tmpfile}"| sed '$d' > "${dst}";
fi