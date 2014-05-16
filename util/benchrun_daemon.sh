#!/bin/bash
#Rewritten as of April 9th, 2014 by Dave Storch & Amalia Hawkins
#Find us if you have any questions, future user!
set -x
#Defaults
MPERFPATH=${HOME}/mongo-perf-qconner
BUILD_DIR=${HOME}/mongo-qconner
DBPATH=${HOME}/db
SHELLPATH=$BUILD_DIR/mongo
BRANCH=master
NUM_CPUS=$(grep ^processor /proc/cpuinfo | wc -l)
RHOST="mongo-perf-1.vpc1.build.10gen.cc"
RPORT=27017
BREAK_PATH=${HOME}/build-perf
TEST_DIR=$MPERFPATH/testcases
SLEEPTIME=60

function do_git_tasks() {
    cd $BUILD_DIR
    git checkout $BRANCH
    git clean -fqdx
    git pull

    if [ -z "$LAST_HASH" ]
    then
        LAST_HASH=$(git rev-parse HEAD)
        return 1
    else
        NEW_HASH=$(git rev-parse HEAD)
        if [ "$LAST_HASH" == "$NEW_HASH" ]
        then
            return 0
        else
            LAST_HASH=$NEW_HASH
            return 1
        fi
    fi
}

function run_build() {
    cd $BUILD_DIR
    scons -j $NUM_CPUS --64 --release mongod mongo
}

function run_mongo-perf() {
    # Kick off a mongod process.
    cd $BUILD_DIR
    ./mongod --dbpath "$(DBPATH)" --smallfiles --fork --logpath mongoperf.log
    MONGOD_PID=$!

    sleep 30

    cd $MPERFPATH
    TIME="$(date "+%m%d%Y|%H:%M")"

    TESTCASES=$(find testcases/ -name *.js)

    # Run with one DB.
    echo 3 > /proc/sys/vm/drop_caches
    python benchrun.py -l "$TIME-linux" --rhost "$RHOST" --rport "$RPORT" -t 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 18 20 22 24 26 28 30 32 -s "$SHELLPATH" -f $TESTCASES

    # Run with multi-DB (4 DBs.)
    echo 3 > /proc/sys/vm/drop_caches
    python benchrun.py -l "$TIME-linux-multi" --rhost "$RHOST" --rport "$RPORT" -t 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 18 20 22 24 26 28 30 32 -s "$SHELLPATH" -m 4 -f $TESTCASES

    # Kill the mongod process and perform cleanup.
    kill -n 9 $MONGOD_PID
    pkill -9 mongod
    rm -rf $DBPATH/*
}


while [ true ]
do
    if [ -e $BREAK_PATH ]
    then
        break
    fi
    do_git_tasks
    if [ $? == 0 ]
    then
        sleep $SLEEPTIME
        continue
    else
        run_build
        run_mongo-perf
    fi
done
