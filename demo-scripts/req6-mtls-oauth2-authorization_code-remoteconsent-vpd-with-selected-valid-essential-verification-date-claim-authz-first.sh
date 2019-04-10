#!/usr/bin/env bash
#

# local user credentials
user="testinguser"
pass="testing123"
# name of the session cookie as configured inside AM (default is iPlanetDirectoryPro)
cookie_name="iPlanetDirectoryPro"
# base uri of AM
openam_endpoint=https://login66.booleans.local:8443/xs
# client settings
client_id="booleans_client"
# a redirect URI
redirect_uri=http://someservice.booleans.local:8080/dummycallback
# which scopes to request
scope="uid%20openid"
# ssl location
ssl_dir="ssl/"
# curl settings
curl_opts="-k"
# claims
claims='{"userinfo":{"https://www.yes.com/claims/verified_person_data":{"verification":{"date":{"max_age":"2000000000", "essential": true}},"claims":null}}}'

# get a session ID with a goto param
get_session_id_with_goto() {
    local _goto="${1}";
    session=$(curl \
        -s \
        -X POST ${curl_opts} \
        -H "X-OpenAM-Username: ${user}" \
        -H "X-OpenAM-Password: ${pass}" \
        -H "Accept-API-Version: protocol=1.0,resource=1.0" \
        -G \
        --data-urlencode "goto=${_goto}" \
        ${openam_endpoint}/json/authenticate | awk -F '"' '{ print $4 }')
    echo "${session}"
}

# get the authorization code with prompt value
get_authorization_code_prompt_consent() {
    local sessionid="${1}";
    local prompt="consent";
    local _urlenc_claims=$(urlencode "${claims}")
    ac_response=$(curl\
        -s \
        -X GET ${curl_opts} \
        -H "Cookie: ${cookie_name}=${sessionid}" \
        -v \
        "${openam_endpoint}/oauth2/authorize?response_type=code&scope=${scope}&client_id=${client_id}&redirect_uri=${redirect_uri}&prompt=${prompt}&claims=${_urlenc_claims}" 2>&1 | grep '< Location' | sed -e 's/< Location: //')
    echo "${ac_response}"
}

# get the authorization code with prompt value
get_authorization_code_prompt_consent_url() {
    local prompt="consent";
    local _urlenc_claims=$(urlencode "${claims}")
    local _goto="${openam_endpoint}/oauth2/authorize?response_type=code&scope=${scope}&client_id=${client_id}&redirect_uri=${redirect_uri}&prompt=${prompt}&claims=${_urlenc_claims}"
    echo "${_goto}"
}

# exchange the access_code for a token
exchange_ac_for_token() {
    set -x
    local _access_code="${1}";
    local _token_resp=$(curl \
        -s \
        -X POST ${curl_opts} \
        --cert ${ssl_dir}oauth2_client.crt \
        --key ${ssl_dir}oauth2_client.key \
        --cacert ${ssl_dir}login.booleans.local.crt \
        -d "client_id=${client_id}&code=${_access_code}&redirect_uri=${redirect_uri}&grant_type=authorization_code" \
        ${openam_endpoint}/oauth2/access_token)
    set +x
    echo "${_token_resp}"
}

# perform mtls request towards introspection endpoint
get_introspect() {
    local sessionid="${1}";
    local _access_token="${2}";
    local _token_resp=$(curl \
        -s \
        -X POST ${curl_opts} \
        --cert ${ssl_dir}oauth2_client.crt \
        --key ${ssl_dir}oauth2_client.key \
        --cacert ${ssl_dir}login.booleans.local.crt \
        -H "Cookie: ${cookie_name}=${sessionid}" \
        -d "client_id=${client_id}&token_type_hint=access_token&token=${_access_token}" \
        ${openam_endpoint}/oauth2/introspect)
    echo "${_token_resp}";
}

# get token information from a central endpoint
get_tokeninfo() {
    local sessionid="${1}";
    local _access_token="${2}";
    tokeninfo_response=$(curl\
        -X GET ${curl_opts} \
        -s \
        -H "Cookie: ${cookie_name}=${sessionid}" \
        -H "Authorization: Bearer ${_access_token}" \
        ${openam_endpoint}/oauth2/tokeninfo 2>&1)
    echo "${tokeninfo_response}"
}

# get user information from a central endpoint
get_userinfo() {
    local sessionid="${1}";
    local _access_token="${2}";
    userinfo_response=$(curl\
        -X GET ${curl_opts} \
        -s \
        -H "Cookie: ${cookie_name}=${sessionid}" \
        -H "Authorization: Bearer ${_access_token}" \
        ${openam_endpoint}/oauth2/userinfo 2>&1)
    echo "${userinfo_response}"
}

# follow the consent URL
follow_consent_url() {
    local sessionid="${1}"
    local _consent_url="${2}";
    _consent_url=${_consent_url%$'\r'}
    local _consent_resp=$(curl \
        -s \
        -X GET ${curl_opts} \
        -H "Cookie: ${cookie_name}=${sessionid}" \
        "${_consent_url}")
    echo "${_consent_resp}"
}

