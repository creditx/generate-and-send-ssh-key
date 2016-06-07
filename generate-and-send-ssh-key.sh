#!/bin/bash

# define settings here
KEYSIZE=2048
PASSPHRASE=
FILENAME=~/.ssh/id_rsa
KEYTYPE=rsa
USER=$USER

while [[ $# > 0 ]]
do
    key="$1"
    while [[ ${key+x} ]]
    do
        case $key in
            -u*|--user)
                USER="$2"
                shift # option has parameter
                ;;
            -p*|--password)
                PASSPHRASE="$2"
                shift # option has parameter
                ;;
            -h*|--host)
                HOST="$2"
                shift # option has been fully handled
                ;;
            -f*|--file)
                FILENAME="$2"
                shift # option has been fully handled
                ;;
            -P*|--port)
                SSH_OPTS="-p $2"
                shift # option has been fully handled
                ;;
            -k*|--keysize)
                KEYSIZE="-p $2"
                shift # option has been fully handled
                ;;
            -t*|--keytype)
                KEYTYPE="-p $2"
                shift # option has been fully handled
                ;;
            -e=*)
                EXAMPLE="${key#*=}"
                break # option has been fully handled
                ;;
            *)
                # unknown option
                echo Unknown option: $key #1>&2
                exit 10 # either this: my preferred way to handle unknown options
                break # or this: do this to signal the option has been handled (if exit isn't used)
                ;;
        esac
        # prepare for next option in this key, if any
        [[ "$key" = -? || "$key" == --* ]] && unset key || key="${key/#-?/-}"
    done
    shift # option(s) fully processed, proceed to next input argument
done


#
# NO MORE CONFIG SETTING BELOW THIS LINE
#

# check that we have all necessary parts
SSH_KEYGEN=`which ssh-keygen`
SSH=`which ssh`
SSH_COPY_ID=`which ssh-copy-id`

if [ -z "$SSH_KEYGEN" ];then
    echo Could not find the 'ssh-keygen' executable
    exit 1
fi
if [ -z "$SSH" ];then
    echo Could not find the 'ssh' executable
    exit 1
fi

# perform the actual work
echo Creating a new key using $SSH-KEYGEN
if [ ! -f $FILENAME ];then
    $SSH_KEYGEN -t $KEYTYPE -b $KEYSIZE  -f $FILENAME -N "$PASSPHRASE"
    RET=$?
    if [ $RET -ne 0 ];then
        echo ssh-keygen failed: $RET
        exit 1
    fi
fi

echo Adjust permissions of generated key-files locally
chmod 0600 ${FILENAME}*
RET=$?
if [ $RET -ne 0 ];then
    echo chmod failed: $RET
    exit 1
fi

echo Copying the key to the remote machine $USER@$HOST
if [ -z "$SSH_COPY_ID" ];then
    echo Could not find the 'ssh-copy-id' executable, using manual copy instead
    cat ${FILENAME}.pub | ssh $SSH_OPTS $USER@$HOST 'cat >> ~/.ssh/authorized_keys'
else
	$SSH_COPY_ID $SSH_OPTS -i $FILENAME $USER@$HOST
fi

RET=$?
if [ $RET -ne 0 ];then
    echo ssh-copy-id failed: $RET
    exit 1
fi

echo Adjusting permissions to avoid errors in ssh-daemon
$SSH $SSH_OPTS $USER@$HOST "chmod go-w ~ && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
RET=$?
if [ $RET -ne 0 ];then
    echo ssh-chmod failed: $RET
    exit 1
fi

echo Setup finished, now try to run $SSH $SSH_OPTS -i $FILENAME $USER@$HOST
