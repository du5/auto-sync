#!/usr/bin/bash

function getArgs
{
    jq -r ${1} ${job}.json
}

function syncGit
{
    job=${1}
    for i in $(seq 0 `echo $(( \`jq . ${job}.json |jq 'length'\` - 1 ))`)
    do
        source="`getArgs \".[${i}].source\"`"
        pull_user="`getArgs \".[${i}].pull_user\"`"
        pull_email="`getArgs \".[${i}].pull_email\"`"
        to="`getArgs \".[${i}].to\"`"
        push_user="`getArgs \".[${i}].push_user\"`"
        push_email="`getArgs \".[${i}].push_email\"`"
        push_args="`getArgs \".[${i}].push_args\"`"
        git config --global user.name ${pull_user}
        git config --global user.email ${pull_email}
        ssh -T `echo ${source} |awk -F: '{print $1}' `
        git clone ${source} repository
        (
            cd repository
            git fetch --all
            git fetch --tags
            git remote set-url origin ${to}
            git config --global user.name ${push_user}
            git config --global user.email ${push_email}
            ssh -T `echo ${to} |awk -F: '{print $1}' `
            git push --all ${push_args} -u origin
            git push --tags ${push_args} -u origin
            cd ..
            rm -rf repository
        )
    done
}

function syncReleases
{
    for i in $(seq 0 `echo $(( \`jq . releases.json |jq 'length'\` - 1 ))`)
    do
        allJson=`curl -s \`jq -r ".[${i}].releases" releases.json\` | jq .`
        nodeId=`echo ${allJson} | tr '\r\n' ' ' | jq -r ".[0].node_id"`
        allAssets=`echo ${allJson} | tr '\r\n' ' ' |  jq ".[0].assets"`
        latest=`curl -s ${CI_HOST}/\`jq -r ".[${i}].saveToPath" releases.json\`/latest`

        if [ "${nodeId}" == "${latest}" ]
        then
            continue
        fi

        mkdir -p releases
        cd releases
        for j in $(seq 0 `echo $(( \`echo ${allAssets} | jq 'length'\` - 1 ))`)
        do
            assets=`echo ${allAssets} | jq -r ".[${j}].browser_download_url"`
            wget -q ${assets}
        done

        tarball_url=`echo ${allJson} | tr '\r\n' ' ' | jq -r ".[0].tarball_url"`
        tarFileName=`echo $tarball_url | awk -F/ '{print $8}' `.tar
        wget -qL -O ${tarFileName} $tarball_url

        zipball_url=`echo ${allJson} | tr '\r\n' ' ' | jq -r ".[0].zipball_url"`
        zipFileName=`echo $zipball_url | awk -F/ '{print $8}' `.zip
        wget -qL -O ${zipFileName} $zipball_url

        echo ${nodeId} >> latest
        ssh root@${CI_SSH_IP} -p ${CI_SSH_PORT} "rm -rf /www/wwwroot/build.git.bet/`jq -r \".[${i}].saveToPath\" ../releases.json`/"
        ssh root@${CI_SSH_IP} -p ${CI_SSH_PORT} "mkdir -p /www/wwwroot/build.git.bet/`jq -r \".[${i}].saveToPath\" ../releases.json`/"
        scp -P${CI_SSH_PORT} -q * root@${CI_SSH_IP}:/www/wwwroot/build.git.bet/`jq -r ".[${i}].saveToPath" ../releases.json`/
        cd ..
        rm -rf releases
    done
}

case ${1} in  
    git)  
        syncGit ${2}
        ;;  
    releases)  
        syncReleases
        ;;  
    *)  
        exit 1  
        ;;  
esac