# retrieve form fields from response
submit_consent_response_and_get_code() {
    local sessionid="${1}";
    local _payload="${2}";
    local _title=$(xmllint --html --xpath "string(//html/body/h1)" - <<< "${_payload}" 2>/dev/null)
    local _formaction=$(xmllint --html --xpath "string(//html/body/form/@action)" - <<< "${_payload}" 2>/dev/null)
    local _formmethod=$(xmllint --html --xpath "string(//html/body/form/@method)" - <<< "${_payload}" 2>/dev/null)
    local _num_input=$(xmllint --html --xpath "count(//html/body/form/input)" - <<< "${_payload}" 2>/dev/null)

    local _post_response=""
    for (( x=1; x<=${_num_input}; x++ )); do
        fieldname=$(xmllint --html --xpath "string(//html/body/form/input["${x}"]/@name)" - <<< "${_payload}" 2>/dev/null)
        fieldvalue=$(xmllint --html --xpath "string(//html/body/form/input["${x}"]/@value)" - <<< "${_payload}" 2>/dev/null)
        if [[ -z "${_post_response}" ]]; then
            _post_response="${fieldname}=${fieldvalue}"
        else
            _post_response+="&${fieldname}=${fieldvalue}"
        fi;
    done;

    local _post_response=$(curl \
        -s \
        -X POST ${curl_opts} \
        -d "${_post_response}" \
        -H "Cookie: ${cookie_name}=${sessionid}" \
        http://nc.booleans.local:8680/rest/rcs/consent)
    echo "Response from saving consent: ${_post_response}" >&2

    # this assumes that the post response is a self-submitting form, YMMV
    local _postback_url=$(xmllint --html --xpath "string(//html/body/form/@action)" - <<< "${_post_response}" 2>/dev/null)
    local _post_fieldname=$(xmllint --html --xpath "string(//html/body/form/input[1]/@name)" - <<< "${_post_response}" 2>/dev/null)
    local _post_fieldvalue=$(xmllint --html --xpath "string(//html/body/form/input[1]/@value)" - <<< "${_post_response}" 2>/dev/null)
    echo >&2
    echo "Issuing POST to ${_postback_url} with body ${_post_fieldname} and value ${_post_fieldvalue}" >&2
    echo >&2

    local _postback_response=$(curl \
        -s \
        -v \
        -X POST ${curl_opts} \
        -d "${_post_fieldname}=${_post_fieldvalue}" \
        -H "Cookie: ${cookie_name}=${sessionid}" \
        "${_postback_url}" 2>&1 | grep '< Location' | sed -e 's/< Location: //')
    ac_code=$(echo ${_postback_response} | awk -F'?' '{ print $2 }'| awk -F'&' '{ print $1 }' | awk -F'=' '{ print $2 }')
    echo "${ac_code}"
}

urlencode() {
    local LANG=C
    for ((i=0;i<${#1};i++)); do
        if [[ ${1:$i:1} =~ ^[a-zA-Z0-9\.\~\_\-]$ ]]; then
            printf "${1:$i:1}"
        else
            printf '%%%02X' "'${1:$i:1}"
        fi
    done
}

# Executing the complete OAuth2 flow using the Authorization code Grant type.
_goto_url=$(get_authorization_code_prompt_consent_url)
echo "Received goto URL: ${_goto_url}"
echo
sessionid=$(get_session_id_with_goto "${_goto_url}")
echo "Received session ID: ${sessionid}"
echo

_consent_redirect=$(get_authorization_code_prompt_consent "${sessionid}")
echo "Received consent redirect: ${_consent_redirect}"
echo

_consent_resp=$(follow_consent_url "${sessionid}" "${_consent_redirect}")
echo "Received consent page content: ${_consent_resp}"

_code=$(submit_consent_response_and_get_code "${sessionid}" "${_consent_resp}")
echo "Auto-submitting consent, redirect back to AM and received code: ${_code}"

_access_token_response=$(exchange_ac_for_token "${_code}")
echo "The access token reponse: "
jq . <<< ${_access_token_response}
at=$(jq -r '.access_token' <<< "${_access_token_response}")
rt=$(jq -r '.refresh_token' <<< "${_access_token_response}")
echo "Access token: ${at}"
echo "Refresh token: ${rt}"
echo

_tokeninfo_response=$(get_tokeninfo "${sessionid}" "${at}")
echo "Response from tokeninfo endpoint: "
jq . <<< ${_tokeninfo_response}
echo

_userinfo_response=$(get_userinfo "${sessionid}" "${at}")
echo "Response from userinfo endpoint: "
jq . <<< ${_userinfo_response}
echo

_introspect_response=$(get_introspect "${sessionid}" "${at}")
echo "Response from introspect endpoint: "
jq . <<< ${_introspect_response}
echo
